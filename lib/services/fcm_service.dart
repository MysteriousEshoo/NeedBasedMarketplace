import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/chat_screen.dart';
import '../screens/notification_screen.dart';
import 'local_notification_service.dart';

/// 🔔 FCM Push Notification Service.
///
/// Bridges Firebase Cloud Messaging (FCM) with the app's existing
/// notification system.
///
/// **Lifecycle:** `init()` is called from [RealtimeAlertService.start()] which
/// already has the authenticated user context. The method is idempotent —
/// calling it multiple times is safe (listeners are re-registered each time).
class FCMService {
  FCMService._();
  static final FCMService instance = FCMService._();

  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  String? _currentToken;

  /// Global navigator key — attach to [MaterialApp.navigatorKey] so
  /// notification taps can navigate without a [BuildContext].
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Stream of notification-payload maps received from a tap on a background
  /// or terminated notification. Screens can listen to react to deep links.
  /// The controller lives for the app's lifetime (singleton service).
  final StreamController<Map<String, String>> _navigationController =
      StreamController<Map<String, String>>.broadcast();

  Stream<Map<String, String>> get onNotificationTap =>
      _navigationController.stream;

  // --------------------------------------------------------------------------
  // Initialization
  // --------------------------------------------------------------------------

  /// Initializes FCM, registers token, sets up listeners.
  /// Safe to call multiple times — re-syncs the token each time.
  Future<void> init() async {
    if (kIsWeb) {
      await _setupWeb();
      return;
    }

    try {
      // ---- 1. Request permissions (iOS) ----
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCM] Push permission denied.');
        return;
      }

      // ---- 2. Get the current token ----
      _currentToken = await FirebaseMessaging.instance.getToken();
      await _syncToken();

      // ---- 3. Token refresh listener ----
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _currentToken = newToken;
        _syncToken();
      });

      // ---- 4. Foreground messages → local notification popup ----
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // ---- 5. App opened from background by tapping a notification ----
      FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTap);

      // ---- 6. Background message handler (top-level static fn) ----
      FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

      // ---- 7. App launched from terminated state via a notification ----
      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        Future.delayed(const Duration(milliseconds: 600), () {
          _onNotificationTap(initialMessage);
        });
      }
    } catch (e) {
      debugPrint('[FCM] Initialization error (non-fatal): $e');
    }
  }

  Future<void> _setupWeb() async {
    try {
      _currentToken = await FirebaseMessaging.instance.getToken();
      await _syncToken();
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _currentToken = newToken;
        _syncToken();
      });
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    } catch (e) {
      debugPrint('[FCM] Web init note: $e');
    }
  }

  // --------------------------------------------------------------------------
  // Token management
  // --------------------------------------------------------------------------

  /// Stores the current FCM token in Realtime DB so the Cloud Function can
  /// target it. The token path uses a sanitised key because Firebase RTDB
  /// forbids `.`, `#`, `$`, `[`, `]` in keys.
  Future<void> _syncToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentToken == null) return;
    final safeKey = _currentToken!.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
    await _db.child('fcm_tokens').child(user.uid).child(safeKey).set({
      'token': _currentToken,
      'platform': _currentPlatform(),
      'updatedAt': ServerValue.timestamp,
    });
  }

  String _currentPlatform() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
    } catch (_) {}
    return 'unknown';
  }

  /// Removes the current token from RTDB. Call on logout.
  Future<void> removeToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentToken == null) return;
    final safeKey = _currentToken!.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
    await _db
        .child('fcm_tokens')
        .child(user.uid)
        .child(safeKey)
        .remove();
    _currentToken = null;
  }

  /// Removes ALL FCM tokens for the current user (account deletion).
  Future<void> removeAllTokens() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _db.child('fcm_tokens').child(user.uid).remove();
    _currentToken = null;
  }

  // --------------------------------------------------------------------------
  // Message handlers
  // --------------------------------------------------------------------------

  void _onForegroundMessage(RemoteMessage message) {
    final nd = message.notification;
    final title = nd?.title ?? message.data['title'] ?? '';
    final body = nd?.body ?? message.data['body'] ?? '';
    if (title.isEmpty && body.isEmpty) return;
    LocalNotificationService.instance.show(title: title, body: body);
  }

  /// Called when the user taps a push notification. Navigates directly via
  /// [navigatorKey] and also emits the payload on [onNotificationTap].
  void _onNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] ?? '';
    final needId = data['needId'] ?? '';
    final needTitle = data['needTitle'] ?? 'Need';
    final otherUserId = data['otherUserId'] ?? '';
    final otherUserName = data['otherUserName'] ?? 'User';
    final offerId = data['offerId'];

    // Broadcast on the stream for any other listener.
    _navigationController.add({
      'type': type,
      'needId': needId,
      'needTitle': needTitle,
      'otherUserId': otherUserId,
      'otherUserName': otherUserName,
      if (offerId != null) 'offerId': offerId,
    });

    if (needId.isEmpty) {
      _navigateToNotificationCenter();
      return;
    }

    if (type == 'message' || type == 'offer' || type == 'offer_status') {
      _navigateToChat(
        needId: needId,
        needTitle: needTitle,
        otherUserId: otherUserId,
        otherUserName: otherUserName,
        offerId: offerId,
        showOfferDecision: type == 'offer',
      );
    } else {
      _navigateToNotificationCenter();
    }
  }

  void _navigateToChat({
    required String needId,
    required String needTitle,
    required String otherUserId,
    required String otherUserName,
    String? offerId,
    bool showOfferDecision = false,
  }) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          needId: needId,
          needTitle: needTitle,
          otherUserId: otherUserId,
          otherUserName: otherUserName,
          initialOfferId: offerId,
          showOfferDecisionOnOpen: showOfferDecision,
        ),
      ),
    );
  }

  void _navigateToNotificationCenter() {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => const NotificationScreen(),
      ),
    );
  }

  /// Public helper for screens that need to navigate to notifications
  /// (e.g. from the app bar bell icon).
  static void pushNotificationScreen() {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => const NotificationScreen(),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Background handler (top-level, separate isolate)
  // --------------------------------------------------------------------------

  @pragma('vm:entry-point')
  static Future<void> _backgroundHandler(RemoteMessage message) async {
    debugPrint('[FCM] Background message received: ${message.messageId}');
    // The system tray notification is handled natively by FCM. No Dart-side
    // work needed in the background isolate — calling Flutter APIs here
    // would crash.
  }
}
