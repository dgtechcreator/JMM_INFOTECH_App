import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/api_client.dart';

const String _defaultChannelId = 'jmm_default_channel';
const String _defaultChannelName = 'General notifications';

final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

/// Must be a top-level (or static) function — this is what actually lets a notification reach the user
/// while the app is fully closed/killed, not just backgrounded. Android already shows a system-tray
/// notification for any FCM message that has a `notification` payload (which is what
/// PushNotificationService.cs always sends) without this handler doing anything further; it exists so
/// Firebase has *something* registered for background messages, per the plugin's own requirement.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Push notifications (Firebase Cloud Messaging) — the app-side half of
/// MVC.Services/PushNotificationService.cs + NotificationService.Notify(). Call [initialize] once at
/// app startup (before runApp) and [registerToken] once a user is signed in (fresh login and app
/// restart both need it — a token can rotate at any time, and the backend has no token at all until the
/// first successful registration).
class PushNotificationService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const androidChannel = AndroidNotificationChannel(_defaultChannelId, _defaultChannelName, importance: Importance.high);
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
    await _localNotifications.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );

    await FirebaseMessaging.instance.requestPermission();

    // Android does NOT auto-display a system notification while the app is in the foreground (only
    // background/terminated) — without this listener, a push sent while the app is open would be
    // silently dropped from the user's point of view even though PushNotificationService.cs succeeded.
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _localNotifications.show(
        message.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(_defaultChannelId, _defaultChannelName, importance: Importance.high, priority: Priority.high),
        ),
      );
    });
  }

  /// Safe to call even if the user isn't signed in yet or the network call fails — registration is
  /// best-effort and retried on every app start / login, so a transient failure just means push
  /// notifications don't reach this device until the next successful call.
  static Future<void> registerToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _sendTokenToServer(token);
      }
      FirebaseMessaging.instance.onTokenRefresh.listen(_sendTokenToServer);
    } catch (e) {
      if (kDebugMode) print('Push token registration failed: $e');
    }
  }

  static Future<void> _sendTokenToServer(String token) async {
    try {
      await ApiClient.instance.post('/EmployeeApp/RegisterDeviceToken', data: {'token': token, 'platform': 'android'});
    } catch (_) {
      // Best-effort — see registerToken's doc comment.
    }
  }
}
