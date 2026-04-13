import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../models/budget_provider.dart';
import '../models/receipt_provider.dart';
import 'api_service.dart';
import 'notification_service.dart';
import 'sync_queue.dart';
import 'sync_service.dart';

/// Keeps the cloud copy in sync with local edits without requiring the user
/// to open Settings → Sync Now.
///
/// Two triggers:
///   1. **Connectivity transitions offline → online** — full sync, drains any
///      queued mutations first.
///   2. **Local mutations** — every time [BudgetProvider] or [ReceiptProvider]
///      fires `notifyListeners`, a 10-second idle timer is rearmed. When the
///      timer fires we attempt a sync. The debounce collapses rapid edits
///      (e.g. renaming a category, editing its budget, adding a transaction
///      in quick succession) into a single upload.
///
/// Both triggers share a single [SyncService] instance, so only one sync runs
/// at a time (guarded by `_isSyncing` inside `SyncService`).
class LiveSyncService {
  LiveSyncService._();
  static final LiveSyncService instance = LiveSyncService._();

  static const _debounce = Duration(seconds: 10);

  BudgetProvider? _budget;
  ReceiptProvider? _receipts;
  SyncService? _sync;
  ApiService? _api;

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Timer? _debounceTimer;
  bool _lastOnline = true;
  bool _started = false;

  /// Public progress mirror so UI can listen once globally.
  ValueNotifier<SyncProgress> get progress =>
      _sync?.progress ?? ValueNotifier(SyncProgress(SyncState.idle));

  Future<void> start({
    required BudgetProvider budget,
    required ReceiptProvider receipts,
    required ApiService api,
  }) async {
    if (_started) return;
    _started = true;

    _budget = budget;
    _receipts = receipts;
    _api = api;
    _sync = SyncService(
      api: api,
      budgetProvider: budget,
      receiptProvider: receipts,
    );

    _lastOnline = await SyncQueue.isOnline;

    budget.addListener(_onLocalMutation);
    receipts.addListener(_onLocalMutation);

    _connSub = Connectivity().onConnectivityChanged.listen(_onConnectivity);
  }

  Future<void> stop() async {
    _budget?.removeListener(_onLocalMutation);
    _receipts?.removeListener(_onLocalMutation);
    await _connSub?.cancel();
    _connSub = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _started = false;
  }

  /// Immediate sync, used by Settings → Sync Now. Returns the same
  /// (success, message) tuple [SyncService.sync] does.
  Future<(bool, String?)> syncNow() async {
    final sync = _sync;
    if (sync == null) return (false, 'Live sync not started');
    _debounceTimer?.cancel();
    return sync.sync();
  }

  Future<void> _onConnectivity(List<ConnectivityResult> results) async {
    final online = !results.contains(ConnectivityResult.none);
    final transitionedOnline = online && !_lastOnline;
    _lastOnline = online;

    if (!transitionedOnline) return;
    await _attemptSync(reason: 'connectivity');
  }

  void _onLocalMutation() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => _attemptSync(reason: 'debounce'));
  }

  Future<void> _attemptSync({required String reason}) async {
    final sync = _sync;
    final api = _api;
    if (sync == null || api == null) return;

    if (!(await api.isLoggedIn)) return;
    if (!(await SyncQueue.isOnline)) return;

    // Before/after transaction counts let us report what actually changed.
    final beforeCats = _budget?.categories.length ?? 0;
    final beforeTxns = _budget?.transactions.length ?? 0;
    final beforeRcpts = _receipts?.receipts.length ?? 0;

    final (ok, err) = await sync.sync();

    if (!ok) {
      debugPrint('LiveSyncService($reason) failed: $err');
      return;
    }

    // After a successful push we can drop anything the offline queue had
    // been tracking — the full sync already reconciled everything.
    await SyncQueue.clear();

    final afterCats = _budget?.categories.length ?? 0;
    final afterTxns = _budget?.transactions.length ?? 0;
    final afterRcpts = _receipts?.receipts.length ?? 0;

    final deltaCats = afterCats - beforeCats;
    final deltaTxns = afterTxns - beforeTxns;
    final deltaRcpts = afterRcpts - beforeRcpts;

    // Only notify for connectivity-driven syncs — debounced syncs fire
    // constantly during active use and would spam the shade.
    if (reason != 'connectivity') return;

    final summary = _summary(deltaCats, deltaTxns, deltaRcpts);
    await NotificationService.instance.showSync(
      title: 'Budgy synced',
      body: summary,
    );
  }

  String _summary(int cats, int txns, int rcpts) {
    final parts = <String>[];
    if (txns > 0) parts.add('$txns transaction${txns == 1 ? "" : "s"}');
    if (cats > 0) parts.add('$cats categor${cats == 1 ? "y" : "ies"}');
    if (rcpts > 0) parts.add('$rcpts receipt${rcpts == 1 ? "" : "s"}');
    if (parts.isEmpty) return 'No new changes from the cloud.';
    return 'Pulled ${parts.join(", ")}.';
  }
}
