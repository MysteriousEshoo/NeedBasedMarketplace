import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';
import '../widgets/brand_logo.dart';

/// 💧 Branded splash — max 2-3 seconds with a 0→100% loading bar.
///
/// While the bar fills, the app warms up in the background: local cache
/// (SharedPreferences), the signed-in user's profile document, their
/// settings and the live needs feed are all prefetched so the home screen
/// opens with refreshed data instead of spinners.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onDone});

  /// Fired once loading completes (bar reaches 100%).
  final VoidCallback onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _duration = Duration(milliseconds: 2500); // 2-3s max

  late final AnimationController _progress;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this, duration: _duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finish();
      })
      ..forward();
    _prefetch();
  }

  /// Warm caches while the bar animates. Every branch is fire-and-forget and
  /// individually guarded — a slow network can never hold the splash past
  /// its 2.5s ceiling because completion is driven by the animation.
  Future<void> _prefetch() async {
    try {
      // Local cache (onboarding flag, theme, saved prefs).
      unawaited(SharedPreferences.getInstance());

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Refresh auth state (email verification etc.).
        unawaited(user.reload().then((_) {}, onError: (_) {}));
        // Profile doc → role/seller mode ready before MainShell builds.
        unawaited(FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get()
            .then((_) {}, onError: (_) {}));
        // User settings + latest needs feed → Realtime DB fills its local
        // cache so the home feed paints instantly.
        unawaited(FirebaseDatabase.instance
            .ref()
            .child('user_settings')
            .child(user.uid)
            .get()
            .then((_) {}, onError: (_) {}));
      }
      unawaited(FirebaseDatabase.instance
          .ref()
          .child('needs')
          .limitToLast(30)
          .get()
          .then((_) {}, onError: (_) {}));
    } catch (_) {
      // Prefetch is best-effort only.
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark ? AppColors.background : Colors.white;
    final Color textPrimary =
        isDark ? AppColors.textPrimary : const Color(0xFF0F172A);
    final Color textSecondary =
        isDark ? AppColors.textSecondary : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const BrandLogo(size: 132, borderRadius: 28),
                    const SizedBox(height: 24),
                    Text(
                      'Need Base',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pakistan\'s need-based marketplace',
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            // Loading bar 0 → 100%
            Padding(
              padding: const EdgeInsets.fromLTRB(48, 0, 48, 48),
              child: AnimatedBuilder(
                animation: _progress,
                builder: (context, _) {
                  final pct = (_progress.value * 100).round();
                  return Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _progress.value,
                          minHeight: 6,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.15),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '$pct%',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
