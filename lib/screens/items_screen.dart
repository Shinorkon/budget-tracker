import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/budget_provider.dart';
import '../models/receipt_model.dart';
import '../models/receipt_provider.dart';
import '../utils/formatters.dart';
import 'stores_screen.dart' show StatMiniCard, buildIntelligenceAppBar;

enum _SortMode { alphabetical, mostBought, cheapest }

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final _searchCtrl = TextEditingController();
  _SortMode _sort = _SortMode.alphabetical;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

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

    final grouped = receiptProvider.itemsByCanonicalName;
    final query = _searchCtrl.text.toLowerCase().trim();

    // Filter
    var entries = grouped.entries
        .where((e) => query.isEmpty || e.key.contains(query))
        .toList();

    // Sort
    switch (_sort) {
      case _SortMode.alphabetical:
        entries.sort((a, b) => a.key.compareTo(b.key));
      case _SortMode.mostBought:
        entries.sort((a, b) => b.value.length.compareTo(a.value.length));
      case _SortMode.cheapest:
        entries.sort((a, b) {
          final minA =
              a.value.map((e) => e.item.unitPrice).reduce((x, y) => x < y ? x : y);
          final minB =
              b.value.map((e) => e.item.unitPrice).reduce((x, y) => x < y ? x : y);
          return minA.compareTo(minB);
        });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: buildIntelligenceAppBar('Items'),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search items...',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textMuted),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: AppColors.textMuted, size: 18),
                        onPressed: () =>
                            setState(() => _searchCtrl.clear()),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppColors.surfaceLight,
                isDense: true,
              ),
            ),
          ),

          // Sort chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                _SortChip(
                  label: 'A–Z',
                  selected: _sort == _SortMode.alphabetical,
                  onTap: () => setState(() => _sort = _SortMode.alphabetical),
                ),
                const SizedBox(width: 8),
                _SortChip(
                  label: 'Most Bought',
                  selected: _sort == _SortMode.mostBought,
                  onTap: () => setState(() => _sort = _SortMode.mostBought),
                ),
                const SizedBox(width: 8),
                _SortChip(
                  label: 'Cheapest',
                  selected: _sort == _SortMode.cheapest,
                  onTap: () => setState(() => _sort = _SortMode.cheapest),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // List
          Expanded(
            child: entries.isEmpty
                ? _buildEmpty(grouped.isEmpty)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    itemCount: entries.length,
                    itemBuilder: (context, i) {
                      final entry = entries[i];
                      final occurrences = entry.value
                        ..sort((a, b) => b.date.compareTo(a.date));
                      final displayName =
                          occurrences.first.item.canonicalName;
                      final prices =
                          occurrences.map((e) => e.item.unitPrice).toList();
                      final minPrice =
                          prices.reduce((a, b) => a < b ? a : b);
                      final maxPrice =
                          prices.reduce((a, b) => a > b ? a : b);
                      final stores = occurrences
                          .map((e) => e.item.storeName)
                          .toSet()
                          .toList();
                      final cheapestStore = occurrences
                          .firstWhere((e) => e.item.unitPrice == minPrice)
                          .item
                          .storeName;

                      return _ItemCard(
                        canonicalName: displayName,
                        buyCount: occurrences.length,
                        storeCount: stores.length,
                        minPrice: minPrice,
                        maxPrice: maxPrice,
                        cheapestStore: cheapestStore,
                        currency: budget.currency,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => _ItemDetailScreen(
                              canonicalName: displayName,
                              occurrences: occurrences,
                              currency: budget.currency,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool noData) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_rounded,
                color: AppColors.textMuted, size: 64),
            const SizedBox(height: 16),
            Text(
              noData ? 'No items yet' : 'No matches',
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              noData
                  ? 'Scan receipts to track purchases'
                  : 'Try a different search',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
}

// ─── Item Card ─────────────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  final String canonicalName;
  final int buyCount;
  final int storeCount;
  final double minPrice;
  final double maxPrice;
  final String cheapestStore;
  final String currency;
  final VoidCallback onTap;

  const _ItemCard({
    required this.canonicalName,
    required this.buyCount,
    required this.storeCount,
    required this.minPrice,
    required this.maxPrice,
    required this.cheapestStore,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final samePrice = (minPrice - maxPrice).abs() < 0.01;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accentLight.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.inventory_2_rounded,
                  color: AppColors.accentLight, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(canonicalName,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                    'Bought $buyCount× · $storeCount store${storeCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Price range
                      Text(
                        samePrice
                            ? formatCurrency(minPrice, currency)
                            : '${formatCurrency(minPrice, currency)} – ${formatCurrency(maxPrice, currency)}',
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      // Cheapest store badge
                      if (cheapestStore.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.income.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: AppColors.income.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.trending_down_rounded,
                                  color: AppColors.income, size: 11),
                              const SizedBox(width: 3),
                              Text(cheapestStore,
                                  style: const TextStyle(
                                      color: AppColors.income,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Item Detail Screen ────────────────────────────────────────────────────

class _ItemDetailScreen extends StatelessWidget {
  final String canonicalName;
  final List<ReceiptItemEntry> occurrences;
  final String currency;

  const _ItemDetailScreen({
    required this.canonicalName,
    required this.occurrences,
    required this.currency,
  });

  String _relativeDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).round()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).round()}mo ago';
    return formatDate(date);
  }

  @override
  Widget build(BuildContext context) {
    final prices = occurrences.map((e) => e.item.unitPrice).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final totalBought =
        occurrences.fold(0, (sum, e) => sum + e.item.quantity);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: buildIntelligenceAppBar(canonicalName),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats row
          Row(
            children: [
              Expanded(
                child: StatMiniCard(
                    label: 'Purchases',
                    value: occurrences.length.toString(),
                    color: AppColors.accentLight),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatMiniCard(
                    label: 'Lowest',
                    value: formatCurrency(minPrice, currency),
                    color: AppColors.income),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatMiniCard(
                    label: 'Highest',
                    value: formatCurrency(maxPrice, currency),
                    color: AppColors.expense),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Total bought: $totalBought unit${totalBought == 1 ? '' : 's'}',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),

          const Text('Purchase History',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),

          ...occurrences.map((entry) {
            final isCheapest = entry.item.unitPrice == minPrice;
            final isMostExpensive =
                entry.item.unitPrice == maxPrice && minPrice != maxPrice;
            final priceColor = isCheapest
                ? AppColors.income
                : isMostExpensive
                    ? AppColors.expense
                    : AppColors.textPrimary;

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
                          entry.item.storeName.isEmpty
                              ? 'Unknown Store'
                              : entry.item.storeName,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                        ),
                        Text(
                          _relativeDate(entry.date),
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          if (isCheapest)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(Icons.star_rounded,
                                  color: AppColors.income, size: 13),
                            ),
                          Text(
                            formatCurrency(entry.item.unitPrice, currency),
                            style: TextStyle(
                                color: priceColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      if (entry.item.quantity > 1)
                        Text(
                          '× ${entry.item.quantity}',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 11),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Sort Chip ─────────────────────────────────────────────────────────────

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.2)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primary : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
