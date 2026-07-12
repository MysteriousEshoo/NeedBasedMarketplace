import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/app_colors.dart';

/// Email verification screen backed by Firebase's real email-verification link.
///
/// Flow:
///  1. On open we send a genuine verification email via Firebase (no backend
///     or third-party service required).
///  2. A short poll keeps calling `user.reload()` so the moment the user taps
///     the link in their inbox, the app detects `emailVerified == true` and
///     flips to the success state automatically.
///  3. The user can also tap "I've verified" for an instant manual re-check,
///     or resend the email after a cooldown.
///
/// Pops with `true` once the email is verified.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isSending = false;
  bool _isChecking = false;
  bool _verified = false;
  int _cooldown = 0;
  String? _error;

  Timer? _pollTimer;
  Timer? _cooldownTimer;

  String get _email => FirebaseAuth.instance.currentUser?.email ?? 'your email';

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.emailVerified) {
      _verified = true;
    } else {
      // Fire the first verification email straight away, then watch for the tap.
      WidgetsBinding.instance.addPostFrameCallback((_) => _sendVerificationEmail());
      _startPolling();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendVerificationEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _isSending || _cooldown > 0) return;

    setState(() {
      _isSending = true;
      _error = null;
    });

    try {
      await user.sendEmailVerification();
      if (mounted) {
        _startCooldown(60);
        _showToast('📧 Verification email sent to $_email');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'too-many-requests') {
        _startCooldown(60);
        setState(() => _error =
            'Too many attempts. Please wait a moment before resending.');
      } else {
        setState(() => _error = e.message ?? 'Could not send the email.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not send the email. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldown <= 1) {
        timer.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown -= 1);
      }
    });
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkVerified());
  }

  Future<void> _checkVerified({bool manual = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (manual) setState(() => _isChecking = true);
    try {
      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      if (refreshed != null && refreshed.emailVerified) {
        _pollTimer?.cancel();
        _cooldownTimer?.cancel();
        if (mounted) setState(() => _verified = true);
        return;
      }
      if (manual && mounted) {
        _showToast('Not verified yet. Please tap the link in your inbox.');
      }
    } catch (_) {
      // Network hiccup — the poll will simply retry on its next tick.
    } finally {
      if (manual && mounted) setState(() => _isChecking = false);
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark ? AppColors.background : const Color(0xFFF1F5F9);
    final Color surface = isDark ? AppColors.surface : Colors.white;
    final Color textPrimary =
        isDark ? AppColors.textPrimary : const Color(0xFF0F172A);
    final Color textSecondary =
        isDark ? AppColors.textSecondary : const Color(0xFF475569);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        title: Text(
          'Verify Email',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: _verified
                ? _buildSuccess(textPrimary, textSecondary)
                : _buildPending(surface, textPrimary, textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildPending(
      Color surface, Color textPrimary, Color textSecondary) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.12),
          ),
          child: const Icon(Icons.mark_email_unread_rounded,
              color: AppColors.primaryLight, size: 46),
        ),
        const SizedBox(height: 24),
        Text(
          'Verify your email',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(
            style: TextStyle(color: textSecondary, fontSize: 14, height: 1.5),
            children: [
              const TextSpan(text: 'We sent a secure verification link to\n'),
              TextSpan(
                text: _email,
                style: const TextStyle(
                  color: AppColors.primaryLight,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const TextSpan(
                  text:
                      '.\nOpen it and this screen will confirm you automatically.'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.urgentHigh,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _isChecking ? null : () => _checkVerified(manual: true),
            icon: _isChecking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.verified_rounded, color: Colors.white),
            label: Text(
              _isChecking ? 'Checking...' : "I've verified",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primaryLight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: (_isSending || _cooldown > 0)
                ? null
                : _sendVerificationEmail,
            icon: _isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primaryLight),
                  )
                : const Icon(Icons.refresh_rounded,
                    color: AppColors.primaryLight),
            label: Text(
              _cooldown > 0
                  ? 'Resend in ${_cooldown}s'
                  : (_isSending ? 'Sending...' : 'Resend email'),
              style: const TextStyle(
                color: AppColors.primaryLight,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(false),
          child: Text(
            'Maybe later',
            style: TextStyle(color: textSecondary, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess(Color textPrimary, Color textSecondary) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accent.withValues(alpha: 0.15),
          ),
          child: const Icon(Icons.verified_rounded,
              color: AppColors.accent, size: 56),
        ),
        const SizedBox(height: 24),
        Text(
          'Email Verified',
          style: TextStyle(
            color: textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Your email $_email is now verified.\nThanks for helping keep the marketplace trusted.',
          textAlign: TextAlign.center,
          style: TextStyle(color: textSecondary, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Continue',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
