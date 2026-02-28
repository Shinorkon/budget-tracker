import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../models/budget_provider.dart';
import '../models/budget_model.dart';
import '../utils/formatters.dart';
import 'main_layout.dart';
import 'categories_screen.dart';

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
      backgroundColor: AppColors.background,
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A1F35), Color(0xFF151929)],
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

            // ─── Spending by category ─────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Text(
                  'Spending by Category',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),

            // Pie chart
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppDecorations.glassCard,
                  child: budget.expensesByCategory.isEmpty
                      ? SizedBox(
                          height: 180,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.pie_chart_outline_rounded,
                                  color: AppColors.textMuted,
                                  size: 48,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No expenses this month',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppColors.textMuted,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tap + to add your first expense',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        )
                      : SizedBox(
                          height: 200,
                          child: Row(
                            children: [
                              Expanded(
                                child: PieChart(
                                  PieChartData(
                                    sections: _buildPieSections(budget),
                                    sectionsSpace: 3,
                                    centerSpaceRadius: 36,
                                    startDegreeOffset: -90,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: _buildLegend(budget),
                                ),
                              ),
                            ],
                          ),
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
                        onPressed: () {},
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

  List<PieChartSectionData> _buildPieSections(BudgetProvider budget) {
    final expByCategory = budget.expensesByCategory;
    final total = expByCategory.values.fold(0.0, (sum, v) => sum + v);
    return expByCategory.entries.map((entry) {
      final cat = budget.getCategoryById(entry.key);
      final percentage = (entry.value / total * 100);
      return PieChartSectionData(
        value: entry.value,
        color: cat?.color ?? AppColors.textMuted,
        title: '${percentage.toStringAsFixed(0)}%',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  List<Widget> _buildLegend(BudgetProvider budget) {
    final expByCategory = budget.expensesByCategory;
    return expByCategory.entries.take(6).map((entry) {
      final cat = budget.getCategoryById(entry.key);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: cat?.color ?? AppColors.textMuted,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                cat?.name ?? 'Unknown',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }).toList();
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
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 20),
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOverBudget
              ? AppColors.expense.withValues(alpha: 0.5)
              : AppColors.border.withValues(alpha: 0.5),
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
                  style: const TextStyle(
                    color: AppColors.textPrimary,
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
              color: isOverBudget ? AppColors.expense : AppColors.textPrimary,
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
                backgroundColor: AppColors.surfaceHighlight,
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
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  transaction.note.isNotEmpty
                      ? transaction.note
                      : formatDateShort(transaction.date),
                  style: const TextStyle(
                    color: AppColors.textMuted,
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
              Icon(Icons.edit_rounded,
                  color: AppColors.textMuted.withValues(alpha: 0.5), size: 14),
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
  late String? _selectedCategoryId;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.transaction.amount.toStringAsFixed(2),
    );
    _noteController = TextEditingController(text: widget.transaction.note);
    _selectedCategoryId = widget.transaction.categoryId;
    _selectedDate = widget.transaction.date;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final budget = Provider.of<BudgetProvider>(context);
    final isExpense = widget.transaction.type == TransactionType.expense;
    final accentColor = isExpense ? AppColors.expense : AppColors.income;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
              color: AppColors.textMuted,
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

                    // Date
                    GestureDetector(
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
                            const SizedBox(width: 12),
                            Text(formatDate(_selectedDate),
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 15)),
                            const Spacer(),
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

  void _save(BudgetProvider budget) {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final isExpense = widget.transaction.type == TransactionType.expense;
    if (isExpense && _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a category'),
          backgroundColor: AppColors.expense,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final updated = widget.transaction.copyWith(
      amount: double.parse(_amountController.text),
      categoryId: _selectedCategoryId,
      note: _noteController.text.trim(),
      date: _selectedDate,
    );

    budget.updateTransaction(widget.transaction.id, updated);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Transaction updated'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
