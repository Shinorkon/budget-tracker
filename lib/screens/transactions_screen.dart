import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../theme/app_theme.dart';
import '../models/budget_provider.dart';
import '../models/budget_model.dart';
import '../utils/formatters.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Transaction> _filteredTransactions(BudgetProvider budget) {
    List<Transaction> txns;
    switch (_tabController.index) {
      case 1:
        txns = budget.expensesForMonth;
        break;
      case 2:
        txns = budget.incomesForMonth;
        break;
      default:
        txns = budget.transactionsForMonth;
    }

    if (_searchQuery.isNotEmpty) {
      txns = txns.where((t) {
        final cat = budget.getCategoryById(t.categoryId);
        final catName = cat?.name.toLowerCase() ?? '';
        final note = t.note.toLowerCase();
        final q = _searchQuery.toLowerCase();
        return catName.contains(q) || note.contains(q);
      }).toList();
    }

    return txns;
  }

  @override
  Widget build(BuildContext context) {
    final budget = Provider.of<BudgetProvider>(context);
    final filteredTxns = _filteredTransactions(budget);

    // Group transactions by date
    final grouped = <String, List<Transaction>>{};
    for (final t in filteredTxns) {
      final key = formatDateShort(t.date);
      grouped.putIfAbsent(key, () => []).add(t);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Text(
                    'Transactions',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const Spacer(),
                  // Month indicator
                  GestureDetector(
                    onTap: () => budget.goToCurrentMonth(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        budget.selectedMonthLabel,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search transactions...',
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            // Tabs
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.primary,
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: const [
                    Tab(text: 'All'),
                    Tab(text: 'Expenses'),
                    Tab(text: 'Income'),
                  ],
                ),
              ),
            ),

            // Summary
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(
                    '${filteredTxns.length} transactions',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13),
                  ),
                  const Spacer(),
                  Text(
                    'Total: ${formatCurrency(filteredTxns.fold(0.0, (sum, t) => sum + (t.type == TransactionType.income ? t.amount : -t.amount)), budget.currency)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Transaction list
            Expanded(
              child: filteredTxns.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            color: AppColors.textMuted.withValues(alpha: 0.5),
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No matching transactions'
                                : 'No transactions this month',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppColors.textMuted,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap + to add one',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      itemCount: grouped.entries.length,
                      itemBuilder: (context, sectionIndex) {
                        final entry = grouped.entries.elementAt(sectionIndex);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date header
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            // Transactions for this date
                            ...entry.value.map((t) {
                              final cat = budget.getCategoryById(t.categoryId);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Slidable(
                                  endActionPane: ActionPane(
                                    motion: const DrawerMotion(),
                                    children: [
                                      SlidableAction(
                                        onPressed: (_) =>
                                            _confirmDelete(context, budget, t),
                                        backgroundColor: AppColors.expense,
                                        foregroundColor: Colors.white,
                                        icon: Icons.delete_rounded,
                                        label: 'Delete',
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ],
                                  ),
                                  child: _TransactionCard(
                                    transaction: t,
                                    category: cat,
                                    currency: budget.currency,
                                  ),
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, BudgetProvider budget, Transaction t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Transaction'),
        content: Text(
          'Are you sure you want to delete this ${t.type == TransactionType.income ? "income" : "expense"} of ${formatCurrency(t.amount, budget.currency)}?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              budget.deleteTransaction(t.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Transaction deleted'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final Category? category;
  final String currency;

  const _TransactionCard({
    required this.transaction,
    required this.category,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final color = isIncome ? AppColors.income : AppColors.expense;
    final sign = isIncome ? '+' : '-';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (category?.color ?? color).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isIncome
                  ? Icons.arrow_downward_rounded
                  : (category?.icon ?? Icons.remove_rounded),
              color: category?.color ?? color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isIncome ? 'Income' : (category?.name ?? 'Expense'),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (transaction.note.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    transaction.note,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$sign${formatCurrency(transaction.amount, currency)}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatDate(transaction.date),
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
