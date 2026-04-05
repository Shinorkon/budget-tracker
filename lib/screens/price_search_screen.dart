import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/budget_provider.dart';
import '../models/receipt_model.dart';
import '../models/receipt_provider.dart';
import '../services/price_search_service.dart';
import '../utils/formatters.dart';

class PriceSearchScreen extends StatefulWidget {
  const PriceSearchScreen({super.key});

  @override
  State<PriceSearchScreen> createState() => _PriceSearchScreenState();
}

class _PriceSearchScreenState extends State<PriceSearchScreen> {
  final _searchCtrl = TextEditingController();
  List<PriceSearchResult> _results = [];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _search(String query, List<ReceiptItemEntry> allEntries) {
    setState(() {
      _results = PriceSearchService.search(query, allEntries);
    });
  }

  @override
  Widget build(BuildContext context) {
    final receiptProvider = Provider.of<ReceiptProvider>(context);
    final budget = Provider.of<BudgetProvider>(context);
    final entries = receiptProvider.allItemEntries;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Price Check',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: (q) => _search(q, entries),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search items (e.g. "milk", "rice")',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textMuted),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: AppColors.textMuted, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _search('', entries);
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppColors.surfaceLight,
              ),
            ),
          ),

          // Results
          Expanded(
            child: _searchCtrl.text.isEmpty
                ? _buildHint(entries.isEmpty)
                : _results.isEmpty
                    ? _buildNoResults()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        itemCount: _results.length,
                        itemBuilder: (context, i) => _ResultCard(
                          result: _results[i],
                          currency: budget.currency,
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHint(bool noData) {
    if (noData) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_rounded,
                color: AppColors.textMuted, size: 56),
            SizedBox(height: 16),
            Text('No receipt data yet',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text('Scan some receipts first to compare prices',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.price_check_rounded,
              color: AppColors.textMuted, size: 56),
          SizedBox(height: 16),
          Text('Compare prices across stores',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          Text('Type a product name to see where it\'s cheapest',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded,
              color: AppColors.textMuted, size: 48),
          const SizedBox(height: 12),
          Text(
            'No matches for "${_searchCtrl.text}"',
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text('Try a different search term',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final PriceSearchResult result;
  final String currency;

  const _ResultCard({required this.result, required this.currency});

  @override
  Widget build(BuildContext context) {
    final lowest = result.lowestPrice;
    final highest = result.highestPrice;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Icon(Icons.shopping_basket_rounded,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.canonicalName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // Best price chip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.income.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.income.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.trending_down_rounded,
                          color: AppColors.income, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        result.cheapestStore,
                        style: const TextStyle(
                          color: AppColors.income,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Container(height: 1, color: AppColors.border.withValues(alpha: 0.4)),

          // Occurrences
          ...result.occurrences.map((occ) {
            final isCheapest = occ.unitPrice == lowest;
            final isMostExpensive =
                occ.unitPrice == highest && lowest != highest;
            final priceColor = isCheapest
                ? AppColors.income
                : isMostExpensive
                    ? AppColors.expense
                    : AppColors.textPrimary;

            return Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Store name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          occ.storeName.isEmpty ? 'Unknown Store' : occ.storeName,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                        ),
                        Text(
                          _relativeDate(occ.date),
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  // Price + badge
                  Row(
                    children: [
                      if (isCheapest)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(Icons.star_rounded,
                              color: AppColors.income, size: 14),
                        ),
                      Text(
                        formatCurrency(occ.unitPrice, currency),
                        style: TextStyle(
                          color: priceColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  String _relativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).round()} weeks ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).round()} months ago';
    return formatDate(date);
  }
}
