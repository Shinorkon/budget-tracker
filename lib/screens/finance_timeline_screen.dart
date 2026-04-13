import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/budget_model.dart';
import '../models/budget_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Vertical, reverse-chronological timeline of every transaction ever
/// recorded — complementary to [CalendarScreen]'s month grid, not a
/// replacement. Users asked for a way to see salary deposits and expenses on
/// a single scrollable surface across months, quarters, and years.
class FinanceTimelineScreen extends StatefulWidget {
  const FinanceTimelineScreen({super.key});

  @override
  State<FinanceTimelineScreen> createState() => _FinanceTimelineScreenState();
}

enum _TypeFilter { all, income, expense }

enum _GroupBy { month, quarter, year }

class _FinanceTimelineScreenState extends State<FinanceTimelineScreen> {
  _TypeFilter _type = _TypeFilter.all;
  _GroupBy _group = _GroupBy.month;

  @override
  Widget build(BuildContext context) {
    final budget = Provider.of<BudgetProvider>(context);
    final txns = _filteredTransactions(budget.transactions);
    final grouped = _groupTransactions(txns);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: AppColors.textPrimary, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('Finance Timeline',
                        style: Theme.of(context).textTheme.headlineMedium),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: _TypeToggle(
                  value: _type,
                  onChanged: (v) => setState(() => _type = v),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: _GroupToggle(
                  value: _group,
                  onChanged: (v) => setState(() => _group = v),
                ),
              ),
            ),
            if (grouped.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.history_rounded,
                            color: AppColors.textMuted, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'No transactions to show',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final group = grouped[index];
                      return _TimelineGroup(
                        title: group.title,
                        transactions: group.transactions,
                        budget: budget,
                      );
                    },
                    childCount: grouped.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Transaction> _filteredTransactions(List<Transaction> all) {
    final filtered = switch (_type) {
      _TypeFilter.all => List<Transaction>.from(all),
      _TypeFilter.income =>
        all.where((t) => t.type == TransactionType.income).toList(),
      _TypeFilter.expense =>
        all.where((t) => t.type == TransactionType.expense).toList(),
    };
    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }

  List<_Group> _groupTransactions(List<Transaction> txns) {
    final groups = <String, _Group>{};
    for (final t in txns) {
      final key = _groupKey(t.date);
      final title = _groupTitle(t.date);
      groups.putIfAbsent(
          key, () => _Group(key: key, title: title, transactions: []));
      groups[key]!.transactions.add(t);
    }
    return groups.values.toList()..sort((a, b) => b.key.compareTo(a.key));
  }

  String _groupKey(DateTime d) {
    switch (_group) {
      case _GroupBy.month:
        return '${d.year}-${d.month.toString().padLeft(2, "0")}';
      case _GroupBy.quarter:
        final q = ((d.month - 1) ~/ 3) + 1;
        return '${d.year}-Q$q';
      case _GroupBy.year:
        return '${d.year}';
    }
  }

  String _groupTitle(DateTime d) {
    switch (_group) {
      case _GroupBy.month:
        return formatMonthYear(d);
      case _GroupBy.quarter:
        final q = ((d.month - 1) ~/ 3) + 1;
        return 'Q$q ${d.year}';
      case _GroupBy.year:
        return '${d.year}';
    }
  }
}

class _Group {
  final String key;
  final String title;
  final List<Transaction> transactions;

  _Group({required this.key, required this.title, required this.transactions});
}

class _TypeToggle extends StatelessWidget {
  final _TypeFilter value;
  final ValueChanged<_TypeFilter> onChanged;

  const _TypeToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _SegmentedPicker<_TypeFilter>(
      value: value,
      onChanged: onChanged,
      segments: const [
        (_TypeFilter.all, 'All', Icons.all_inclusive_rounded),
        (_TypeFilter.income, 'Income', Icons.arrow_downward_rounded),
        (_TypeFilter.expense, 'Expenses', Icons.arrow_upward_rounded),
      ],
    );
  }
}

class _GroupToggle extends StatelessWidget {
  final _GroupBy value;
  final ValueChanged<_GroupBy> onChanged;

  const _GroupToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _SegmentedPicker<_GroupBy>(
      value: value,
      onChanged: onChanged,
      segments: const [
        (_GroupBy.month, 'Month', Icons.calendar_view_month_rounded),
        (_GroupBy.quarter, 'Quarter', Icons.calendar_view_week_rounded),
        (_GroupBy.year, 'Year', Icons.event_note_rounded),
      ],
    );
  }
}

class _SegmentedPicker<T> extends StatelessWidget {
  final T value;
  final ValueChanged<T> onChanged;
  final List<(T, String, IconData)> segments;

  const _SegmentedPicker({
    required this.value,
    required this.onChanged,
    required this.segments,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: segments.map((s) {
          final selected = s.$1 == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(s.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(s.$3,
                        size: 16,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      s.$2,
                      style: TextStyle(
                        color: selected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TimelineGroup extends StatelessWidget {
  final String title;
  final List<Transaction> transactions;
  final BudgetProvider budget;

  const _TimelineGroup({
    required this.title,
    required this.transactions,
    required this.budget,
  });

  @override
  Widget build(BuildContext context) {
    final income = transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + t.amount);
    final expense = transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + t.amount);
    final net = income - expense;
    final currency = budget.currency;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Sticky-ish header (visually — it's inside the card).
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${transactions.length} entr${transactions.length == 1 ? "y" : "ies"}',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _stat(
                        label: 'Income',
                        value: formatCurrencyShort(income, currency),
                        color: AppColors.income),
                    const SizedBox(width: 12),
                    _stat(
                        label: 'Expense',
                        value: formatCurrencyShort(expense, currency),
                        color: AppColors.expense),
                    const SizedBox(width: 12),
                    _stat(
                        label: 'Net',
                        value: formatCurrencyShort(net, currency),
                        color: net >= 0 ? AppColors.income : AppColors.expense),
                  ],
                ),
              ],
            ),
          ),
          ...transactions.map((t) {
            final cat = budget.getCategoryById(t.categoryId);
            return _TimelineEntry(transaction: t, category: cat, currency: currency);
          }),
        ],
      ),
    );
  }

  Widget _stat(
      {required String label, required String value, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 10)),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final Transaction transaction;
  final Category? category;
  final String currency;

  const _TimelineEntry({
    required this.transaction,
    required this.category,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final color = isIncome ? AppColors.income : AppColors.expense;
    final sign = isIncome ? '+' : '-';
    final isSalary =
        isIncome && transaction.storeName.toLowerCase().contains('salary');

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (category?.color ?? color).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isSalary
                  ? Icons.bolt_rounded
                  : (isIncome
                      ? Icons.arrow_downward_rounded
                      : (category?.icon ?? Icons.remove_rounded)),
              color: isSalary ? AppColors.income : (category?.color ?? color),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.storeName.isNotEmpty
                      ? transaction.storeName
                      : (isIncome ? 'Income' : (category?.name ?? 'Expense')),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  formatDateShort(transaction.date),
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '$sign${formatCurrency(transaction.amount, currency)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
