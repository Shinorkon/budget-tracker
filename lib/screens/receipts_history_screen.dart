import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/budget_provider.dart';
import '../models/receipt_model.dart';
import '../models/receipt_provider.dart';
import '../utils/formatters.dart';
import 'price_search_screen.dart';

class ReceiptsHistoryScreen extends StatelessWidget {
  const ReceiptsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final receiptProvider = Provider.of<ReceiptProvider>(context);
    final budget = Provider.of<BudgetProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Receipts',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon:
                const Icon(Icons.search_rounded, color: AppColors.textSecondary),
            tooltip: 'Price search',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const PriceSearchScreen()),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: receiptProvider.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : receiptProvider.receipts.isEmpty
              ? _buildEmpty(context)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: receiptProvider.receipts.length,
                  itemBuilder: (context, index) {
                    final receipt = receiptProvider.receipts[index];
                    return ReceiptCard(
                      receipt: receipt,
                      currency: budget.currency,
                      onDelete: () => _confirmDelete(
                          context, receipt, receiptProvider),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ReceiptDetailScreen(
                            receipt: receipt,
                            currency: budget.currency,
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.receipt_long_rounded,
              color: AppColors.textMuted, size: 64),
          const SizedBox(height: 16),
          const Text('No receipts yet',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Scan a receipt using the + button',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Receipt receipt,
    ReceiptProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Receipt',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Delete receipt from "${receipt.storeName}"? The associated transaction will NOT be deleted.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.deleteReceipt(receipt.id);
    }
  }
}

class ReceiptCard extends StatelessWidget {
  final Receipt receipt;
  final String currency;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const ReceiptCard({
    required this.receipt,
    required this.currency,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Slidable(
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => onDelete(),
              backgroundColor: AppColors.expense,
              foregroundColor: Colors.white,
              icon: Icons.delete_rounded,
              label: 'Delete',
              borderRadius: BorderRadius.circular(14),
            ),
          ],
        ),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                // Thumbnail or placeholder
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(14)),
                  child: receipt.imagePathOrNull != null
                      ? Image.file(
                          File(receipt.imagePathOrNull!),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          receipt.storeName.isEmpty
                              ? 'Unknown Store'
                              : receipt.storeName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatDate(receipt.date),
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${receipt.items.length} item${receipt.items.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Text(
                    formatCurrency(receipt.total, currency),
                    style: const TextStyle(
                      color: AppColors.expense,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 80,
      height: 80,
      color: AppColors.surfaceLight,
      child: const Icon(Icons.receipt_long_rounded,
          color: AppColors.textMuted, size: 28),
    );
  }
}

// ─── Receipt Detail Screen ─────────────────────────────────────────────────

class ReceiptDetailScreen extends StatelessWidget {
  final Receipt receipt;
  final String currency;

  const ReceiptDetailScreen({
    required this.receipt,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final items = receipt.items;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          receipt.storeName.isEmpty ? 'Receipt' : receipt.storeName,
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Image
          if (receipt.imagePathOrNull != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(
                File(receipt.imagePathOrNull!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Meta
          _metaRow(
              Icons.storefront_rounded,
              receipt.storeName.isEmpty ? 'Unknown Store' : receipt.storeName),
          const SizedBox(height: 8),
          _metaRow(Icons.calendar_today_rounded, formatDate(receipt.date)),
          const SizedBox(height: 20),

          // Items header
          const Text(
            'Items',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),

          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No items recorded',
                  style:
                      TextStyle(color: AppColors.textMuted, fontSize: 14)),
            )
          else
            ...items.map((item) => _ItemRow(item: item, currency: currency)),

          const Divider(color: AppColors.border, height: 32),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              Text(
                formatCurrency(receipt.total, currency),
                style: const TextStyle(
                  color: AppColors.expense,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: AppColors.textMuted, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'The associated transaction was not deleted and must be managed from the Transactions screen.',
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _metaRow(IconData icon, String text) => Row(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 18),
          const SizedBox(width: 10),
          Text(text,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 15)),
        ],
      );
}

class _ItemRow extends StatelessWidget {
  final ReceiptItem item;
  final String currency;

  const _ItemRow({required this.item, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.canonicalName.isEmpty ? item.rawName : item.canonicalName,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
                if (item.rawName.isNotEmpty &&
                    item.rawName != item.canonicalName)
                  Text(
                    item.rawName,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatCurrency(item.unitPrice, currency),
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
              if (item.quantity > 1)
                Text(
                  '× ${item.quantity}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
