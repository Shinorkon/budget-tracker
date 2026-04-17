import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'account_provider.dart';
import 'budget_model.dart';
import '../services/currency_util.dart';

const _uuid = Uuid();

class BudgetProvider extends ChangeNotifier {
  List<Category> _categories = [];
  List<Transaction> _transactions = [];
  List<VendorRule> _vendorRules = [];
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String _currency = 'MVR';
  bool _isLoading = true;
  late Box<Category> _catBox;
  late Box<Transaction> _txBox;
  late Box<VendorRule> _ruleBox;

  /// Injected by main.dart after both providers exist. Until set,
  /// `_budgetScoped` is a no-op (everything counted) — which matches the
  /// pre-accounts behavior on first launch before the resolver is wired.
  AccountProvider? _accounts;

  void attachAccountProvider(AccountProvider accounts) {
    _accounts = accounts;
  }

  /// Drops transfer halves and savings-account txns so the resulting list
  /// feeds monthly-budget and statistics math. Per-account and net-worth
  /// views do not use this.
  Iterable<Transaction> _budgetScoped(Iterable<Transaction> source) {
    return source.where((t) {
      if (t.transferGroupId != null) return false;
      final accounts = _accounts;
      if (accounts == null) return true;
      return accounts.includeInBudget(t.accountId);
    });
  }

  // Getters
  List<Category> get categories => List.unmodifiable(_categories);
  List<Transaction> get transactions => List.unmodifiable(_transactions);
  List<VendorRule> get vendorRules => List.unmodifiable(_vendorRules);
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
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(VendorRuleAdapter());
    }

    _catBox = await Hive.openBox<Category>('categories_v2');
    _txBox = await Hive.openBox<Transaction>('transactions_v2');
    _ruleBox = await Hive.openBox<VendorRule>('vendor_rules_v1');

    _categories = _catBox.values.toList();
    _transactions = _txBox.values.toList();
    _vendorRules = _ruleBox.values.toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    // Add default categories if none exist
    if (_categories.isEmpty) {
      await _addDefaultCategories();
    }

    await _backfillOrphanAccountIds();

    _isLoading = false;
    notifyListeners();
  }

  /// One-shot migration: every transaction written before v4 has a null
  /// `accountId`. Point those at the legacy-default account so balance,
  /// net-worth, and budget math all have a stable anchor. Idempotent —
  /// runs every startup but only touches rows that still need it.
  Future<void> _backfillOrphanAccountIds() async {
    for (int i = 0; i < _transactions.length; i++) {
      final t = _transactions[i];
      if (t.accountId != null) continue;
      final fixed = t.copyWith(accountId: kLegacyDefaultAccountId);
      _transactions[i] = fixed;
      await _txBox.putAt(i, fixed);
    }
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

  List<Transaction> get expensesForMonth => _budgetScoped(transactionsForMonth)
      .where((t) => t.type == TransactionType.expense)
      .toList();

  List<Transaction> get incomesForMonth => _budgetScoped(transactionsForMonth)
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

  // ─── Ranged helpers for statistics screen ────────────────
  /// Expense transactions whose [Transaction.date] falls within
  /// [start] (inclusive) and [end] (inclusive). Both bounds are optional so
  /// callers can request "everything before X", "everything after X", or
  /// "all time" without special-casing.
  List<Transaction> expensesInRange({DateTime? start, DateTime? end}) {
    return _budgetScoped(_transactions).where((t) {
      if (t.type != TransactionType.expense) return false;
      if (start != null && t.date.isBefore(start)) return false;
      if (end != null && t.date.isAfter(end)) return false;
      return true;
    }).toList();
  }

  /// Total expenses per store, filtered by optional date range. Stores with
  /// empty names are grouped under "Uncategorized vendor" so they're still
  /// visible in drill-downs.
  Map<String, double> expensesByVendor({DateTime? start, DateTime? end}) {
    final map = <String, double>{};
    for (final t in expensesInRange(start: start, end: end)) {
      final key = t.storeName.trim().isEmpty
          ? 'Uncategorized vendor'
          : t.storeName.trim();
      map[key] = (map[key] ?? 0) + t.amount;
    }
    return map;
  }

  /// Expenses per category within a date range (used by the drill-down
  /// modal for top-spending categories).
  Map<String, double> expensesByCategoryInRange(
      {DateTime? start, DateTime? end}) {
    final map = <String, double>{};
    for (final t in expensesInRange(start: start, end: end)) {
      if (t.categoryId != null) {
        map[t.categoryId!] = (map[t.categoryId!] ?? 0) + t.amount;
      }
    }
    return map;
  }

  /// Vendor breakdown for a single category, scoped to a date range. Used by
  /// the category drill-down to show "where did the Food money go?".
  Map<String, double> vendorBreakdownForCategory(
    String categoryId, {
    DateTime? start,
    DateTime? end,
  }) {
    final map = <String, double>{};
    for (final t in expensesInRange(start: start, end: end)) {
      if (t.categoryId != categoryId) continue;
      final key = t.storeName.trim().isEmpty
          ? 'Uncategorized vendor'
          : t.storeName.trim();
      map[key] = (map[key] ?? 0) + t.amount;
    }
    return map;
  }

  // ─── All-time stats ──────────────────────────────────────
  double get totalAllTimeExpenses => _budgetScoped(_transactions)
      .where((t) => t.type == TransactionType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalAllTimeIncome => _budgetScoped(_transactions)
      .where((t) => t.type == TransactionType.income)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalAllTimeBalance => totalAllTimeIncome - totalAllTimeExpenses;

  // ─── Last 6 months for chart ──────────────────────────────
  List<MapEntry<DateTime, double>> get last6MonthsExpenses {
    final now = DateTime.now();
    final result = <MapEntry<DateTime, double>>[];
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i);
      final total = _budgetScoped(_transactions)
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
      final total = _budgetScoped(_transactions)
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
      final total = _budgetScoped(_transactions)
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
  /// Returns true if the transaction was inserted, false if it was skipped as
  /// a duplicate. Callers that need accurate import counts must check this
  /// return value rather than trusting a pre-filter candidate count.
  Future<bool> addTransaction(Transaction transaction, {bool skipDuplicateCheck = false}) async {
    // Duplicate check and list insert must be synchronous (no await between)
    // to prevent interleaved calls from passing the same check.
    if (!skipDuplicateCheck && isDuplicateTransaction(transaction)) {
      return false;
    }
    _transactions.add(transaction);
    notifyListeners();
    await _txBox.add(transaction);
    return true;
  }

  bool isDuplicateTransaction(Transaction incoming) {
    // ID collisions are always duplicates.
    if (_transactions.any((t) => t.id == incoming.id)) {
      return true;
    }

    // Re-import of the same transfer half: same groupId + same side of the
    // pair (type). The other side is a legitimate pair, not a duplicate.
    if (incoming.transferGroupId != null) {
      final sameHalf = _transactions.any((t) =>
          t.transferGroupId == incoming.transferGroupId &&
          t.type == incoming.type);
      if (sameHalf) return true;
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

    // Search only recent expenses, latest first. Transfer halves are
    // excluded — a receipt should never attach to an account-to-account
    // move.
    final recentExpenses = _transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            t.transferGroupId == null &&
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

  // ─── Transfers ─────────────────────────────────────────────
  /// Write two paired transactions representing a transfer between the
  /// user's own accounts. Returns the shared `transferGroupId`. The pair
  /// is: expense on `fromAccountId` + income on `toAccountId`, both with
  /// the same amount, date, and group id.
  Future<String> createTransfer({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    DateTime? date,
    String note = '',
    String? groupId,
  }) async {
    assert(fromAccountId != toAccountId,
        'Transfer requires two distinct accounts');
    final when = date ?? DateTime.now();
    final gid = groupId ?? _uuid.v4();

    final outgoing = Transaction(
      id: _uuid.v4(),
      amount: amount,
      date: when,
      note: note,
      type: TransactionType.expense,
      accountId: fromAccountId,
      transferGroupId: gid,
    );
    final incoming = Transaction(
      id: _uuid.v4(),
      amount: amount,
      date: when,
      note: note,
      type: TransactionType.income,
      accountId: toAccountId,
      transferGroupId: gid,
    );

    await addTransaction(outgoing, skipDuplicateCheck: true);
    await addTransaction(incoming, skipDuplicateCheck: true);
    return gid;
  }

  /// Returns the matching sibling half of a transfer pair (opposite type,
  /// same `transferGroupId`, within the 15-minute window) so SMS import
  /// can finalise the pair. Returns null if only one half is present.
  Transaction? findTransferSibling(Transaction half) {
    final gid = half.transferGroupId;
    if (gid == null) return null;
    for (final t in _transactions) {
      if (t.id == half.id) continue;
      if (t.transferGroupId != gid) continue;
      if (t.type == half.type) continue;
      if (t.date.difference(half.date).inMinutes.abs() > 15) continue;
      return t;
    }
    return null;
  }

  /// If `half` has a sibling, both rows are already a legitimate transfer
  /// pair — no write needed, the deterministic group id already links
  /// them. Returns true iff the pair is complete after this call.
  bool reconcileTransferPair(Transaction half) {
    return findTransferSibling(half) != null;
  }

  // ─── CRUD: VendorRule ──────────────────────────────────────
  /// Find the best-matching [VendorRule] for a merchant name. Rules are
  /// evaluated in priority order (lowest first); the first match wins.
  /// Returns null if no rule matches.
  VendorRule? findVendorRule(String merchant) {
    for (final r in _vendorRules) {
      if (r.matches(merchant)) return r;
    }
    return null;
  }

  /// Shortcut: apply vendor rules to suggest a categoryId for [merchant].
  /// Returns null if no rule matches, letting callers fall back to built-in
  /// keyword matching or AI-based suggestion.
  String? suggestCategoryByVendorRules(String merchant) =>
      findVendorRule(merchant)?.categoryId;

  Future<void> addVendorRule(VendorRule rule) async {
    _vendorRules.add(rule);
    _vendorRules.sort((a, b) => a.priority.compareTo(b.priority));
    await _ruleBox.add(rule);
    notifyListeners();
  }

  Future<void> updateVendorRule(String id, VendorRule updated) async {
    final index = _vendorRules.indexWhere((r) => r.id == id);
    if (index == -1) return;
    final boxIndex = _ruleBox.values.toList().indexWhere((r) => r.id == id);
    _vendorRules[index] = updated;
    _vendorRules.sort((a, b) => a.priority.compareTo(b.priority));
    if (boxIndex != -1) {
      await _ruleBox.putAt(boxIndex, updated);
    }
    notifyListeners();
  }

  Future<void> deleteVendorRule(String id) async {
    final boxIndex = _ruleBox.values.toList().indexWhere((r) => r.id == id);
    _vendorRules.removeWhere((r) => r.id == id);
    if (boxIndex != -1) {
      await _ruleBox.deleteAt(boxIndex);
    }
    notifyListeners();
  }

  // ─── Clear all data ────────────────────────────────────────
  Future<void> clearAllData() async {
    _categories.clear();
    _transactions.clear();
    _vendorRules.clear();
    await _catBox.clear();
    await _txBox.clear();
    await _ruleBox.clear();
    await _addDefaultCategories();
    notifyListeners();
  }
}
