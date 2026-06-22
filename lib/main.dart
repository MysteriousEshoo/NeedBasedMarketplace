import 'package:flutter/material.dart';

import 'screens/auth_screen.dart';
import 'theme/app_theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Nayi exact keys jo tumhare screenshot mien hain:
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyA1ZvbhOuNkRmvn9PFVgp_JJ6ZC_oqPwVc",
      authDomain: "needbasedmarketplace.firebaseapp.com",
      databaseURL:
          "https://needbasedmarketplace-default-rtdb.asia-southeast1.firebasedatabase.app",
      projectId: "needbasedmarketplace",
      storageBucket: "needbasedmarketplace.firebasestorage.app",
      messagingSenderId: "976134004608",
      appId: "1:976134004608:web:bed2a0b2bbf65853b16b65",
    ),
  );

  runApp(const NeedMarketplaceApp());
}

class NeedMarketplaceApp extends StatelessWidget {
  const NeedMarketplaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeedHub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthScreen(),
    );
  }
}
