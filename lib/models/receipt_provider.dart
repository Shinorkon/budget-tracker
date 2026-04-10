import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'receipt_model.dart';

class ReceiptProvider extends ChangeNotifier {
  List<Receipt> _receipts = [];
  bool _isLoading = true;
  final HiveAesCipher? _cipher;
  late Box<Receipt> _box;

  List<Receipt> get receipts => List.unmodifiable(_receipts);
  bool get isLoading => _isLoading;

  List<ReceiptItem> get allItems =>
      _receipts.expand((r) => r.items).toList();

  /// Returns all items paired with their receipt date for price comparison.
  List<ReceiptItemEntry> get allItemEntries => _receipts
      .expand((r) => r.items.map((item) => ReceiptItemEntry(item: item, date: r.date)))
      .toList();

  /// Receipts grouped by store name (lowercase key, sorted by latest date per store).
  Map<String, List<Receipt>> get receiptsByStore {
    final map = <String, List<Receipt>>{};
    for (final r in _receipts) {
      final key = r.storeName.trim().toLowerCase().isEmpty
          ? 'unknown store'
          : r.storeName.trim().toLowerCase();
      map.putIfAbsent(key, () => []).add(r);
    }
    return map;
  }

  /// ReceiptItemEntries grouped by canonical name (lowercase key).
  Map<String, List<ReceiptItemEntry>> get itemsByCanonicalName {
    final map = <String, List<ReceiptItemEntry>>{};
    for (final entry in allItemEntries) {
      final key = entry.item.canonicalName.trim().toLowerCase();
      if (key.isEmpty) continue;
      map.putIfAbsent(key, () => []).add(entry);
    }
    return map;
  }

  ReceiptProvider({HiveAesCipher? cipher}) : _cipher = cipher {
    _init();
  }

  Future<void> _init() async {
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ReceiptAdapter());
    }
    await _migrateToEncrypted<Receipt>('receipts_v1');
    _box = await Hive.openBox<Receipt>('receipts_v1',
        encryptionCipher: _cipher);
    _receipts = _box.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    _isLoading = false;
    notifyListeners();
  }

  /// One-time migration: read unencrypted data, delete box, re-write encrypted.
  Future<void> _migrateToEncrypted<T>(String boxName) async {
    if (_cipher == null) return;
    if (Hive.isBoxOpen(boxName)) return;
    try {
      final plain = await Hive.openBox<T>(boxName);
      if (plain.isEmpty) {
        await plain.close();
        return;
      }
      final keys = plain.keys.toList();
      final values = plain.values.toList();
      await plain.close();
      await Hive.deleteBoxFromDisk(boxName);
      final encrypted = await Hive.openBox<T>(boxName,
          encryptionCipher: _cipher);
      for (int i = 0; i < keys.length; i++) {
        await encrypted.put(keys[i], values[i]);
      }
      await encrypted.close();
    } catch (_) {
      // Box may already be encrypted — nothing to migrate.
    }
  }

  Future<void> addReceipt(Receipt receipt) async {
    await _box.put(receipt.id, receipt);
    _receipts.insert(0, receipt);
    _receipts.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  Future<void> deleteReceipt(String id) async {
    await _box.delete(id);
    _receipts.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  Receipt? getReceiptByTransactionId(String transactionId) {
    try {
      return _receipts.firstWhere((r) => r.transactionId == transactionId);
    } catch (_) {
      return null;
    }
  }

  bool isDuplicate(String storeName, DateTime date, double total) {
    return _receipts.any((r) =>
        r.storeName.toLowerCase() == storeName.toLowerCase() &&
        r.date.year == date.year &&
        r.date.month == date.month &&
        r.date.day == date.day &&
        (r.total - total).abs() < 0.01);
  }
}
