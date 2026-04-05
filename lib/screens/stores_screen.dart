import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/budget_provider.dart';
import '../models/receipt_model.dart';
import '../models/receipt_provider.dart';
import '../utils/formatters.dart';
import 'receipts_history_screen.dart';

class StoresScreen extends StatelessWidget {
  const StoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final receiptProvider = Provider.of<ReceiptProvider>(context);
    final budget = Provider.of<BudgetProvider>(context);

    if (receiptProvider.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    // Build sorted store list: latest visit first
    final grouped = receiptProvider.receiptsByStore;
    final stores = grouped.entries.toList()
      ..sort((a, b) {
        final latestA = a.value.map((r) => r.date).reduce((x, y) => x.isAfter(y) ? x : y);
        final latestB = b.value.map((r) => r.date).reduce((x, y) => x.isAfter(y) ? x : y);
        return latestB.compareTo(latestA);
      });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: buildIntelligenceAppBar('Stores'),
      body: stores.isEmpty
          ? _buildEmpty()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: stores.length,
              itemBuilder: (context, i) {
                final entry = stores[i];
                final receipts = entry.value
                  ..sort((a, b) => b.date.compareTo(a.date));
                final displayName = receipts.first.storeName.isEmpty
                    ? 'Unknown Store'
                    : receipts.first.storeName;
                final totalSpent =
                    receipts.fold(0.0, (sum, r) => sum + r.total);
                final lastVisit = receipts.first.date;

                return _StoreCard(
                  storeName: displayName,
                  visitCount: receipts.length,
                  totalSpent: totalSpent,
                  lastVisit: lastVisit,
                  currency: budget.currency,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => _StoreDetailScreen(
                      storeName: displayName,
                      receipts: receipts,
                      currency: budget.currency,
                    ),
                  )),
                );
              },
            ),
    );
  }

  Widget _buildEmpty() => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_rounded, color: AppColors.textMuted, size: 64),
            SizedBox(height: 16),
            Text('No stores yet',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text('Scan receipts to track stores',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ],
        ),
      );
}

// ─── Store Card ────────────────────────────────────────────────────────────

class _StoreCard extends StatelessWidget {
  final String storeName;
  final int visitCount;
  final double totalSpent;
  final DateTime lastVisit;
  final String currency;
  final VoidCallback onTap;

  const _StoreCard({
    required this.storeName,
    required this.visitCount,
    required this.totalSpent,
    required this.lastVisit,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            // Icon badge
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.storefront_rounded,
                  color: AppColors.warning, size: 22),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(storeName,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                    '$visitCount visit${visitCount == 1 ? '' : 's'} · Last: ${formatDate(lastVisit)}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            // Total
            Text(
              formatCurrency(totalSpent, currency),
              style: const TextStyle(
                  color: AppColors.expense,
                  fontSize: 15,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Store Detail Screen ───────────────────────────────────────────────────

class _StoreDetailScreen extends StatelessWidget {
  final String storeName;
  final List<Receipt> receipts;
  final String currency;

  const _StoreDetailScreen({
    required this.storeName,
    required this.receipts,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final totalSpent = receipts.fold(0.0, (sum, r) => sum + r.total);
    final avgPerVisit =
        receipts.isEmpty ? 0.0 : totalSpent / receipts.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: buildIntelligenceAppBar(storeName),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats row
          Row(
            children: [
              Expanded(
                child: StatMiniCard(
                    label: 'Visits',
                    value: receipts.length.toString(),
                    color: AppColors.warning),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatMiniCard(
                    label: 'Total Spent',
                    value: formatCurrency(totalSpent, currency),
                    color: AppColors.expense),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatMiniCard(
                    label: 'Avg / Visit',
                    value: formatCurrency(avgPerVisit, currency),
                    color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 20),

          const Text('Receipts',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),

          ...receipts.map((receipt) => ReceiptCard(
                receipt: receipt,
                currency: currency,
                onDelete: () {}, // deletion handled from receipts history
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ReceiptDetailScreen(
                      receipt: receipt, currency: currency),
                )),
              )),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Shared helpers ────────────────────────────────────────────────────────

PreferredSizeWidget buildIntelligenceAppBar(String title) => AppBar(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textSecondary,
      title: Text(title,
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600)),
      centerTitle: true,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.border),
      ),
    );

class StatMiniCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const StatMiniCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

