import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../models/budget_provider.dart';
import '../utils/formatters.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final budget = Provider.of<BudgetProvider>(context);
    final expData = budget.last6MonthsExpenses;
    final incData = budget.last6MonthsIncome;
    final maxY = [
      ...expData.map((e) => e.value),
      ...incData.map((e) => e.value),
    ].fold(0.0, (a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Text(
                  'Statistics',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ),

            // ─── Overview cards ───────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Total Income',
                        subtitle: 'All time',
                        amount: budget.totalAllTimeIncome,
                        currency: budget.currency,
                        color: AppColors.income,
                        icon: Icons.trending_up_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Total Expenses',
                        subtitle: 'All time',
                        amount: budget.totalAllTimeExpenses,
                        currency: budget.currency,
                        color: AppColors.expense,
                        icon: Icons.trending_down_rounded,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _StatCard(
                  title: 'Net Balance',
                  subtitle: 'All time savings',
                  amount: budget.totalAllTimeBalance,
                  currency: budget.currency,
                  color: budget.totalAllTimeBalance >= 0
                      ? AppColors.income
                      : AppColors.expense,
                  icon: Icons.account_balance_rounded,
                  isWide: true,
                ),
              ),
            ),

            // ─── 6-month bar chart ───────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Text(
                  'Last 6 Months',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Container(
                  height: 260,
                  padding: const EdgeInsets.all(20),
                  decoration: AppDecorations.glassCard,
                  child: maxY == 0
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.bar_chart_rounded,
                                  color: AppColors.textMuted, size: 48),
                              const SizedBox(height: 12),
                              Text(
                                'No data to display',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AppColors.textMuted,
                                    ),
                              ),
                            ],
                          ),
                        )
                      : BarChart(
                          BarChartData(
                            maxY: maxY * 1.2,
                            barGroups: List.generate(6, (i) {
                              return BarChartGroupData(
                                x: i,
                                barRods: [
                                  BarChartRodData(
                                    toY: incData[i].value,
                                    color: AppColors.income,
                                    width: 12,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(6),
                                    ),
                                  ),
                                  BarChartRodData(
                                    toY: expData[i].value,
                                    color: AppColors.expense,
                                    width: 12,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(6),
                                    ),
                                  ),
                                ],
                                barsSpace: 4,
                              );
                            }),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 50,
                                  getTitlesWidget: (value, meta) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Text(
                                        formatCurrencyShort(value, ''),
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 10,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final idx = value.toInt();
                                    if (idx < 0 || idx >= expData.length) {
                                      return const SizedBox.shrink();
                                    }
                                    return Text(
                                      formatMonthShort(expData[idx].key),
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                              getDrawingHorizontalLine: (value) {
                                return FlLine(
                                  color:
                                      AppColors.border.withValues(alpha: 0.3),
                                  strokeWidth: 1,
                                  dashArray: [5, 5],
                                );
                              },
                            ),
                            borderData: FlBorderData(show: false),
                            barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipColor: (_) => AppColors.surfaceLight,
                                tooltipRoundedRadius: 10,
                                tooltipPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                getTooltipItem:
                                    (group, groupIndex, rod, rodIndex) {
                                  return BarTooltipItem(
                                    formatCurrency(rod.toY, budget.currency),
                                    TextStyle(
                                      color: rod.color,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),

            // Legend
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendDot(color: AppColors.income, label: 'Income'),
                    const SizedBox(width: 24),
                    _LegendDot(color: AppColors.expense, label: 'Expenses'),
                  ],
                ),
              ),
            ),

            // ─── Top spending categories ──────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Text(
                  'Top Spending Categories',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              sliver: budget.expensesByCategory.isEmpty
                  ? SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: AppDecorations.subtleCard,
                        child: Center(
                          child: Text(
                            'No spending data yet',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppColors.textMuted,
                                ),
                          ),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final sorted = budget.expensesByCategory.entries
                              .toList()
                            ..sort((a, b) => b.value.compareTo(a.value));
                          if (index >= sorted.length) return null;
                          final entry = sorted[index];
                          final cat = budget.getCategoryById(entry.key);
                          final total = budget.totalExpensesForMonth;
                          final percentage =
                              total > 0 ? entry.value / total : 0.0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: AppDecorations.subtleCard,
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color:
                                            (cat?.color ?? AppColors.textMuted)
                                                .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        cat?.icon ?? Icons.category_rounded,
                                        color:
                                            cat?.color ?? AppColors.textMuted,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        cat?.name ?? 'Unknown',
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          formatCurrency(
                                              entry.value, budget.currency),
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          '${(percentage * 100).toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            color: cat?.color ??
                                                AppColors.textMuted,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: percentage,
                                    backgroundColor: AppColors.surfaceHighlight,
                                    valueColor: AlwaysStoppedAnimation(
                                      cat?.color ?? AppColors.primary,
                                    ),
                                    minHeight: 6,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        childCount: budget.expensesByCategory.length,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double amount;
  final String currency;
  final Color color;
  final IconData icon;
  final bool isWide;

  const _StatCard({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.currency,
    required this.color,
    required this.icon,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatCurrency(amount, currency),
                  style: TextStyle(
                    color: color,
                    fontSize: isWide ? 22 : 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}
