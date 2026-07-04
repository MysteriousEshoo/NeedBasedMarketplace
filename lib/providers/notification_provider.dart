import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class NotificationProvider extends ChangeNotifier {
  bool _notificationsEnabled = true;
  bool _isLoading = true;

  NotificationProvider() {
    _loadNotificationSettings();
  }

  bool get notificationsEnabled => _notificationsEnabled;
  bool get isLoading => _isLoading;

  Future<void> _loadNotificationSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snapshot = await FirebaseDatabase.instance
            .ref()
            .child('user_settings')
            .child(user.uid)
            .child('notifications')
            .get();

        if (snapshot.exists) {
          _notificationsEnabled = snapshot.value as bool? ?? true;
        }
      }
    } catch (e) {
      _notificationsEnabled = true;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> toggleNotifications() async {
    _notificationsEnabled = !_notificationsEnabled;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseDatabase.instance
            .ref()
            .child('user_settings')
            .child(user.uid)
            .child('notifications')
            .set(_notificationsEnabled);
      }
    } catch (e) {
      _notificationsEnabled = !_notificationsEnabled;
      notifyListeners();
    }
  }

  Future<void> setNotifications(bool value) async {
    if (_notificationsEnabled != value) {
      _notificationsEnabled = value;
      notifyListeners();

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseDatabase.instance
              .ref()
              .child('user_settings')
              .child(user.uid)
              .child('notifications')
              .set(value);
        }
      } catch (e) {
        _notificationsEnabled = !value;
        notifyListeners();
      }
    }
  }
}
