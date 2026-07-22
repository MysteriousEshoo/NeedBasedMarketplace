import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAJlk1DnGcNrNtL_OmTyJPx7nMPxDlkEV0',
    appId: '1:636560866742:android:0f263c75201551dfa0d517',
    messagingSenderId: '636560866742',
    projectId: 'studyplanner1367',
    databaseURL: 'https://studyplanner1367-default-rtdb.firebaseio.com',
    storageBucket: 'studyplanner1367.firebasestorage.app',
  );

  static FirebaseOptions get ios => throw UnsupportedError(
        'DefaultFirebaseOptions are not configured for iOS - '
        'run FlutterFire configure with --platforms=ios to register an iOS app.',
      );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB5Wj8YpawOhKh8LkpAEzdR2XTEEnSYQnk',
    appId: '1:636560866742:web:3a00f1878d069b5ea0d517',
    messagingSenderId: '636560866742',
    projectId: 'studyplanner1367',
    authDomain: 'studyplanner1367.firebaseapp.com',
    databaseURL: 'https://studyplanner1367-default-rtdb.firebaseio.com',
    storageBucket: 'studyplanner1367.firebasestorage.app',
    measurementId: 'G-RD421TJP5C',
  );

}