import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'budget_model.dart';
import '../services/currency_util.dart';

const _uuid = Uuid();

class BudgetProvider extends ChangeNotifier {
  List<Category> _categories = [];
  List<Transaction> _transactions = [];
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String _currency = 'MVR';
  bool _isLoading = true;
  late Box<Category> _catBox;
  late Box<Transaction> _txBox;

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

    _catBox = await Hive.openBox<Category>('categories_v2');
    _txBox = await Hive.openBox<Transaction>('transactions_v2');

    _categories = _catBox.values.toList();
    _transactions = _txBox.values.toList();

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

    for (final cat in defaults) {
      _categories.add(cat);
      await _catBox.add(cat);
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
    await _catBox.add(category);
    notifyListeners();
  }

  Future<void> updateCategory(String id, Category updated) async {
    final index = _categories.indexWhere((c) => c.id == id);
    if (index == -1) return;
    _categories[index] = updated;
    await _catBox.putAt(index, updated);
    notifyListeners();
  }

  Future<void> deleteCategory(String id) async {
    final index = _categories.indexWhere((c) => c.id == id);
    if (index == -1) return;
    _categories.removeAt(index);
    await _catBox.deleteAt(index);
    // Nullify categoryId on orphaned transactions instead of deleting them
    for (int i = 0; i < _transactions.length; i++) {
      if (_transactions[i].categoryId == id) {
        final updated = _transactions[i].copyWith(categoryId: null);
        _transactions[i] = updated;
        await _txBox.putAt(i, updated);
      }
    }
    notifyListeners();
  }

  // ─── CRUD: Transaction ─────────────────────────────────────
  Future<void> addTransaction(Transaction transaction, {bool skipDuplicateCheck = false}) async {
    // Duplicate check and list insert must be synchronous (no await between)
    // to prevent interleaved calls from passing the same check.
    if (!skipDuplicateCheck && isDuplicateTransaction(transaction)) {
      return;
    }
    _transactions.add(transaction);
    notifyListeners();
    await _txBox.add(transaction);
  }

  bool isDuplicateTransaction(Transaction incoming) {
    // ID collisions are always duplicates.
    if (_transactions.any((t) => t.id == incoming.id)) {
      return true;
    }

    final incomingRef = _extractReferenceNo(incoming.note);

    return _transactions.any((existing) {
      final existingRef = _extractReferenceNo(existing.note);
      if (incomingRef != null && existingRef != null && incomingRef == existingRef) {
        return true;
      }

      final sameType = existing.type == incoming.type;
      final sameStore = _normalizeStore(existing.storeName) ==
          _normalizeStore(incoming.storeName);
      final tol = CurrencyUtil.tolerance(incoming.currency);
      final closeAmount = (existing.amount - incoming.amount).abs() <= tol;
      final closeTime =
          (existing.date.difference(incoming.date).inMinutes).abs() <= 2;

      return sameType && sameStore && closeAmount && closeTime;
    });
  }

  Transaction? findBestMatchingExpenseTransaction({
    required double amount,
    required DateTime date,
    required String storeName,
  }) {
    final normalizedStore = _normalizeStore(storeName);

    // Search only recent expenses, latest first.
    final recentExpenses = _transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            date.difference(t.date).inHours.abs() <= 24)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    Transaction? best;
    double bestScore = -1;

    for (final tx in recentExpenses) {
      // Skip already linked receipt transactions.
      if (tx.note.toLowerCase().contains('[receipt-linked]')) continue;

      final amountDiff = (tx.amount - amount).abs();
      final amountScore = amountDiff <= 0.01
          ? 1.0
          : (amountDiff <= 1.0 ? (1.0 - (amountDiff / 1.0)) : 0.0);

      final timeDiffMinutes = date.difference(tx.date).inMinutes.abs();
      final timeScore =
          timeDiffMinutes <= 60 ? (1.0 - (timeDiffMinutes / 60.0)) : 0.0;

      final txStore = _normalizeStore(tx.storeName);
      final storeScore = (txStore.isNotEmpty && txStore == normalizedStore)
          ? 1.0
          : 0.0;

      final score = (amountScore * 0.65) + (storeScore * 0.25) + (timeScore * 0.10);

      if (score > bestScore) {
        bestScore = score;
        best = tx;
      }
    }

    // Require reasonably high confidence to auto-link.
    if (bestScore >= 0.75) return best;
    return null;
  }

  String _normalizeStore(String store) =>
      store.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

  String? _extractReferenceNo(String note) {
    final match = RegExp(r'Ref\s+([A-Za-z0-9-]+)', caseSensitive: false)
        .firstMatch(note);
    return match?.group(1)?.toUpperCase();
  }

  Future<void> updateTransaction(String id, Transaction updated) async {
    final index = _transactions.indexWhere((t) => t.id == id);
    if (index == -1) return;
    _transactions[index] = updated;
    await _txBox.putAt(index, updated);
    notifyListeners();
  }

  Future<void> deleteTransaction(String id) async {
    final index = _transactions.indexWhere((t) => t.id == id);
    if (index == -1) return;
    _transactions.removeAt(index);
    await _txBox.deleteAt(index);
    notifyListeners();
  }

  // ─── Clear all data ────────────────────────────────────────
  Future<void> clearAllData() async {
    _categories.clear();
    _transactions.clear();
    await _catBox.clear();
    await _txBox.clear();
    await _addDefaultCategories();
    notifyListeners();
  }
}
