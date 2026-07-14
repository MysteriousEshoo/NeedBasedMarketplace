import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

/// 📜 USER ACTIVITY HISTORY (Chrome-style)
/// Logs every meaningful action (offer sent, seller request sent, need
/// visited, need posted) to RTDB `user_history/{uid}` so the History screen
/// can show it in real time. Fire-and-forget: a history failure must NEVER
/// break the main feature flow.
class HistoryService {
  HistoryService._();

  static const String typeOfferSent = 'offer_sent';
  static const String typeSellerRequest = 'seller_request';
  static const String typeNeedVisited = 'need_visited';
  static const String typeNeedPosted = 'need_posted';

  /// Simple in-memory dedup so re-opening the same need within a few minutes
  /// doesn't spam the history (like Chrome collapsing rapid revisits).
  static final Map<String, DateTime> _recentVisits = {};

  static Future<void> log({
    required String type,
    required String title,
    String? subtitle,
    String? refId,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // Dedup rapid repeat visits of the same need.
      if (type == typeNeedVisited && refId != null) {
        final last = _recentVisits[refId];
        if (last != null &&
            DateTime.now().difference(last) < const Duration(minutes: 3)) {
          return;
        }
        _recentVisits[refId] = DateTime.now();
      }

      await FirebaseDatabase.instance
          .ref('user_history')
          .child(uid)
          .push()
          .set({
        'type': type,
        'title': title,
        if (subtitle != null && subtitle.isNotEmpty) 'subtitle': subtitle,
        if (refId != null) 'refId': refId,
        'timestamp': ServerValue.timestamp,
      });
    } catch (_) {
      // Never let history logging break the calling feature.
    }
  }

  /// Live stream of the user's history entries, newest first.
  static Stream<DatabaseEvent> stream() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '_none_';
    return FirebaseDatabase.instance
        .ref('user_history')
        .child(uid)
        .orderByChild('timestamp')
        .onValue;
  }

  /// Deletes the entire history for the current user.
  static Future<void> clear() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseDatabase.instance.ref('user_history').child(uid).remove();
  }
}
