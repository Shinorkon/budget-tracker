import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper around [FlutterLocalNotificationsPlugin] so the rest of the
/// app can fire-and-forget notifications without worrying about channel setup
/// or permissions.
///
/// Channels:
///   * `budgy_sync`  — sync and SMS import status
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _syncChannelId = 'budgy_sync';
  static const _syncChannelName = 'Sync & Imports';
  static const _syncChannelDesc =
      'Notifications about cloud sync and SMS imports';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  int _notificationId = 1000;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    if (!kIsWeb && Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _syncChannelId,
          _syncChannelName,
          description: _syncChannelDesc,
          importance: Importance.defaultImportance,
        ),
      );
      // Android 13+ runtime permission. Safe to call on older APIs.
      await android?.requestNotificationsPermission();
    }

    if (!kIsWeb && Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  /// Show a sync/import notification. Safe to call before [init] — the call
  /// will be silently dropped rather than crashing.
  Future<void> showSync({
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;

    const android = AndroidNotificationDetails(
      _syncChannelId,
      _syncChannelName,
      channelDescription: _syncChannelDesc,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: false,
    );
    const ios = DarwinNotificationDetails(presentSound: false);
    const details = NotificationDetails(android: android, iOS: ios);

    try {
      await _plugin.show(_notificationId++, title, body, details);
    } catch (e) {
      debugPrint('NotificationService.showSync error: $e');
    }
  }
}
