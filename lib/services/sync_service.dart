import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/budget_model.dart';
import '../models/budget_provider.dart';
import '../models/receipt_provider.dart';
import 'api_service.dart';

class SyncService {
  final ApiService _api;
  final BudgetProvider _budgetProvider;
  final ReceiptProvider _receiptProvider;
  bool _isSyncing = false;

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

      final response = await _api.authenticatedRequest(
        'POST',
        '/api/sync',
        body: {
          'last_synced_at': lastSynced?.toUtc().toIso8601String(),
          'categories': categories,
          'transactions': transactions,
          'receipts': receipts,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _api.setLastSyncedAt(DateTime.parse(data['server_time']));
        return (true, null);
      }

      // Try to extract server error detail
      String msg = 'Server returned ${response.statusCode}';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['detail'] != null) {
          msg = body['detail'].toString();
        }
      } catch (_) {}
      return (false, msg);
    } on Exception catch (e) {
      return (false, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      _isSyncing = false;
    }
  }
}
