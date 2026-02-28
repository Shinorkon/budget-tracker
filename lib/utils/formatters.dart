import 'package:intl/intl.dart';

String formatCurrency(double amount, String currency) {
  final formatter = NumberFormat('#,##0.00');
  return '${formatter.format(amount)} $currency';
}

String formatCurrencyShort(double amount, String currency) {
  if (amount.abs() >= 1000000) {
    return '${(amount / 1000000).toStringAsFixed(1)}M $currency';
  } else if (amount.abs() >= 1000) {
    return '${(amount / 1000).toStringAsFixed(1)}K $currency';
  }
  return '${amount.toStringAsFixed(0)} $currency';
}

String formatDate(DateTime date) {
  return DateFormat('MMM d, yyyy').format(date);
}

String formatDateShort(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dateOnly = DateTime(date.year, date.month, date.day);

  if (dateOnly == today) return 'Today';
  if (dateOnly == today.subtract(const Duration(days: 1))) return 'Yesterday';
  if (now.difference(date).inDays < 7) return DateFormat('EEEE').format(date);
  return DateFormat('MMM d').format(date);
}

String formatMonthShort(DateTime date) {
  return DateFormat('MMM').format(date);
}

String formatMonthYear(DateTime date) {
  return DateFormat('MMMM yyyy').format(date);
}

double percentChange(double current, double previous) {
  if (previous == 0) return current > 0 ? 100 : 0;
  return ((current - previous) / previous) * 100;
}
