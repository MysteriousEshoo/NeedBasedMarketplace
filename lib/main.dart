import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/main_shell.dart';
import 'screens/auth_screen.dart';
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/seller_request_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => SellerRequestProvider()),
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
      // 📱 GLOBAL RESPONSIVENESS
      // Scales all text across every screen based on device width so the UI
      // reads well on small Androids, large Androids and iPhones alike, while
      // clamping the user's system font setting so oversized fonts can never
      // cause bottom-overflow. Applied app-wide — no per-screen changes needed.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        // Width-based scale against a 390px baseline (iPhone 13 / typical
        // modern phone), gently clamped so tiny/huge devices stay balanced.
        final double widthScale = (mq.size.width / 390).clamp(0.90, 1.12);
        // Respect the user's accessibility font choice, but keep it inside a
        // safe band so layouts never break.
        final double systemScale = mq.textScaler.scale(1.0).clamp(0.85, 1.30);
        final double finalScale = widthScale * systemScale;

        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(finalScale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
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
