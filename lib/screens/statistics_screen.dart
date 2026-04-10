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

            // ─── Daily spending trend ─────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Text(
                  'Daily Spending — ${budget.selectedMonthLabel}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 220,
                  padding: const EdgeInsets.all(20),
                  decoration: AppDecorations.glassCard,
                  child: _DailyTrendChart(budget: budget),
                ),
              ),
            ),

            // ─── Budget vs Actual ────────────────────────────────
            if (budget.categories
                .any((c) => c.budgetLimit > 0)) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Text(
                    'Budget vs Actual',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: AppDecorations.glassCard,
                    child: _BudgetVsActual(budget: budget),
                  ),
                ),
              ),
            ],

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
        color: Theme.of(context).colorScheme.surface,
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

// ─── Daily spending trend line chart ─────────────────────────

class _DailyTrendChart extends StatelessWidget {
  final BudgetProvider budget;

  const _DailyTrendChart({required this.budget});

  @override
  Widget build(BuildContext context) {
    final dailyData = budget.dailyExpensesForMonth;
    final maxY = dailyData.fold(0.0, (m, e) => e.value > m ? e.value : m);

    if (maxY == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart_rounded,
                color: AppColors.textMuted, size: 48),
            const SizedBox(height: 12),
            Text(
              'No expenses this month',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    final spots = dailyData
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return LineChart(
      LineChartData(
        maxY: maxY * 1.2,
        minY: 0,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppColors.expense,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.expense.withValues(alpha: 0.08),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
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
              interval: (dailyData.length / 6).ceilToDouble().clamp(1, 31),
              getTitlesWidget: (value, meta) {
                final day = value.toInt();
                if (day < 1 || day > dailyData.length) {
                  return const SizedBox.shrink();
                }
                return Text(
                  '$day',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 0 ? maxY / 3 : 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.border.withValues(alpha: 0.3),
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.surfaceLight,
            tooltipRoundedRadius: 10,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  'Day ${spot.x.toInt()}\n${formatCurrency(spot.y, budget.currency)}',
                  const TextStyle(
                    color: AppColors.expense,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}

// ─── Budget vs Actual per category ───────────────────────────

class _BudgetVsActual extends StatelessWidget {
  final BudgetProvider budget;

  const _BudgetVsActual({required this.budget});

  @override
  Widget build(BuildContext context) {
    final cats = budget.categories
        .where((c) => c.budgetLimit > 0)
        .toList();

    return Column(
      children: cats.map((cat) {
        final spent = budget.expensesForCategory(cat.id);
        final limit = cat.budgetLimit;
        final ratio = limit > 0 ? (spent / limit).clamp(0.0, 1.5) : 0.0;
        final isOver = spent > limit;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(cat.icon, color: cat.color, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      cat.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    '${formatCurrencyShort(spent, budget.currency)} / ${formatCurrencyShort(limit, budget.currency)}',
                    style: TextStyle(
                      color: isOver ? AppColors.expense : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Stack(
                children: [
                  // Budget bar (full width = budget)
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHighlight,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  // Actual bar
                  FractionallySizedBox(
                    widthFactor: ratio.clamp(0.0, 1.0),
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: isOver ? AppColors.expense : cat.color,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ],
              ),
              if (isOver)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Over by ${formatCurrency(spent - limit, budget.currency)}',
                    style: const TextStyle(
                      color: AppColors.expense,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
