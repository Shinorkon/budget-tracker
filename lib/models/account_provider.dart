import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'account_model.dart';
import 'budget_model.dart';
import 'savings_goal_model.dart';

const String kLegacyDefaultAccountId = 'legacy-default';

class AccountProvider extends ChangeNotifier {
  final List<Account> _accounts = [];
  final List<SavingsGoal> _goals = [];
  late Box<Account> _accountBox;
  late Box<SavingsGoal> _goalBox;
  bool _isLoading = true;

  List<Account> get accounts => List.unmodifiable(
        _accounts.where((a) => a.deletedAt == null && !a.archived),
      );
  List<Account> get allAccountsIncludingArchived =>
      List.unmodifiable(_accounts.where((a) => a.deletedAt == null));
  List<SavingsGoal> get savingsGoals => List.unmodifiable(
        _goals.where((g) => g.deletedAt == null),
      );
  bool get isLoading => _isLoading;

  AccountProvider() {
    _init();
  }

  Future<void> _init() async {
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(AccountAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(SavingsGoalAdapter());
    }

    _accountBox = await Hive.openBox<Account>('accounts_v1');
    _goalBox = await Hive.openBox<SavingsGoal>('savings_goals_v1');

    _accounts
      ..clear()
      ..addAll(_accountBox.values);
    _goals
      ..clear()
      ..addAll(_goalBox.values);

    await _ensureLegacyDefault();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _ensureLegacyDefault() async {
    if (_accounts.any((a) => a.id == kLegacyDefaultAccountId)) return;
    final seed = Account(
      id: kLegacyDefaultAccountId,
      name: 'Default',
      bank: BankType.other,
      type: AccountType.current,
      openingBalance: 0,
      includeInBudget: true,
    );
    _accounts.add(seed);
    await _accountBox.put(seed.id, seed);
  }

  // ─── Lookups ──────────────────────────────────────────────
  Account? accountById(String? id) {
    if (id == null) return null;
    for (final a in _accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  Account get defaultAccount =>
      accountById(kLegacyDefaultAccountId) ?? _accounts.first;

  List<Account> accountsForBank(BankType bank) =>
      accounts.where((a) => a.bank == bank).toList();

  /// Used by BudgetProvider's `_budgetScoped` filter. Unknown accountId
  /// (e.g. null on legacy rows) is treated as in-budget so upgrade from an
  /// older client doesn't silently hide data.
  bool includeInBudget(String? accountId) {
    if (accountId == null) return true;
    final a = accountById(accountId);
    if (a == null) return true;
    return a.includeInBudget && !a.archived;
  }

  // ─── CRUD: Accounts ───────────────────────────────────────
  Future<void> addAccount(Account account) async {
    _accounts.add(account);
    await _accountBox.put(account.id, account);
    notifyListeners();
  }

  Future<void> updateAccount(String id, Account updated) async {
    final index = _accounts.indexWhere((a) => a.id == id);
    if (index < 0) return;
    final bumped = updated.copyWith(version: updated.version + 1);
    _accounts[index] = bumped;
    await _accountBox.put(id, bumped);
    notifyListeners();
  }

  Future<void> archiveAccount(String id) async {
    final a = accountById(id);
    if (a == null) return;
    await updateAccount(id, a.copyWith(archived: true));
  }

  Future<void> softDeleteAccount(String id) async {
    final a = accountById(id);
    if (a == null) return;
    await updateAccount(id, a.copyWith(deletedAt: DateTime.now()));
  }

  // ─── CRUD: Savings Goals ──────────────────────────────────
  Future<void> addGoal(SavingsGoal goal) async {
    _goals.add(goal);
    await _goalBox.put(goal.id, goal);
    notifyListeners();
  }

  Future<void> updateGoal(String id, SavingsGoal updated) async {
    final index = _goals.indexWhere((g) => g.id == id);
    if (index < 0) return;
    final bumped = updated.copyWith(version: updated.version + 1);
    _goals[index] = bumped;
    await _goalBox.put(id, bumped);
    notifyListeners();
  }

  Future<void> deleteGoal(String id) async {
    final g = _goals.firstWhere(
      (g) => g.id == id,
      orElse: () => SavingsGoal(
        id: '',
        accountId: '',
        name: '',
        targetAmount: 0,
        monthlyTarget: 0,
        startMonth: DateTime.now(),
      ),
    );
    if (g.id.isEmpty) return;
    await updateGoal(id, g.copyWith(deletedAt: DateTime.now()));
  }

  // ─── Balance math ─────────────────────────────────────────
  /// Per-account balance. Includes every transaction assigned to the
  /// account — expenses and transfer-out halves subtract, incomes and
  /// transfer-in halves add, opening balance is the starting offset.
  double balanceFor(String accountId, List<Transaction> txns,
      {DateTime? upTo}) {
    final account = accountById(accountId);
    if (account == null) return 0;
    final scoped = txns.where((t) =>
        t.accountId == accountId &&
        (upTo == null || !t.date.isAfter(upTo)));
    double delta = 0;
    for (final t in scoped) {
      delta += t.type == TransactionType.income ? t.amount : -t.amount;
    }
    return account.openingBalance + delta;
  }

  double netWorth(List<Transaction> txns, {DateTime? upTo}) {
    double total = 0;
    for (final a in accounts) {
      total += balanceFor(a.id, txns, upTo: upTo);
    }
    return total;
  }

  double budgetNetWorth(List<Transaction> txns, {DateTime? upTo}) {
    double total = 0;
    for (final a in accounts.where((a) => a.includeInBudget)) {
      total += balanceFor(a.id, txns, upTo: upTo);
    }
    return total;
  }

  double savingsNetWorth(List<Transaction> txns, {DateTime? upTo}) {
    double total = 0;
    for (final a in accounts.where((a) => a.isSavings)) {
      total += balanceFor(a.id, txns, upTo: upTo);
    }
    return total;
  }

  // ─── Savings goal math ────────────────────────────────────
  /// Net contribution into the goal's account for `month` — transfers in
  /// minus transfers out. Non-transfer rows on the account are treated as
  /// contributions/withdrawals too (a user deposit that lands as an
  /// income SMS still counts toward saving).
  double savedInMonth(
      SavingsGoal goal, DateTime month, List<Transaction> txns) {
    final monthStart = DateTime(month.year, month.month);
    final nextMonth = DateTime(month.year, month.month + 1);
    double delta = 0;
    for (final t in txns) {
      if (t.accountId != goal.accountId) continue;
      if (t.date.isBefore(monthStart) || !t.date.isBefore(nextMonth)) continue;
      delta += t.type == TransactionType.income ? t.amount : -t.amount;
    }
    return delta;
  }

  double savedThisMonth(SavingsGoal goal, List<Transaction> txns) =>
      savedInMonth(goal, DateTime.now(), txns);

  /// Total underpayment across every complete month between the goal's
  /// `startMonth` and the month before `now`. Overpayment in one month
  /// reduces (but does not go below zero for) the running total.
  double rolloverDue(
      SavingsGoal goal, DateTime now, List<Transaction> txns) {
    final startMonth = DateTime(goal.startMonth.year, goal.startMonth.month);
    final currentMonth = DateTime(now.year, now.month);
    if (!startMonth.isBefore(currentMonth)) return 0;

    double running = 0;
    DateTime cursor = startMonth;
    while (cursor.isBefore(currentMonth)) {
      final saved = savedInMonth(goal, cursor, txns);
      running += goal.monthlyTarget - saved;
      if (running < 0) running = 0;
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
    return running;
  }

  double expectedThisMonth(
      SavingsGoal goal, DateTime now, List<Transaction> txns) {
    return goal.monthlyTarget + rolloverDue(goal, now, txns);
  }

  // ─── Migration ────────────────────────────────────────────
  /// Orphan-transaction backfill target. Callers use this id when
  /// writing `accountId` to rows that were created before the
  /// accounts feature existed.
  String get legacyDefaultId => kLegacyDefaultAccountId;

  // Debug helper so tests can force a fresh seed.
  @visibleForTesting
  Future<void> resetForTests() async {
    _accounts.clear();
    _goals.clear();
    await _accountBox.clear();
    await _goalBox.clear();
    await _ensureLegacyDefault();
    notifyListeners();
  }
}
