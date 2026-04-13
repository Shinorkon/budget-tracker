import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/budget_model.dart';
import '../models/budget_provider.dart';
import '../models/receipt_model.dart';
import '../models/receipt_provider.dart';
import 'api_service.dart';

enum SyncState { idle, uploading, downloading, merging, done, error }

class SyncProgress {
  final SyncState state;
  final String? message;
  SyncProgress(this.state, [this.message]);
}

class SyncService {
  final ApiService _api;
  final BudgetProvider _budgetProvider;
  final ReceiptProvider _receiptProvider;
  bool _isSyncing = false;

  /// Listen to this for real-time sync progress updates.
  final ValueNotifier<SyncProgress> progress =
      ValueNotifier(SyncProgress(SyncState.idle));

  SyncService({
    required ApiService api,
    required BudgetProvider budgetProvider,
    required ReceiptProvider receiptProvider,
  })  : _api = api,
        _budgetProvider = budgetProvider,
        _receiptProvider = receiptProvider;

  Future<bool> get _isOnline async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  /// Attempt a full sync. Returns (success, errorMessage).
  Future<(bool, String?)> sync() async {
    if (_isSyncing) return (false, 'Sync already in progress');
    if (!(await _api.isLoggedIn)) return (false, 'Not logged in');
    if (!(await _isOnline)) return (false, 'No internet connection');

    _isSyncing = true;
    try {
      progress.value = SyncProgress(SyncState.uploading, 'Pushing local changes...');

      final lastSynced = await _api.lastSyncedAt;

      // Build payload from local data
      final categories = _budgetProvider.categories.map((c) => {
            'id': c.id,
            'name': c.name,
            'icon_code': c.iconCode,
            'color_value': c.colorValue,
            'budget_limit': c.budgetLimit,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).toList();

      final transactions = _budgetProvider.transactions.map((t) => {
            'id': t.id,
            'category_id': t.categoryId,
            'amount': t.amount,
            'date': t.date.toUtc().toIso8601String(),
            'note': t.note,
            'type': t.type == TransactionType.expense ? 'expense' : 'income',
            'store_name': t.storeName,
            'image_path': t.imagePath,
            'currency': t.currency,
            'exchange_rate': t.exchangeRate,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).toList();

      final receipts = _receiptProvider.receipts.map((r) => {
            'id': r.id,
            'store_name': r.storeName,
            'date': r.date.toUtc().toIso8601String(),
            'total': r.total,
            'category_id': r.categoryId,
            'transaction_id': r.transactionId,
            'image_path': r.imagePath,
            'items_json': r.itemsJson,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).toList();

      final vendorRules = _budgetProvider.vendorRules.map((v) => {
            'id': v.id,
            'pattern': v.pattern,
            'use_regex': v.useRegex,
            'category_id': v.categoryId,
            'is_income': v.isIncome,
            'priority': v.priority,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).toList();

      // Paginated sync: loop until no more pages
      int page = 1;
      bool hasMore = true;
      String? serverTime;

      while (hasMore) {
        progress.value = SyncProgress(
          page == 1 ? SyncState.uploading : SyncState.downloading,
          page == 1 ? 'Pushing local changes...' : 'Downloading page $page...',
        );

        final response = await _api.authenticatedRequest(
          'POST',
          '/api/sync',
          body: {
            'last_synced_at': lastSynced?.toUtc().toIso8601String(),
            'categories': page == 1 ? categories : [],
            'transactions': page == 1 ? transactions : [],
            'receipts': page == 1 ? receipts : [],
            'vendor_rules': page == 1 ? vendorRules : [],
            'page': page,
            'per_page': 500,
          },
        );

        if (response.statusCode != 200) {
          String msg = 'Server returned ${response.statusCode}';
          try {
            final body = jsonDecode(response.body);
            if (body is Map && body['detail'] != null) {
              msg = body['detail'].toString();
            }
          } catch (_) {}
          progress.value = SyncProgress(SyncState.error, msg);
          return (false, msg);
        }

        final data = jsonDecode(response.body);
        serverTime = data['server_time'] as String;
        hasMore = data['has_more'] as bool? ?? false;

        progress.value = SyncProgress(SyncState.merging, 'Merging changes...');

        // ── Apply server changes to local state ───────────────
        await _applyServerChanges(data);
        page++;
      }

      if (serverTime != null) {
        await _api.setLastSyncedAt(DateTime.parse(serverTime));
      }

      progress.value = SyncProgress(SyncState.done, 'Sync complete');
      return (true, null);
    } on Exception catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      progress.value = SyncProgress(SyncState.error, msg);
      return (false, msg);
    } finally {
      _isSyncing = false;
      // Reset to idle after a brief delay so UI can show "done"
      Future.delayed(const Duration(seconds: 2), () {
        if (progress.value.state == SyncState.done) {
          progress.value = SyncProgress(SyncState.idle);
        }
      });
    }
  }

  Future<void> _applyServerChanges(Map<String, dynamic> data) async {
    final serverCats = data['categories'] as List? ?? [];
    for (final sc in serverCats) {
      final id = sc['id'] as String;
      final deletedAt = sc['deleted_at'];

      // Handle soft-deleted items from server
      if (deletedAt != null) {
        final existing = _budgetProvider.getCategoryById(id);
        if (existing != null) {
          await _budgetProvider.deleteCategory(id);
        }
        continue;
      }

      final existing = _budgetProvider.getCategoryById(id);
      final cat = Category(
        id: id,
        name: sc['name'] as String,
        icon: IconData(sc['icon_code'] as int, fontFamily: 'MaterialIcons'),
        color: Color(sc['color_value'] as int),
        budgetLimit: (sc['budget_limit'] as num).toDouble(),
      );
      if (existing != null) {
        await _budgetProvider.updateCategory(id, cat);
      } else {
        await _budgetProvider.addCategory(cat);
      }
    }

    final serverTxns = data['transactions'] as List? ?? [];
    for (final st in serverTxns) {
      final id = st['id'] as String;
      final deletedAt = st['deleted_at'];

      if (deletedAt != null) {
        final existingIdx = _budgetProvider.transactions
            .indexWhere((t) => t.id == id);
        if (existingIdx != -1) {
          await _budgetProvider.deleteTransaction(id);
        }
        continue;
      }

      final existingIdx = _budgetProvider.transactions
          .indexWhere((t) => t.id == id);
      final tx = Transaction(
        id: id,
        categoryId: st['category_id'] as String?,
        amount: (st['amount'] as num).toDouble(),
        date: DateTime.parse(st['date'] as String),
        note: st['note'] as String? ?? '',
        type: st['type'] == 'income'
            ? TransactionType.income
            : TransactionType.expense,
        storeName: st['store_name'] as String? ?? '',
        imagePath: st['image_path'] as String? ?? '',
        currency: st['currency'] as String? ?? 'MVR',
        exchangeRate: st['exchange_rate'] != null
            ? (st['exchange_rate'] as num).toDouble()
            : null,
      );
      if (existingIdx != -1) {
        await _budgetProvider.updateTransaction(id, tx);
      } else {
        // Skip fuzzy duplicate check for server data — ID is authoritative
        await _budgetProvider.addTransaction(tx, skipDuplicateCheck: true);
      }
    }

    final serverRules = data['vendor_rules'] as List? ?? [];
    for (final sv in serverRules) {
      final id = sv['id'] as String;
      final deletedAt = sv['deleted_at'];

      if (deletedAt != null) {
        final exists = _budgetProvider.vendorRules.any((v) => v.id == id);
        if (exists) {
          await _budgetProvider.deleteVendorRule(id);
        }
        continue;
      }

      final rule = VendorRule(
        id: id,
        pattern: sv['pattern'] as String? ?? '',
        useRegex: sv['use_regex'] as bool? ?? false,
        categoryId: sv['category_id'] as String? ?? '',
        isIncome: sv['is_income'] as bool? ?? false,
        priority: (sv['priority'] as num?)?.toInt() ?? 100,
      );
      final existing = _budgetProvider.vendorRules.any((v) => v.id == id);
      if (existing) {
        await _budgetProvider.updateVendorRule(id, rule);
      } else {
        await _budgetProvider.addVendorRule(rule);
      }
    }

    final serverRcpts = data['receipts'] as List? ?? [];
    for (final sr in serverRcpts) {
      final id = sr['id'] as String;
      final deletedAt = sr['deleted_at'];

      if (deletedAt != null) {
        final existingRcpt =
            _receiptProvider.receipts.where((r) => r.id == id);
        if (existingRcpt.isNotEmpty) {
          await _receiptProvider.deleteReceipt(id);
        }
        continue;
      }

      final existingRcpt =
          _receiptProvider.receipts.where((r) => r.id == id);
      final receipt = Receipt(
        id: id,
        storeName: sr['store_name'] as String,
        date: DateTime.parse(sr['date'] as String),
        total: (sr['total'] as num).toDouble(),
        categoryId: sr['category_id'] as String? ?? '',
        transactionId: sr['transaction_id'] as String? ?? '',
        imagePath: sr['image_path'] as String? ?? '',
        itemsJson: sr['items_json'] as String? ?? '[]',
      );
      if (existingRcpt.isEmpty) {
        await _receiptProvider.addReceipt(receipt);
      }
    }
  }
}
