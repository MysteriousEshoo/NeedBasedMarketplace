import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/main_shell.dart';
import 'screens/auth_screen.dart';
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/payment_provider.dart'; // ✅ ADD THIS
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()), // ✅ ADD THIS
      ],
      child: const NeedMarketplaceApp(),
    ),
  );
}

class NeedMarketplaceApp extends StatelessWidget {
  const NeedMarketplaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'NeedHub',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.currentTheme,
      darkTheme: AppTheme.dark,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData) {
            return const MainShell();
          }

          return const AuthScreen();
        },
      ),
    );
  }
}
