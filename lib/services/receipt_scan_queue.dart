import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/budget_model.dart';
import '../models/budget_provider.dart';
import '../models/receipt_model.dart';
import '../models/receipt_provider.dart';
import 'notification_service.dart';
import 'receipt_ai_service.dart';

/// One queued scan awaiting Gemini. Exposed via [ReceiptScanQueue.pending] so
/// UIs (e.g. the transactions list) can show a badge or in-progress marker
/// for a transaction whose receipt is still being processed.
class ReceiptScan {
  final String id;
  final String transactionId;
  final String imagePath;
  final DateTime enqueuedAt;

  const ReceiptScan({
    required this.id,
    required this.transactionId,
    required this.imagePath,
    required this.enqueuedAt,
  });
}

/// Processes receipt-image → Gemini → Receipt attachments in the background.
///
/// Distinct from [ScanReceiptFlow] which scans first and then fuzzy-matches to
/// a transaction. Here the transaction is already known (vendor, amount,
/// date), so we save the image immediately, return control to the caller, and
/// let the AI call race to completion. When it finishes we create the
/// [Receipt], link it to the transaction, fire a local notification, and
/// apply vendor rules to back-categorize the transaction if it was
/// uncategorized.
class ReceiptScanQueue {
  ReceiptScanQueue._();
  static final ReceiptScanQueue instance = ReceiptScanQueue._();
  static const _uuid = Uuid();

  BudgetProvider? _budget;
  ReceiptProvider? _receipts;

  /// Callers can `ValueListenableBuilder` on this to see live queue state.
  final ValueNotifier<List<ReceiptScan>> pending = ValueNotifier([]);

  void attach({
    required BudgetProvider budget,
    required ReceiptProvider receipts,
  }) {
    _budget = budget;
    _receipts = receipts;
  }

  /// Take raw image bytes (camera/gallery), compress, save to docs/receipts,
  /// and kick off an AI scan in the background. Returns immediately with the
  /// saved image path so the caller can show a progress snackbar.
  Future<String?> enqueueFromBytes({
    required Uint8List rawBytes,
    required Transaction transaction,
  }) async {
    // Compress the same way [ScanReceiptFlow] does, so Gemini behavior is
    // identical and we don't keep full-resolution originals on disk.
    final compressed = await FlutterImageCompress.compressWithList(
      rawBytes,
      quality: 70,
      minWidth: 800,
      minHeight: 800,
      keepExif: false,
    );
    final imageBytes = compressed.isEmpty ? rawBytes : compressed;

    String savedPath;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final receiptsDir = Directory('${dir.path}/receipts');
      await receiptsDir.create(recursive: true);
      final imgFile = File('${receiptsDir.path}/${_uuid.v4()}.jpg');
      await imgFile.writeAsBytes(imageBytes);
      savedPath = imgFile.path;
    } catch (e) {
      debugPrint('ReceiptScanQueue: image save failed: $e');
      await NotificationService.instance.showSync(
        title: 'Receipt save failed',
        body: 'Could not store the image locally. Try again.',
      );
      return null;
    }

    final scan = ReceiptScan(
      id: _uuid.v4(),
      transactionId: transaction.id,
      imagePath: savedPath,
      enqueuedAt: DateTime.now(),
    );
    pending.value = [...pending.value, scan];

    // Fire-and-forget — detached future, not awaited here so the caller's
    // snackbar can show "scanning in background" and pop the sheet.
    unawaited(_process(scan, imageBytes, transaction));

    return savedPath;
  }

  Future<void> _process(
    ReceiptScan scan,
    Uint8List imageBytes,
    Transaction transaction,
  ) async {
    final budget = _budget;
    final receipts = _receipts;
    if (budget == null || receipts == null) {
      debugPrint('ReceiptScanQueue: providers not attached');
      _removeScan(scan);
      return;
    }

    try {
      final parsed = await ReceiptAiService.parseReceipt(imageBytes);

      // Transaction is authoritative for vendor + amount + date. Fall back to
      // AI-extracted values only when the transaction's field is empty.
      final storeName = transaction.storeName.isNotEmpty
          ? transaction.storeName
          : parsed.storeName;
      final total = transaction.amount;
      final date = transaction.date;

      // User-defined vendor rules beat Gemini's category guess.
      String? categoryId = transaction.categoryId;
      categoryId ??= budget.suggestCategoryByVendorRules(storeName);
      if (categoryId == null && parsed.storeName.isNotEmpty) {
        final categoryNames = budget.categories.map((c) => c.name).toList();
        final canonicalNames =
            parsed.items.map((i) => i.canonicalName).toList();
        final suggested = await ReceiptAiService.suggestCategory(
          storeName: parsed.storeName,
          canonicalNames: canonicalNames,
          categoryNames: categoryNames,
        );
        if (suggested != null) {
          final match = budget.categories
              .where((c) => c.name == suggested)
              .firstOrNull;
          if (match != null) categoryId = match.id;
        }
      }

      final receiptId = _uuid.v4();
      final items = parsed.items
          .map((item) => ReceiptItem(
                id: item.id.isEmpty ? _uuid.v4() : item.id,
                receiptId: receiptId,
                rawName: item.rawName,
                canonicalName: item.canonicalName,
                unitPrice: item.unitPrice,
                quantity: item.quantity,
                storeName: storeName,
              ))
          .toList();

      final receipt = Receipt(
        id: receiptId,
        storeName: storeName,
        date: date,
        total: total,
        categoryId: categoryId ?? '',
        transactionId: transaction.id,
        imagePath: scan.imagePath,
        itemsJson: '',
      );
      receipt.items = items;

      await receipts.addReceipt(receipt);

      // Back-fill the transaction's category/store if it was missing.
      final needsCategoryFill =
          transaction.categoryId == null && categoryId != null;
      final needsStoreFill =
          transaction.storeName.isEmpty && storeName.isNotEmpty;
      final needsReceiptTag = !transaction.note.contains('[receipt-linked]');
      if (needsCategoryFill || needsStoreFill || needsReceiptTag) {
        final updated = transaction.copyWith(
          categoryId: needsCategoryFill ? categoryId : transaction.categoryId,
          storeName: needsStoreFill ? storeName : transaction.storeName,
          note: needsReceiptTag
              ? (transaction.note.isEmpty
                  ? '[receipt-linked]'
                  : '${transaction.note} [receipt-linked]')
              : transaction.note,
        );
        await budget.updateTransaction(transaction.id, updated);
      }

      await NotificationService.instance.showSync(
        title: 'Receipt scanned',
        body: storeName.isNotEmpty
            ? 'Attached ${items.length} item${items.length == 1 ? "" : "s"} to $storeName.'
            : 'Receipt attached to your transaction.',
      );
    } catch (e) {
      debugPrint('ReceiptScanQueue._process error: $e');
      await NotificationService.instance.showSync(
        title: 'Receipt scan failed',
        body: 'Gemini could not read the image. The photo is saved — try again from the transaction.',
      );
    } finally {
      _removeScan(scan);
    }
  }

  void _removeScan(ReceiptScan scan) {
    pending.value =
        pending.value.where((s) => s.id != scan.id).toList(growable: false);
  }

  bool isPendingFor(String transactionId) =>
      pending.value.any((s) => s.transactionId == transactionId);
}
