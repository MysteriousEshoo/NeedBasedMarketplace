import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 🔔 WhatsApp-style device notifications.
///
/// Shows a heads-up banner at the top of the phone (even while the app is
/// open) and drops the entry into the Android/iOS notification shade —
/// exactly like WhatsApp does when a message arrives.
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// High-importance channel → Android renders it as a heads-up popup.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'needhub_alerts',
    'NeedHub Alerts',
    description: 'Real-time alerts for offers, messages and matching needs',
    importance: Importance.max,
  );

  Future<void> init() async {
    if (_initialized || kIsWeb) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_channel);
    // Android 13+ runtime permission for posting notifications.
    await androidImpl?.requestNotificationsPermission();

    _initialized = true;
  }

  /// Fires a system heads-up notification (WhatsApp style).
  Future<void> show({
    required String title,
    required String body,
    int? id,
  }) async {
    if (kIsWeb) return;
    if (!_initialized) await init();

    await _plugin.show(
      id ?? DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          ticker: title,
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}
