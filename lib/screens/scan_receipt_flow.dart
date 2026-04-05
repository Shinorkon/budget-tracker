import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../models/budget_model.dart';
import '../models/budget_provider.dart';
import '../models/receipt_model.dart';
import '../models/receipt_provider.dart';
import '../services/receipt_ai_service.dart';
import '../utils/formatters.dart';
import 'receipt_review_screen.dart';

const _uuid = Uuid();

enum _ScanState { picking, processing, done, error }

class ScanReceiptFlow extends StatefulWidget {
  const ScanReceiptFlow({super.key});

  @override
  State<ScanReceiptFlow> createState() => _ScanReceiptFlowState();
}

class _ScanReceiptFlowState extends State<ScanReceiptFlow> {
  _ScanState _state = _ScanState.picking;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final source = await _pickSource();
    if (source == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2048,
    );

    if (file == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    setState(() => _state = _ScanState.processing);

    try {
      // Compress image
      final Uint8List? compressed = await FlutterImageCompress.compressWithFile(
        file.path,
        quality: 70,
        minWidth: 800,
        minHeight: 800,
        keepExif: false,
      );
      final imageBytes = compressed ?? await File(file.path).readAsBytes();

      // Parse receipt with Gemini
      final parsed = await ReceiptAiService.parseReceipt(imageBytes);

      if (!mounted) return;

      // Check for duplicate
      final receiptProvider =
          Provider.of<ReceiptProvider>(context, listen: false);
      if (parsed.storeName.isNotEmpty &&
          receiptProvider.isDuplicate(
              parsed.storeName, parsed.date, parsed.totalAmount)) {
        final proceed = await _showDuplicateDialog();
        if (!proceed) {
          if (mounted) Navigator.of(context).pop();
          return;
        }
      }

      // Save compressed image to documents dir
      String? savedImagePath;
      try {
        final dir = await getApplicationDocumentsDirectory();
        final receiptsDir = Directory('${dir.path}/receipts');
        await receiptsDir.create(recursive: true);
        final imgFile = File('${receiptsDir.path}/${_uuid.v4()}.jpg');
        await imgFile.writeAsBytes(imageBytes);
        savedImagePath = imgFile.path;
      } catch (_) {
        // Image save failure is non-fatal
      }

      // Fire category suggestion concurrently (result delivered via callback)
      final budget = Provider.of<BudgetProvider>(context, listen: false);
      String? suggestedCategoryId;
      final categoryNames = budget.categories.map((c) => c.name).toList();
      final canonicalNames =
          parsed.items.map((i) => i.canonicalName).toList();

      // Launch suggestion as background future, update state when done
      ReceiptAiService.suggestCategory(
        storeName: parsed.storeName,
        canonicalNames: canonicalNames,
        categoryNames: categoryNames,
      ).then((suggested) {
        if (!mounted || suggestedCategoryId != null) return;
        if (suggested != null) {
          final match = budget.categories
              .where((c) => c.name == suggested)
              .firstOrNull;
          if (match != null) {
            suggestedCategoryId = match.id;
            // This setState would only matter if the review screen is reading
            // it from a parent — handled via Navigator.pushReplacement below
          }
        }
      });

      if (!mounted) return;

      // Open review screen, await result map
      final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (_) => ReceiptReviewScreen(
            parsed: parsed,
            imagePath: savedImagePath,
            suggestedCategoryId: suggestedCategoryId,
          ),
        ),
      );

      if (result == null) {
        // User cancelled review
        if (mounted) Navigator.of(context).pop();
        return;
      }

      await _saveReceipt(result, savedImagePath, budget, receiptProvider);
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _ScanState.error;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<ImageSource?> _pickSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Scan Receipt',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Take a photo or choose from your gallery',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _sourceButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: AppColors.primary,
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _sourceButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: AppColors.accent,
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sourceButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showDuplicateDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Possible Duplicate',
                style: TextStyle(color: AppColors.textPrimary)),
            content: const Text(
              'A receipt with the same store, date, and total already exists. Save anyway?',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save Anyway',
                    style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _saveReceipt(
    Map<String, dynamic> result,
    String? imagePath,
    BudgetProvider budget,
    ReceiptProvider receiptProvider,
  ) async {
    final storeName = result['storeName'] as String;
    final date = result['date'] as DateTime;
    final total = result['total'] as double;
    final items = result['items'] as List<ReceiptItem>;
    final categoryId = result['categoryId'] as String?;

    // Create the transaction
    final txId = _uuid.v4();
    final transaction = Transaction(
      id: txId,
      categoryId: categoryId,
      amount: total,
      date: date,
      note: 'Receipt: $storeName',
      type: TransactionType.expense,
    );
    budget.addTransaction(transaction);

    // Build receipt with denormalized store on each item
    final receiptId = _uuid.v4();
    final finalItems = items
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
      transactionId: txId,
      imagePath: imagePath ?? '',
      itemsJson: '',
    );
    receipt.items = finalItems;

    await receiptProvider.addReceipt(receipt);

    if (!mounted) return;

    setState(() => _state = _ScanState.done);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Saved — ${formatCurrency(total, budget.currency)} added from $storeName'),
        backgroundColor: AppColors.income,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: switch (_state) {
          _ScanState.processing => _buildProcessing(),
          _ScanState.error => _buildError(),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }

  Widget _buildProcessing() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Reading your receipt...',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Gemini AI is analyzing the image',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.expense, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Could not read receipt',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _state = _ScanState.picking;
                      _errorMessage = '';
                    });
                    _start();
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  child: const Text('Try Again',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
