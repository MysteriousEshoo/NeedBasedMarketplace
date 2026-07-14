import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../providers/theme_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/seller_request_provider.dart';
import '../models/seller_request_model.dart';
import 'seller_registration_sheet.dart';

/// Standalone screen (opened from the Profile screen) that lets a user switch
/// between Seller and Buyer mode. Seller Mode stays locked behind an approval
/// request — see [SellerRequestProvider].
class MarketplaceModeScreen extends StatefulWidget {
  const MarketplaceModeScreen({super.key});

  @override
  State<MarketplaceModeScreen> createState() => _MarketplaceModeScreenState();
}

class _MarketplaceModeScreenState extends State<MarketplaceModeScreen> {
  bool _isSellerMode = false;

  @override
  void initState() {
    super.initState();
    _loadSellerMode();
  }

  void _loadSellerMode() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get()
        .then((doc) {
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            _isSellerMode = data['isSellerMode'] ?? false;
          });
        }
      } else {
        _createUserDocument(user);
      }
    }).catchError((e) {
      print('Error loading seller mode: $e');
    });
  }

  Future<void> _createUserDocument(User user) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': user.displayName ?? 'User',
        'email': user.email ?? '',
        'isSellerMode': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating user document: $e');
    }
  }

  Future<void> _toggleSellerMode(bool value) async {
    setState(() => _isSellerMode = value);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final docRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        await docRef.update({
          'isSellerMode': value,
        });
      } else {
        await docRef.set({
          'uid': user.uid,
          'name': user.displayName ?? 'User',
          'email': user.email ?? '',
          'isSellerMode': value,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      _showCoreFeedback(
          value ? '🔵 Seller Mode activated!' : '🟢 Buyer Mode activated!');
    } catch (e) {
      setState(() => _isSellerMode = !value);
      _showCoreFeedback('Error updating mode: ${e.toString()}');
    }
  }

  // --------------------------------------------------------------------------
  // Seller registration + approval gating
  // --------------------------------------------------------------------------

  String _sellerModeSubtitle(SellerRequestStatus status) {
    switch (status) {
      case SellerRequestStatus.approved:
        return _isSellerMode
            ? 'You can view all needs and submit offers'
            : 'Approved — turn on to start selling';
      case SellerRequestStatus.pending:
        return 'Your seller request is pending approval';
      case SellerRequestStatus.rejected:
        return 'Request rejected. Tap the switch to re-apply';
      case SellerRequestStatus.none:
        return 'Register as a seller to submit offers';
    }
  }

  Future<void> _handleSellerModeToggle(
    bool value,
    SellerRequestStatus status,
    SettingsProvider settingsProvider,
  ) async {
    // Turning Seller Mode OFF is always allowed.
    if (!value) {
      await _toggleSellerMode(false);
      return;
    }

    // Turning it ON requires an approved seller request.
    switch (status) {
      case SellerRequestStatus.approved:
        await _toggleSellerMode(true);
        await settingsProvider.setBuyerMode(false);
        break;
      case SellerRequestStatus.pending:
        _showCoreFeedback(
            '⏳ Your seller request is still pending approval.');
        break;
      case SellerRequestStatus.rejected:
      case SellerRequestStatus.none:
        await _showSellerAccountDialog(status, settingsProvider);
        break;
    }
  }

  /// 🧭 inDrive-style pre-check before seller registration:
  /// "Already have a seller account?" vs "Request a seller account".
  Future<void> _showSellerAccountDialog(
    SellerRequestStatus status,
    SettingsProvider settingsProvider,
  ) async {
    final bool isDark =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final Color surface = isDark ? AppColors.surface : Colors.white;
    final Color textPrimary =
        isDark ? AppColors.textPrimary : Colors.black87;
    final Color textSecondary =
        isDark ? AppColors.textSecondary : Colors.black54;

    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.storefront_rounded,
                  color: AppColors.primaryLight, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Switch to Seller',
                  style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 17)),
            ),
          ],
        ),
        content: Text(
          'Do you already have a seller account, or would you like to request one?',
          style: TextStyle(color: textSecondary, fontSize: 13),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.pop(dialogContext, 'existing'),
              child: const Text('I already have a seller account',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primaryLight),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.pop(dialogContext, 'request'),
              child: Text('Don\'t have one? Request seller account',
                  style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
            ),
          ),
        ],
      ),
    );

    if (!mounted || choice == null) return;

    if (choice == 'request') {
      await _openSellerRegistration();
      return;
    }

    // "I already have a seller account" → re-check the LIVE status (the
    // provider streams RTDB, so approval may have landed since build).
    final liveStatus = context.read<SellerRequestProvider>().status;
    switch (liveStatus) {
      case SellerRequestStatus.approved:
        await _toggleSellerMode(true);
        await settingsProvider.setBuyerMode(false);
        break;
      case SellerRequestStatus.pending:
        _showCoreFeedback(
            '⏳ Your seller request is under review. Please wait for approval.');
        break;
      case SellerRequestStatus.rejected:
        _showCoreFeedback(
            '❌ Your previous request was rejected. You can re-apply below.');
        await _openSellerRegistration();
        break;
      case SellerRequestStatus.none:
        _showCoreFeedback(
            'ℹ️ No seller account found for this user. Please request one.');
        await _openSellerRegistration();
        break;
    }
  }

  Future<void> _openSellerRegistration() async {
    final submitted = await showSellerRegistrationSheet(context);
    if (submitted == true && mounted) {
      _showCoreFeedback(
          '📨 Request sent! We\'ll notify you once it is reviewed.');
    }
  }

  Widget _buildSellerStatusBanner(SellerRequestStatus status) {
    late final IconData icon;
    late final Color color;
    late final String label;

    switch (status) {
      case SellerRequestStatus.pending:
        icon = Icons.hourglass_top_rounded;
        color = AppColors.urgentMedium;
        label = 'Pending approval';
        break;
      case SellerRequestStatus.rejected:
        icon = Icons.cancel_rounded;
        color = AppColors.urgentHigh;
        label = 'Rejected — tap switch to re-apply';
        break;
      case SellerRequestStatus.none:
        icon = Icons.storefront_rounded;
        color = AppColors.primaryLight;
        label = 'Not registered as a seller';
        break;
      case SellerRequestStatus.approved:
        return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showCoreFeedback(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDarkMode = themeProvider.isDarkMode;

    final settingsProvider = Provider.of<SettingsProvider>(context);
    final bool isBuyerMode = settingsProvider.isBuyerMode;

    final sellerRequestProvider = Provider.of<SellerRequestProvider>(context);
    final SellerRequestStatus sellerStatus = sellerRequestProvider.status;

    final Color currentBg =
        isDarkMode ? AppColors.background : const Color(0xFFF1F5F9);
    final Color currentSurface = isDarkMode ? AppColors.surface : Colors.white;
    final Color currentBorder =
        isDarkMode ? AppColors.border : const Color(0xFFCBD5E1);
    final Color currentText =
        isDarkMode ? AppColors.textPrimary : Colors.black87;
    final Color currentSubText =
        isDarkMode ? AppColors.textTertiary : Colors.black54;

    return Scaffold(
      backgroundColor: currentBg,
      appBar: AppBar(
        backgroundColor: currentSurface,
        title: Text('Switch Seller / Buyer Mode',
            style: TextStyle(color: currentText)),
        centerTitle: true,
        iconTheme: IconThemeData(color: currentText),
        elevation: 0,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
            child: Text(
                'Choose how you want to use the marketplace. Selling requires a one-time approval.',
                style: TextStyle(color: currentSubText, fontSize: 12)),
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color: currentSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: currentBorder)),
            child: Column(
              children: [
                SwitchListTile(
                  activeColor: AppColors.primaryLight,
                  title: Text('Seller Mode',
                      style: TextStyle(
                          color: currentText,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  subtitle: Text(_sellerModeSubtitle(sellerStatus),
                      style: TextStyle(color: currentSubText, fontSize: 11)),
                  value: _isSellerMode &&
                      sellerStatus == SellerRequestStatus.approved,
                  onChanged: (value) => _handleSellerModeToggle(
                      value, sellerStatus, settingsProvider),
                ),
                if (sellerStatus != SellerRequestStatus.approved)
                  _buildSellerStatusBanner(sellerStatus),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color: currentSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: currentBorder)),
            child: SwitchListTile(
              activeColor: AppColors.primaryLight,
              title: Text('Buyer / Customer Mode',
                  style: TextStyle(
                      color: currentText,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              subtitle: Text('Toggle client consumer search panel',
                  style: TextStyle(color: currentSubText, fontSize: 11)),
              value: isBuyerMode,
              onChanged: (value) async {
                await settingsProvider.toggleBuyerMode();
                if (value) {
                  await _toggleSellerMode(false);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
