import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/main_shell.dart';
import 'screens/auth_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/seller_request_provider.dart';
import 'services/realtime_alert_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🔔 WhatsApp-style alerts: heads-up popups for every incoming in-app
  // notification + seller category-matched need alerts. Auth-bound: starts
  // on login, stops on logout.
  RealtimeAlertService.instance.bindToAuth();

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
      title: 'Need Base',
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
      home: const _LaunchGate(),
    );
  }
}

/// 🚀 Launch sequence: Splash (2-3s, loading bar, cache warm-up) →
/// Onboarding (first launch only, Skip/Next) → normal auth flow.
class _LaunchGate extends StatefulWidget {
  const _LaunchGate();

  @override
  State<_LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<_LaunchGate> {
  bool _splashDone = false;
  bool _onboardingDone = false;
  bool _checkingOnboarding = true;

  @override
  void initState() {
    super.initState();
    OnboardingScreen.alreadySeen().then((seen) {
      if (mounted) {
        setState(() {
          _onboardingDone = seen;
          _checkingOnboarding = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashDone || _checkingOnboarding) {
      return SplashScreen(
        onDone: () => setState(() => _splashDone = true),
      );
    }
    if (!_onboardingDone) {
      return OnboardingScreen(
        onFinished: () => setState(() => _onboardingDone = true),
      );
    }
    return const _AuthFlow();
  }
}

/// Auth-aware root: signed-out → AuthScreen; signed-in → role gate → shell.
class _AuthFlow extends StatelessWidget {
  const _AuthFlow();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashLoader();
        }

        if (snapshot.hasData) {
          // 🧭 ONBOARDING GATE
          // New signups carry `roleSelected: false` in their user doc and
          // must pick Buyer/Seller first (inDrive style). Existing users
          // (flag absent or true) go straight to the shell — unchanged.
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(snapshot.data!.uid)
                .snapshots(),
            builder: (context, docSnap) {
              if (docSnap.connectionState == ConnectionState.waiting) {
                return const _SplashLoader();
              }
              final data = docSnap.data?.data();
              if (docSnap.hasData &&
                  docSnap.data!.exists &&
                  data?['roleSelected'] == false) {
                return const RoleSelectionScreen();
              }
              if (docSnap.hasData && !docSnap.data!.exists) {
                // Doc still being written during signup — brief wait so a
                // brand-new user never flashes MainShell before the role
                // screen. Legacy users without a doc fall through after
                // the timeout.
                return const _DocPendingSplash();
              }
              return const MainShell();
            },
          );
        }

        return const AuthScreen();
      },
    );
  }
}

/// Branded loading screen used while auth / profile state resolves.
class _SplashLoader extends StatelessWidget {
  const _SplashLoader();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Shown when the user is authenticated but their Firestore profile document
/// hasn't landed yet (signup write in flight). If the doc never appears
/// (legacy account), falls back to MainShell after a short timeout.
class _DocPendingSplash extends StatefulWidget {
  const _DocPendingSplash();

  @override
  State<_DocPendingSplash> createState() => _DocPendingSplashState();
}

class _DocPendingSplashState extends State<_DocPendingSplash> {
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_timedOut) return const MainShell();
    return const _SplashLoader();
  }
}
