import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/notification_model.dart';

class NotificationService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? data,
  }) async {
    final notification = NotificationModel(
      id: '',
      title: title,
      body: body,
      type: type,
      data: data,
      timestamp: DateTime.now(),
      seen: false,
    );

    await _db
        .child('notifications')
        .child(userId)
        .push()
        .set(notification.toMap());

    print('🔔 Notification sent to: $userId');
    print('🔔 Title: $title');
  }

  Stream<List<NotificationModel>> getNotifications(String userId) {
    return _db
        .child('notifications')
        .child(userId)
        .orderByChild('timestamp')
        .onValue
        .map((event) {
      final List<NotificationModel> notifications = [];

      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final notification = NotificationModel.fromMap(
              key, Map<String, dynamic>.from(value as Map));
          notifications.add(notification);
        });
      }

      notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return notifications;
    });
  }

  Future<void> markAsSeen(String userId, String notificationId) async {
    await _db
        .child('notifications')
        .child(userId)
        .child(notificationId)
        .child('seen')
        .set(true);
  }

  Future<void> markAllAsSeen(String userId) async {
    final snapshot = await _db.child('notifications').child(userId).get();

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      for (var key in data.keys) {
        await _db
            .child('notifications')
            .child(userId)
            .child(key)
            .child('seen')
            .set(true);
      }
    }
  }

  Stream<int> getUnreadCount(String userId) {
    return _db
        .child('notifications')
        .child(userId)
        .orderByChild('seen')
        .equalTo(false)
        .onValue
        .map((event) {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        return data.length;
      }
      return 0;
    });
  }
}
