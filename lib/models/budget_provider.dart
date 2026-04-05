import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'budget_model.dart';

const _uuid = Uuid();

class BudgetProvider extends ChangeNotifier {
  List<Category> _categories = [];
  List<Transaction> _transactions = [];
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String _currency = 'MVR';
  bool _isLoading = true;

  // Getters
  List<Category> get categories => List.unmodifiable(_categories);
  List<Transaction> get transactions => List.unmodifiable(_transactions);
  DateTime get selectedMonth => _selectedMonth;
  String get currency => _currency;
  bool get isLoading => _isLoading;

  String get selectedMonthLabel {
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}';
  }

  BudgetProvider() {
    _init();
  }

  Future<void> _init() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(CategoryAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TransactionAdapter());
    }

    final catBox = await Hive.openBox<Category>('categories_v2');
    final txBox = await Hive.openBox<Transaction>('transactions_v2');

    _categories = catBox.values.toList();
    _transactions = txBox.values.toList();

    // Add default categories if none exist
    if (_categories.isEmpty) {
      await _addDefaultCategories();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _addDefaultCategories() async {
    final defaults = [
      Category(
          id: _uuid.v4(),
          name: 'Rent',
          icon: Icons.home_rounded,
          color: const Color(0xFF6C5CE7),
          budgetLimit: 0),
      Category(
          id: _uuid.v4(),
          name: 'Food',
          icon: Icons.restaurant_rounded,
          color: const Color(0xFFFF7675),
          budgetLimit: 0),
      Category(
          id: _uuid.v4(),
          name: 'Transport',
          icon: Icons.directions_car_rounded,
          color: const Color(0xFF74B9FF),
          budgetLimit: 0),
      Category(
          id: _uuid.v4(),
          name: 'Shopping',
          icon: Icons.shopping_bag_rounded,
          color: const Color(0xFFFDCB6E),
          budgetLimit: 0),
      Category(
          id: _uuid.v4(),
          name: 'Bills',
          icon: Icons.receipt_long_rounded,
          color: const Color(0xFF00CEC9),
          budgetLimit: 0),
      Category(
          id: _uuid.v4(),
          name: 'Entertainment',
          icon: Icons.movie_rounded,
          color: const Color(0xFFE17055),
          budgetLimit: 0),
    ];

    final box = await Hive.openBox<Category>('categories_v2');
    for (final cat in defaults) {
      _categories.add(cat);
      await box.add(cat);
    }
  }

  // ─── Month navigation ─────────────────────────────────────
  void nextMonth() {
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    notifyListeners();
  }

  void prevMonth() {
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    notifyListeners();
  }

  void goToCurrentMonth() {
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    notifyListeners();
  }

  // ─── Filtered data ────────────────────────────────────────
  List<Transaction> get transactionsForMonth {
    return _transactions
        .where((t) =>
            t.date.year == _selectedMonth.year &&
            t.date.month == _selectedMonth.month)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<Transaction> get expensesForMonth => transactionsForMonth
      .where((t) => t.type == TransactionType.expense)
      .toList();

  List<Transaction> get incomesForMonth => transactionsForMonth
      .where((t) => t.type == TransactionType.income)
      .toList();

  double get totalExpensesForMonth =>
      expensesForMonth.fold(0.0, (sum, t) => sum + t.amount);

  double get totalIncomeForMonth =>
      incomesForMonth.fold(0.0, (sum, t) => sum + t.amount);

  double get balance => totalIncomeForMonth - totalExpensesForMonth;

  double expensesForCategory(String categoryId) {
    return expensesForMonth
        .where((t) => t.categoryId == categoryId)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  Map<String, double> get expensesByCategory {
    final map = <String, double>{};
    for (final t in expensesForMonth) {
      if (t.categoryId != null) {
        map[t.categoryId!] = (map[t.categoryId!] ?? 0) + t.amount;
      }
    }
    return map;
  }

  Category? getCategoryById(String? id) {
    if (id == null) return null;
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // ─── All-time stats ──────────────────────────────────────
  double get totalAllTimeExpenses => _transactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalAllTimeIncome => _transactions
      .where((t) => t.type == TransactionType.income)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalAllTimeBalance => totalAllTimeIncome - totalAllTimeExpenses;

  // ─── Last 6 months for chart ──────────────────────────────
  List<MapEntry<DateTime, double>> get last6MonthsExpenses {
    final now = DateTime.now();
    final result = <MapEntry<DateTime, double>>[];
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i);
      final total = _transactions
          .where((t) =>
              t.type == TransactionType.expense &&
              t.date.year == month.year &&
              t.date.month == month.month)
          .fold(0.0, (sum, t) => sum + t.amount);
      result.add(MapEntry(month, total));
    }
    return result;
  }

  List<MapEntry<DateTime, double>> get last6MonthsIncome {
    final now = DateTime.now();
    final result = <MapEntry<DateTime, double>>[];
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i);
      final total = _transactions
          .where((t) =>
              t.type == TransactionType.income &&
              t.date.year == month.year &&
              t.date.month == month.month)
          .fold(0.0, (sum, t) => sum + t.amount);
      result.add(MapEntry(month, total));
    }
    return result;
  }

  // ─── Date-based queries (for calendar) ─────────────────────
  List<Transaction> transactionsForDate(DateTime date) {
    return _transactions
        .where((t) =>
            t.date.year == date.year &&
            t.date.month == date.month &&
            t.date.day == date.day)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Map<DateTime, List<Transaction>> get transactionsByDay {
    final map = <DateTime, List<Transaction>>{};
    for (final t in _transactions) {
      final key = DateTime(t.date.year, t.date.month, t.date.day);
      map.putIfAbsent(key, () => []).add(t);
    }
    return map;
  }

  // ─── Daily expenses for current month (for charts) ────────
  List<MapEntry<int, double>> get dailyExpensesForMonth {
    final daysInMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final result = <MapEntry<int, double>>[];
    for (int d = 1; d <= daysInMonth; d++) {
      final total = _transactions
          .where((t) =>
              t.type == TransactionType.expense &&
              t.date.year == _selectedMonth.year &&
              t.date.month == _selectedMonth.month &&
              t.date.day == d)
          .fold(0.0, (sum, t) => sum + t.amount);
      result.add(MapEntry(d, total));
    }
    return result;
  }

  // ─── Currency ──────────────────────────────────────────────
  void setCurrency(String newCurrency) {
    _currency = newCurrency;
    notifyListeners();
  }

  // ─── CRUD: Category ────────────────────────────────────────
  Future<void> addCategory(Category category) async {
    _categories.add(category);
    final box = await Hive.openBox<Category>('categories_v2');
    await box.add(category);
    notifyListeners();
  }

  Future<void> updateCategory(String id, Category updated) async {
    final index = _categories.indexWhere((c) => c.id == id);
    if (index == -1) return;
    _categories[index] = updated;
    final box = await Hive.openBox<Category>('categories_v2');
    await box.putAt(index, updated);
    notifyListeners();
  }

  Future<void> deleteCategory(String id) async {
    final index = _categories.indexWhere((c) => c.id == id);
    if (index == -1) return;
    _categories.removeAt(index);
    final box = await Hive.openBox<Category>('categories_v2');
    await box.deleteAt(index);
    // Also remove transactions for this category
    _transactions.removeWhere((t) => t.categoryId == id);
    final txBox = await Hive.openBox<Transaction>('transactions_v2');
    await txBox.clear();
    for (final t in _transactions) {
      await txBox.add(t);
    }
    notifyListeners();
  }

  // ─── CRUD: Transaction ─────────────────────────────────────
  Future<void> addTransaction(Transaction transaction) async {
    _transactions.add(transaction);
    final box = await Hive.openBox<Transaction>('transactions_v2');
    await box.add(transaction);
    notifyListeners();
  }

  Future<void> updateTransaction(String id, Transaction updated) async {
    final index = _transactions.indexWhere((t) => t.id == id);
    if (index == -1) return;
    _transactions[index] = updated;
    final box = await Hive.openBox<Transaction>('transactions_v2');
    await box.putAt(index, updated);
    notifyListeners();
  }

  Future<void> deleteTransaction(String id) async {
    final index = _transactions.indexWhere((t) => t.id == id);
    if (index == -1) return;
    _transactions.removeAt(index);
    final box = await Hive.openBox<Transaction>('transactions_v2');
    await box.deleteAt(index);
    notifyListeners();
  }

  // ─── Clear all data ────────────────────────────────────────
  Future<void> clearAllData() async {
    _categories.clear();
    _transactions.clear();
    final catBox = await Hive.openBox<Category>('categories_v2');
    final txBox = await Hive.openBox<Transaction>('transactions_v2');
    await catBox.clear();
    await txBox.clear();
    await _addDefaultCategories();
    notifyListeners();
  }
}
