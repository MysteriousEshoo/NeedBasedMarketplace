import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/app_colors.dart';
import 'seller_registration_sheet.dart';
import 'main_shell.dart';

/// 🧭 FIRST-RUN ROLE SELECTION (inDrive style)
/// Shown ONCE right after signup (email or first-time Google). Asks the user
/// whether they want to start as a Seller or a Buyer.
///
/// - Buyer  → marks `roleSelected: true` and the root auth gate swaps to
///            MainShell in the existing buyer mode.
/// - Seller → opens the existing seller registration sheet. After the request
///            is submitted the user still continues in BUYER mode (seller is
///            only unlocked after admin approval — existing flow untouched).
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _isSaving = false;

  Future<void> _completeSelection() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({'roleSelected': true}, SetOptions(merge: true));

    if (!mounted) return;
    // Matches the app's imperative navigation style (AuthScreen does the
    // same). The root gate also reacts to the flag on cold start.
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  Future<void> _chooseBuyer() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await _completeSelection();
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _toast('⚠️ Something went wrong. Please try again.');
      }
    }
  }

  Future<void> _chooseSeller() async {
    if (_isSaving) return;
    final submitted = await showSellerRegistrationSheet(context);
    if (!mounted) return;

    if (submitted == true) {
      setState(() => _isSaving = true);
      try {
        await _completeSelection();
        if (mounted) {
          _toast(
              '📨 Request sent! You\'ll start in buyer mode until approval.');
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          _toast('⚠️ Something went wrong. Please try again.');
        }
      }
    }
    // Sheet dismissed without submitting → stay here so the user can decide.
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark ? AppColors.background : const Color(0xFFF1F5F9);
    final Color textPrimary =
        isDark ? AppColors.textPrimary : Colors.black87;
    final Color textSecondary =
        isDark ? AppColors.textSecondary : Colors.black54;

    return PopScope(
      canPop: false, // role must be chosen — can't back out
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: _isSaving
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primaryLight))
              : Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 🎨 Illustration — gradient glow circle, app style
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primaryDark,
                                AppColors.primary,
                                AppColors.primaryLight,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.glow.withOpacity(0.45),
                                blurRadius: 40,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.swap_horiz_rounded,
                              color: Colors.white, size: 76),
                        ),
                        const SizedBox(height: 36),
                        Text(
                          'Are you a seller or a buyer?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'You can change mode later',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 44),

                        // 🟢 BUYER
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _chooseBuyer,
                            icon: const Icon(Icons.shopping_bag_rounded,
                                color: Colors.white, size: 22),
                            label: const Text(
                              'I\'M A BUYER',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 🔵 SELLER
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: AppColors.primaryLight, width: 1.4),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _chooseSeller,
                            icon: const Icon(Icons.storefront_rounded,
                                color: AppColors.primaryLight, size: 22),
                            label: Text(
                              'I\'M A SELLER',
                              style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Sellers need a one-time approval. You\'ll browse as a buyer until your request is approved.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: textSecondary, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
