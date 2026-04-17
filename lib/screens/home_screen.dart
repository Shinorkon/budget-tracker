import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../models/budget_provider.dart';
import '../models/budget_model.dart';
import '../services/receipt_scan_queue.dart';
import '../utils/formatters.dart';
import 'main_layout.dart';
import 'categories_screen.dart';
import 'transactions_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final budget = Provider.of<BudgetProvider>(context);

    if (budget.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ─── Header ───────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Budget Tracker',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          _getGreeting(),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ─── Month selector ───────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _MonthArrowButton(
                      icon: Icons.chevron_left_rounded,
                      onTap: budget.prevMonth,
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => budget.goToCurrentMonth(),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          budget.selectedMonthLabel,
                          key: ValueKey(budget.selectedMonthLabel),
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    _MonthArrowButton(
                      icon: Icons.chevron_right_rounded,
                      onTap: budget.nextMonth,
                    ),
                  ],
                ),
              ),
            ),

            // ─── Balance card ─────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: Theme.of(context).brightness == Brightness.dark
                          ? [const Color(0xFF1A1F35), const Color(0xFF151929)]
                          : [const Color(0xFFEEF1F8), const Color(0xFFE8EBF5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Balance',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                              letterSpacing: 1,
                            ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          formatCurrency(budget.balance, budget.currency),
                          key: ValueKey(budget.balance),
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(
                                color: budget.balance >= 0
                                    ? AppColors.income
                                    : AppColors.expense,
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Income / Expense row — TAPPABLE
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryTile(
                              label: 'Income',
                              amount: budget.totalIncomeForMonth,
                              currency: budget.currency,
                              icon: Icons.trending_up_rounded,
                              color: AppColors.income,
                              gradient: AppColors.incomeGradient,
                              onTap: () =>
                                  _openAddTransaction(context, tabIndex: 1),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SummaryTile(
                              label: 'Expenses',
                              amount: budget.totalExpensesForMonth,
                              currency: budget.currency,
                              icon: Icons.trending_down_rounded,
                              color: AppColors.expense,
                              gradient: AppColors.expenseGradient,
                              onTap: () =>
                                  _openAddTransaction(context, tabIndex: 0),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ─── Category cards — TAPPABLE ────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Row(
                  children: [
                    Text(
                      'Categories',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CategoriesScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.tune_rounded,
                                color: AppColors.primary, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Manage',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.6,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index < budget.categories.length) {
                      final cat = budget.categories[index];
                      final spent = budget.expensesForCategory(cat.id);
                      return GestureDetector(
                        onTap: () => _openAddTransaction(
                          context,
                          tabIndex: 0,
                          categoryId: cat.id,
                        ),
                        child: _CategoryCard(
                          category: cat,
                          spent: spent,
                          currency: budget.currency,
                        ),
                      );
                    }
                    return null;
                  },
                  childCount: budget.categories.length,
                ),
              ),
            ),

            // ─── Recent transactions — TAPPABLE ───────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Transactions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (budget.transactionsForMonth.length > 5)
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const TransactionsScreen()),
                          );
                        },
                        child: const Text('See All',
                            style: TextStyle(color: AppColors.primary)),
                      ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              sliver: budget.transactionsForMonth.isEmpty
                  ? SliverToBoxAdapter(
                      child: GestureDetector(
                        onTap: () => _openAddTransaction(context),
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: AppDecorations.subtleCard,
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long_rounded,
                                  color: AppColors.textMuted, size: 40),
                              const SizedBox(height: 12),
                              Text(
                                'No transactions yet',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: AppColors.textMuted),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap here to add one',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final txns =
                              budget.transactionsForMonth.take(5).toList();
                          if (index >= txns.length) return null;
                          final t = txns[index];
                          final cat = budget.getCategoryById(t.categoryId);
                          return GestureDetector(
                            onTap: () =>
                                _showEditTransactionSheet(context, t, budget),
                            child: _TransactionTile(
                              transaction: t,
                              category: cat,
                              currency: budget.currency,
                              isLast: index == txns.length - 1,
                            ),
                          );
                        },
                        childCount: budget.transactionsForMonth.take(5).length,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────

  void _openAddTransaction(
    BuildContext context, {
    int tabIndex = 0,
    String? categoryId,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionSheet(
        initialTabIndex: tabIndex,
        initialCategoryId: categoryId,
      ),
    );
  }

  void _showEditTransactionSheet(
    BuildContext context,
    Transaction transaction,
    BudgetProvider budget,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditTransactionSheet(
        transaction: transaction,
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning 👋';
    if (hour < 17) return 'Good afternoon ☀️';
    return 'Good evening 🌙';
  }
}

// ─── Widgets ────────────────────────────────────────────────

class _MonthArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MonthArrowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.onSurface, size: 20),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final double amount;
  final String currency;
  final IconData icon;
  final Color color;
  final LinearGradient gradient;
  final VoidCallback? onTap;

  const _SummaryTile({
    required this.label,
    required this.amount,
    required this.currency,
    required this.icon,
    required this.color,
    required this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                const Spacer(),
                Icon(Icons.add_circle_outline_rounded,
                    color: color.withValues(alpha: 0.6), size: 16),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              formatCurrencyShort(amount, currency),
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final Category category;
  final double spent;
  final String currency;

  const _CategoryCard({
    required this.category,
    required this.spent,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final hasLimit = category.budgetLimit > 0;
    final progress =
        hasLimit ? (spent / category.budgetLimit).clamp(0.0, 1.0) : 0.0;
    final isOverBudget = hasLimit && spent > category.budgetLimit;

    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOverBudget
              ? AppColors.expense.withValues(alpha: 0.5)
              : theme.dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(category.icon, color: category.color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  category.name,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.add_rounded,
                color: category.color.withValues(alpha: 0.5),
                size: 18,
              ),
            ],
          ),
          const Spacer(),
          Text(
            formatCurrencyShort(spent, currency),
            style: TextStyle(
              color: isOverBudget ? AppColors.expense : theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          if (hasLimit) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  isOverBudget ? AppColors.expense : category.color,
                ),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final Category? category;
  final String currency;
  final bool isLast;

  const _TransactionTile({
    required this.transaction,
    required this.category,
    required this.currency,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final color = isIncome ? AppColors.income : AppColors.expense;
    final sign = isIncome ? '+' : '-';

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.subtleCard,
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
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  transaction.note.isNotEmpty
                      ? transaction.note
                      : transaction.storeNameOrNull ??
                          formatDateShort(transaction.date),
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 12,
                  ),
                ),
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (transaction.imagePathOrNull != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(Icons.receipt_rounded,
                          color: AppColors.primary.withValues(alpha: 0.6),
                          size: 14),
                    ),
                  Icon(Icons.edit_rounded,
                      color: AppColors.textMuted.withValues(alpha: 0.5),
                      size: 14),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Edit Transaction Sheet ─────────────────────────────────

class _EditTransactionSheet extends StatefulWidget {
  final Transaction transaction;

  const _EditTransactionSheet({required this.transaction});

  @override
  State<_EditTransactionSheet> createState() => _EditTransactionSheetState();
}

class _EditTransactionSheetState extends State<_EditTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late TextEditingController _storeController;
  late String? _selectedCategoryId;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  String? _imagePath;
  bool _defaultCategoryQueued = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.transaction.amount.toStringAsFixed(2),
    );
    _noteController = TextEditingController(text: widget.transaction.note);
    _storeController =
        TextEditingController(text: widget.transaction.storeName);
    _selectedCategoryId = widget.transaction.categoryId;
    _selectedDate = widget.transaction.date;
    _selectedTime = TimeOfDay.fromDateTime(widget.transaction.date);
    _imagePath = widget.transaction.imagePathOrNull;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _storeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final budget = Provider.of<BudgetProvider>(context);
    final isExpense = widget.transaction.type == TransactionType.expense;
    final accentColor = isExpense ? AppColors.expense : AppColors.income;
    _ensureDefaultCategory(budget, isExpense);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).textTheme.bodySmall?.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Edit ${isExpense ? "Expense" : "Income"}',
                  style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isExpense ? 'EXPENSE' : 'INCOME',
              style: TextStyle(
                color: accentColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Form
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Amount
                    TextFormField(
                      controller: _amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: '0.00',
                        suffixText: budget.currency,
                        suffixStyle: const TextStyle(
                            fontSize: 16, color: AppColors.textSecondary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppColors.surfaceLight,
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter an amount';
                        final amount = double.tryParse(v);
                        if (amount == null || amount <= 0)
                          return 'Enter a valid amount';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Category (expense only)
                    if (isExpense) ...[
                      const Text(
                        'Category',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: budget.categories.map((cat) {
                          final isSelected = _selectedCategoryId == cat.id;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedCategoryId = cat.id),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? cat.color.withValues(alpha: 0.2)
                                    : AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      isSelected ? cat.color : AppColors.border,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(cat.icon, color: cat.color, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    cat.name,
                                    style: TextStyle(
                                      color: isSelected
                                          ? cat.color
                                          : AppColors.textSecondary,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Note
                    TextFormField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        hintText: 'Add a note (optional)',
                        prefixIcon: Icon(Icons.notes_rounded,
                            color: AppColors.textMuted),
                      ),
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 16),

                    // Store / Location
                    TextFormField(
                      controller: _storeController,
                      decoration: const InputDecoration(
                        hintText: 'Store / Location (optional)',
                        prefixIcon: Icon(Icons.store_rounded,
                            color: AppColors.textMuted),
                      ),
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 16),

                    // Date & Time row
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded,
                                      color: AppColors.textMuted, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(formatDate(_selectedDate),
                                        style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 14)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _pickTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_rounded,
                                    color: AppColors.textMuted, size: 20),
                                const SizedBox(width: 10),
                                Text(_selectedTime.format(context),
                                    style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Receipt / Image attachment
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _imagePath != null
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _imagePath != null
                                  ? Icons.check_circle_rounded
                                  : Icons.camera_alt_rounded,
                              color: _imagePath != null
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _imagePath != null
                                    ? 'Receipt attached'
                                    : 'Attach receipt / image (optional)',
                                style: TextStyle(
                                  color: _imagePath != null
                                      ? AppColors.textPrimary
                                      : AppColors.textMuted,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (_imagePath != null)
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _imagePath = null),
                                child: const Icon(Icons.close_rounded,
                                    color: AppColors.textMuted, size: 18),
                              )
                            else
                              const Icon(Icons.chevron_right_rounded,
                                  color: AppColors.textMuted),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Buttons row
                    Row(
                      children: [
                        // Delete button
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: () => _confirmDelete(budget),
                              icon: const Icon(Icons.delete_rounded, size: 18),
                              label: const Text('Delete'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.expense,
                                side:
                                    const BorderSide(color: AppColors.expense),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Save button
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: () => _save(budget),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text(
                                'Save Changes',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded,
                  color: AppColors.primary),
              title: const Text('Camera',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppColors.primary),
              title: const Text('Gallery',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: source, imageQuality: 70);
    if (xFile == null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final fileName = 'txn_${const Uuid().v4()}.jpg';
    final saved = await File(xFile.path).copy('${appDir.path}/$fileName');
    setState(() => _imagePath = saved.path);
  }

  void _ensureDefaultCategory(BudgetProvider budget, bool isExpense) {
    if (!isExpense || _selectedCategoryId != null) return;
    if (budget.categories.isEmpty || _defaultCategoryQueued) return;

    _defaultCategoryQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _defaultCategoryQueued = false;
      if (!mounted || !isExpense || _selectedCategoryId != null) return;
      if (budget.categories.isEmpty) return;
      setState(() => _selectedCategoryId = budget.categories.first.id);
    });
  }

  void _save(BudgetProvider budget) {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final dateWithTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final updated = widget.transaction.copyWith(
      amount: double.parse(_amountController.text),
      categoryId: _selectedCategoryId,
      note: _noteController.text.trim(),
      date: dateWithTime,
      storeName: _storeController.text.trim(),
      imagePath: _imagePath ?? '',
    );

    budget.updateTransaction(widget.transaction.id, updated);

    final attachedNew = _imagePath != null &&
        _imagePath != widget.transaction.imagePathOrNull;

    Navigator.of(context).pop();

    if (attachedNew) {
      unawaited(_scanAttachedReceipt(_imagePath!, updated));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(attachedNew
            ? 'Transaction updated — scanning receipt in background.'
            : 'Transaction updated'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _scanAttachedReceipt(String path, Transaction txn) async {
    try {
      final bytes = await File(path).readAsBytes();
      await ReceiptScanQueue.instance.enqueueFromBytes(
        rawBytes: bytes,
        transaction: txn,
      );
    } catch (e) {
      debugPrint('home_screen: receipt scan kickoff failed: $e');
    }
  }

  void _confirmDelete(BudgetProvider budget) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Transaction'),
        content: Text(
          'Delete this ${widget.transaction.type == TransactionType.income ? "income" : "expense"} of ${formatCurrency(widget.transaction.amount, budget.currency)}?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              budget.deleteTransaction(widget.transaction.id);
              Navigator.pop(ctx);
              Navigator.of(context).pop();
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
