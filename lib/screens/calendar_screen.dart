import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../theme/app_theme.dart';
import '../models/budget_provider.dart';
import '../models/budget_model.dart';
import '../utils/formatters.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final budget = Provider.of<BudgetProvider>(context);
    final txnsByDay = budget.transactionsByDay;

    final selectedTxns = _selectedDay != null
        ? budget.transactionsForDate(_selectedDay!)
        : <Transaction>[];

    final dayExpenses = selectedTxns
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
    final dayIncome = selectedTxns
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
      ),
      body: Column(
        children: [
          // Calendar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
            ),
            child: TableCalendar<Transaction>(
              firstDay: DateTime(2020),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: _calendarFormat,
              onFormatChanged: (format) =>
                  setState(() => _calendarFormat = format),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onPageChanged: (focusedDay) => _focusedDay = focusedDay,
              eventLoader: (day) {
                final key = DateTime(day.year, day.month, day.day);
                return txnsByDay[key] ?? [];
              },
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                todayDecoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                defaultTextStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface),
                weekendTextStyle: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color),
                todayTextStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600),
                selectedTextStyle: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
                markerDecoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                markerSize: 6,
                markersMaxCount: 3,
                markerMargin: const EdgeInsets.symmetric(horizontal: 1),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                leftChevronIcon: Icon(Icons.chevron_left_rounded,
                    color: Theme.of(context).colorScheme.onSurface),
                rightChevronIcon: Icon(Icons.chevron_right_rounded,
                    color: Theme.of(context).colorScheme.onSurface),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
                weekendStyle: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Day summary
          if (_selectedDay != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _DaySummaryChip(
                      label: 'Income',
                      amount: dayIncome,
                      currency: budget.currency,
                      color: AppColors.income,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DaySummaryChip(
                      label: 'Expenses',
                      amount: dayExpenses,
                      currency: budget.currency,
                      color: AppColors.expense,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),

          // Transaction list for selected day
          Expanded(
            child: selectedTxns.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_note_rounded,
                            color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.4),
                            size: 48),
                        const SizedBox(height: 8),
                        Text(
                          'No transactions this day',
                          style: TextStyle(
                              color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: selectedTxns.length,
                    itemBuilder: (context, index) {
                      final t = selectedTxns[index];
                      final cat = budget.getCategoryById(t.categoryId);
                      final isIncome = t.type == TransactionType.income;
                      final color =
                          isIncome ? AppColors.income : AppColors.expense;
                      final sign = isIncome ? '+' : '-';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: AppDecorations.subtleCard,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (cat?.color ?? color)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isIncome
                                    ? Icons.arrow_downward_rounded
                                    : (cat?.icon ?? Icons.remove_rounded),
                                color: cat?.color ?? color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isIncome
                                        ? 'Income'
                                        : (cat?.name ?? 'Expense'),
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (t.note.isNotEmpty ||
                                      t.storeNameOrNull != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        t.note.isNotEmpty
                                            ? t.note
                                            : t.storeName,
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$sign${formatCurrency(t.amount, budget.currency)}',
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  TimeOfDay.fromDateTime(t.date)
                                      .format(context),
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DaySummaryChip extends StatelessWidget {
  final String label;
  final double amount;
  final String currency;
  final Color color;

  const _DaySummaryChip({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            label == 'Income'
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: color, fontSize: 11, fontWeight: FontWeight.w500)),
                Text(
                  formatCurrencyShort(amount, currency),
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
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
