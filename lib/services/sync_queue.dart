import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Queues sync mutations when offline and drains them when connectivity returns.
class SyncQueue {
  static const _key = 'sync_queue_pending';

  /// Add a mutation to the offline queue.
  static Future<void> enqueue(Map<String, dynamic> mutation) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    list.add(jsonEncode(mutation));
    await prefs.setStringList(_key, list);
    debugPrint('SyncQueue: enqueued mutation (${list.length} pending)');
  }

  /// Get all pending mutations.
  static Future<List<Map<String, dynamic>>> pending() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    return list
        .map((e) => jsonDecode(e) as Map<String, dynamic>)
        .toList();
  }

  /// Clear all pending mutations after successful sync.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// Whether there are pending mutations.
  static Future<bool> get hasPending async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    return list.isNotEmpty;
  }

  /// Check if currently online.
  static Future<bool> get isOnline async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }
}
