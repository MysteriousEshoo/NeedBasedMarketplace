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
    apiKey: 'AIzaSyBnRoxBCDxNySdLvRR_TasGhpFm7QGDrGM',
    appId: '1:976134004608:android:1d48ec9ea544c31db16b65',
    messagingSenderId: '976134004608',
    projectId: 'needbasedmarketplace',
    databaseURL:
        'https://needbasedmarketplace-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'needbasedmarketplace.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBnRoxBCDxNySdLvRR_TasGhpFm7QGDrGM',
    appId: '1:976134004608:android:1d48ec9ea544c31db16b65',
    messagingSenderId: '976134004608',
    projectId: 'needbasedmarketplace',
    databaseURL:
        'https://needbasedmarketplace-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'needbasedmarketplace.firebasestorage.app',
    iosBundleId: 'com.esha.marketplace',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA1ZvbhOuNkRmvn9PFVgp_JJ6ZC_oqPwVc',
    authDomain: 'needbasedmarketplace.firebaseapp.com',
    databaseURL:
        'https://needbasedmarketplace-default-rtdb.asia-southeast1.firebasedatabase.app',
    projectId: 'needbasedmarketplace',
    storageBucket: 'needbasedmarketplace.firebasestorage.app',
    messagingSenderId: '976134004608',
    appId: '1:976134004608:web:bed2a0b2bbf65853b16b65',
  );
}
