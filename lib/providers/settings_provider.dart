import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class SettingsProvider extends ChangeNotifier {
  bool _isBuyerMode = true;
  bool _isLoading = true;

  SettingsProvider() {
    _loadSettings();
  }

  bool get isBuyerMode => _isBuyerMode;
  bool get isLoading => _isLoading;

  Future<void> _loadSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snapshot = await FirebaseDatabase.instance
            .ref()
            .child('user_settings')
            .child(user.uid)
            .child('isBuyerMode')
            .get();

        if (snapshot.exists) {
          _isBuyerMode = snapshot.value as bool? ?? true;
        }
      }
    } catch (e) {
      _isBuyerMode = true;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> toggleBuyerMode() async {
    _isBuyerMode = !_isBuyerMode;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseDatabase.instance
            .ref()
            .child('user_settings')
            .child(user.uid)
            .child('isBuyerMode')
            .set(_isBuyerMode);
      }
    } catch (e) {
      _isBuyerMode = !_isBuyerMode;
      notifyListeners();
    }
  }

  // ✅ ADD THIS METHOD
  Future<void> setBuyerMode(bool value) async {
    if (_isBuyerMode != value) {
      _isBuyerMode = value;
      notifyListeners();

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseDatabase.instance
              .ref()
              .child('user_settings')
              .child(user.uid)
              .child('isBuyerMode')
              .set(value);
        }
      } catch (e) {
        _isBuyerMode = !value;
        notifyListeners();
      }
    }
  }
}
