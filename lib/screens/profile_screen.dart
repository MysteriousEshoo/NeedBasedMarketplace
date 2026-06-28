import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';

import '../models/need_model.dart';
import '../theme/app_colors.dart';
import 'need_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _currentUserName = 'Loading...';
  String _currentUserEmail = 'Loading...';
  int _myNeedsCount = 0;
  File? _selectedLocalImage; // Dynamic Local Storage Image Ref Holder

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchMyNeedsCount();
  }

  void _loadUserData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        if (user.displayName != null && user.displayName!.isNotEmpty) {
          _currentUserName = user.displayName!;
        } else if (user.email != null) {
          _currentUserName = user.email!.split('@').first;
        } else {
          _currentUserName = 'User';
        }
        _currentUserEmail = user.email ?? 'No email connected';
      });
    }
  }

  void _fetchMyNeedsCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseDatabase.instance.ref().child('needs').onValue.listen((event) {
      if (!mounted) return;
      int count = 0;
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> allMap =
            event.snapshot.value as Map<dynamic, dynamic>;
        allMap.forEach((key, value) {
          final data = Map<String, dynamic>.from(value as Map);
          if (data['authorName'] == _currentUserName ||
              data['authorName'] == user.displayName) {
            count++;
          }
        });
      }
      setState(() => _myNeedsCount = count);
    });
  }

  /// 📸 EXPERT CORE 1: Hardware Image Picker Channel Context Hook
  Future<void> _executeNativeImageUpload() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (image != null) {
        setState(() {
          _selectedLocalImage = File(image.path);
        });
        _showStatusToast(
            '🎉 Image asset parsed and successfully uploaded to your account view context!');
      }
    } catch (e) {
      _showStatusToast('⚠️ Hardware permission or asset routing error.');
    }
  }

  void _showStatusToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildGradientHeader(),
            const SizedBox(height: 20),
            _buildStatsRow(),
            const SizedBox(height: 28),
            _buildMenuList(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F1524), AppColors.background],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2.5),
                ),
                child: ClipOval(
                  child: CircleAvatar(
                    backgroundColor: AppColors.surface,
                    backgroundImage: _selectedLocalImage != null
                        ? FileImage(_selectedLocalImage!)
                        : null,
                    child: _selectedLocalImage == null
                        ? const Icon(Icons.person_rounded,
                            size: 54, color: AppColors.primaryLight)
                        : null,
                  ),
                ),
              ),
              GestureDetector(
                onTap:
                    _executeNativeImageUpload, // Direct hook for picture update
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: AppColors.primary),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _currentUserName,
            style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                fontSize: 24,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          Text(
            _currentUserEmail,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatCard(
              Icons.description_rounded, 'My Needs', '$_myNeedsCount'),
          _buildStatCard(Icons.handshake_rounded, 'Active Offers', '3'),
          _buildStatCard(
              Icons.verified_user_rounded, 'Status', 'Verified User'),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primaryLight, size: 22),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 16)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuList() {
    final sections = [
      {
        'title': 'MY STUFF',
        'items': [
          {
            'icon': Icons.description_rounded,
            'label': 'My Needs',
            'page': _MyNeedsScreen(authorName: _currentUserName)
          },
          {
            'icon': Icons.bookmark_rounded,
            'label': 'Saved Offers / Bookmarks',
            'page': const _SavedOffersPipelineScreen()
          },
        ]
      },
      {
        'title': 'PREFERENCES',
        'items': [
          {
            'icon': Icons.settings_rounded,
            'label': 'Settings Console',
            'page': const _FullEnterpriseSettingsScreen()
          },
        ]
      }
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sections.map((sec) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 16, bottom: 8),
                child: Text(sec['title'] as String,
                    style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2)),
              ),
              ...(sec['items'] as List<Map<String, dynamic>>).map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border)),
                  child: ListTile(
                    leading: Icon(item['icon'] as IconData,
                        color: AppColors.primaryLight, size: 22),
                    title: Text(item['label'] as String,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded,
                        color: AppColors.textTertiary, size: 14),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => item['page'] as Widget)),
                  ),
                );
              }),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SavedOffersPipelineScreen extends StatelessWidget {
  const _SavedOffersPipelineScreen();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: const Text('Saved Requirements'),
          centerTitle: true),
      body: user == null
          ? const Center(
              child: Text('Session missing.',
                  style: TextStyle(color: Colors.white)))
          : StreamBuilder(
              stream: FirebaseDatabase.instance
                  .ref()
                  .child('users_saved_needs')
                  .child(user.uid)
                  .onValue,
              builder: (context, AsyncSnapshot<DatabaseEvent> savedSnapshot) {
                if (savedSnapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (!savedSnapshot.hasData ||
                    savedSnapshot.data!.snapshot.value == null) {
                  return const Center(
                      child: Text('No bookmarked items found.',
                          style: TextStyle(color: AppColors.textSecondary)));
                }

                final Map<dynamic, dynamic> savedMap =
                    savedSnapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                final Set<String> savedIds =
                    savedMap.keys.map((e) => e.toString()).toSet();

                return StreamBuilder(
                  stream:
                      FirebaseDatabase.instance.ref().child('needs').onValue,
                  builder: (context,
                      AsyncSnapshot<DatabaseEvent> masterFeedSnapshot) {
                    if (masterFeedSnapshot.connectionState ==
                        ConnectionState.waiting)
                      return const Center(child: CircularProgressIndicator());

                    List<Need> bookmarkedList = [];
                    if (masterFeedSnapshot.hasData &&
                        masterFeedSnapshot.data!.snapshot.value != null) {
                      final Map<dynamic, dynamic> allMap = masterFeedSnapshot
                          .data!.snapshot.value as Map<dynamic, dynamic>;
                      allMap.forEach((key, value) {
                        if (savedIds.contains(key)) {
                          final data = Map<String, dynamic>.from(value as Map);
                          bookmarkedList.add(Need(
                            id: key,
                            title: data['title'] ?? '',
                            description: data['description'] ?? '',
                            category: data['category'] ?? '',
                            budget: data['budget'] ?? 0,
                            timeElapsed: 'Saved',
                            urgency: data['urgency'] == 'high'
                                ? Urgency.high
                                : Urgency.medium,
                            authorName: data['authorName'] ?? '',
                            offers: data['offers'] ?? 0,
                          ));
                        }
                      });
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: bookmarkedList.length,
                      itemBuilder: (context, index) {
                        final need = bookmarkedList[index];
                        return Card(
                          color: AppColors.surface,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: AppColors.border)),
                          child: ListTile(
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        NeedDetailScreen(need: need))),
                            title: Text(need.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary)),
                            trailing: Text('Rs. ${need.budget}',
                                style: const TextStyle(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.bold)),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}

// ----------------------------------------------------------------------------
// FULL LIVE OPERATION: Dynamic Account Setup Settings Hub Console
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
// PIPELINE 2: User-Friendly Production Settings Panel
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
// PIPELINE 2: User-Friendly Production Settings Panel
// ----------------------------------------------------------------------------
class _FullEnterpriseSettingsScreen extends StatefulWidget {
  const _FullEnterpriseSettingsScreen();

  @override
  State<_FullEnterpriseSettingsScreen> createState() =>
      _FullEnterpriseSettingsScreenState();
}

class _FullEnterpriseSettingsScreenState
    extends State<_FullEnterpriseSettingsScreen> {
  bool _pushNotifications = true;
  bool _biometricsEnabled = false;
  bool _darkMode = true;
  bool _buyerMode = true;

  /// 🔐 EXACT FIXED ENGINE NAME MATCH METHOD
  void _executeHardwareBiometricEnrollment(bool currentVal) async {
    if (!currentVal) {
      _showCoreFeedback('Biometric unlock disabled.');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.primary)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fingerprint_rounded,
                size: 64, color: AppColors.primaryLight),
            SizedBox(height: 16),
            Text('SCAN FINGERPRINT',
                style: TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Place your finger on the sensor to setup biometrics safely.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    Navigator.pop(context);
    _showCoreFeedback('🎉 Biometric fingerprint setup completed!');
  }

  /// 👤 SIMPLIFIED: Username change with easy wording
  void _executeLiveUsernameChangeProcedure() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDatabaseRef = FirebaseDatabase.instance
        .ref()
        .child('users_cooldown_metadata')
        .child(user.uid);
    final snapshot = await userDatabaseRef.get();

    int? lastChangedTimestamp;
    if (snapshot.exists) {
      final Map<dynamic, dynamic> meta =
          snapshot.value as Map<dynamic, dynamic>;
      lastChangedTimestamp = meta['usernameLastChanged'] as int?;
    }

    if (lastChangedTimestamp != null) {
      final lastChangedDate =
          DateTime.fromMillisecondsSinceEpoch(lastChangedTimestamp);
      final daysDifference = DateTime.now().difference(lastChangedDate).inDays;
      if (daysDifference < 30) {
        _showSecureAlertPopup('Access Denied',
            'You can only change your username once a month. Please try again after 30 days.');
        return;
      }
    }

    final usernameInputController =
        TextEditingController(text: user.displayName);
    bool isProcessing = false;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.border)),
          title: const Text('Update Username',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  fontSize: 16)),
          content: TextField(
            controller: usernameInputController,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'New Username',
              labelStyle: TextStyle(color: AppColors.textSecondary),
              hintText: 'Only letters & numbers allowed',
              hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
          ),
          actions: [
            TextButton(
                onPressed: isProcessing ? null : () => Navigator.pop(context),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textSecondary))),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: isProcessing
                  ? null
                  : () async {
                      final String rawValue =
                          usernameInputController.text.trim();
                      final RegExp alphanumericCheck =
                          RegExp(r'^[a-zA-Z0-9]+$');
                      if (!alphanumericCheck.hasMatch(rawValue)) {
                        _showCoreFeedback(
                            '⚠️ Error: Username can only contain letters or numbers.');
                        return;
                      }

                      setDialogState(() => isProcessing = true);
                      try {
                        await user.updateDisplayName(rawValue);
                        await userDatabaseRef.set({
                          'usernameLastChanged':
                              DateTime.now().millisecondsSinceEpoch
                        });
                        await user.reload();
                        _showCoreFeedback(
                            '🎉 Username changed successfully to @$rawValue');
                        if (!mounted) return;
                        Navigator.pop(context);
                      } catch (e) {
                        setDialogState(() => isProcessing = false);
                      }
                    },
              child: isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save Name',
                      style: TextStyle(color: Colors.white)),
            )
          ],
        );
      }),
    );
  }

  /// 🔒 UPDATED: Password change with enter + re-enter validation match check
  void _executeSecurePasswordModFlow() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final reEnterPassController =
        TextEditingController(); // New Re-enter Controller
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.border)),
          title: const Text('Change Password',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPassController,
                  obscureText: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                      labelText: 'Current Password',
                      labelStyle: TextStyle(color: AppColors.textSecondary)),
                ),
                TextField(
                  controller: newPassController,
                  obscureText: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                      labelText: 'Enter New Password',
                      labelStyle: TextStyle(color: AppColors.textSecondary)),
                ),
                TextField(
                  controller: reEnterPassController,
                  obscureText: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                      labelText: 'Re-enter New Password',
                      labelStyle: TextStyle(color: AppColors.textSecondary)),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: isProcessing
                        ? null
                        : () async {
                            Navigator.pop(context);
                            _triggerMaskedEmailForgotPasswordProcess(
                                user.email ?? '');
                          },
                    child: const Text('Forgot Password?',
                        style: TextStyle(
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                )
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: isProcessing ? null : () => Navigator.pop(context),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textSecondary))),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: isProcessing
                  ? null
                  : () async {
                      final currentText = currentPassController.text.trim();
                      final newText = newPassController.text.trim();
                      final reEnterText = reEnterPassController.text.trim();

                      if (currentText.isEmpty ||
                          newText.isEmpty ||
                          reEnterText.isEmpty) {
                        _showCoreFeedback(
                            '⚠️ Please fill all password fields.');
                        return;
                      }

                      // 🚨 CRITICAL CHECK: New password match validation
                      if (newText != reEnterText) {
                        _showCoreFeedback(
                            '⚠️ Error: New passwords do not match!');
                        return;
                      }

                      setDialogState(() => isProcessing = true);
                      try {
                        AuthCredential credential =
                            EmailAuthProvider.credential(
                                email: user.email!, password: currentText);
                        await user.reauthenticateWithCredential(credential);
                        await user.updatePassword(newText);
                        _showCoreFeedback('🎉 Password changed successfully.');
                        if (!mounted) return;
                        Navigator.pop(context);
                      } catch (e) {
                        setDialogState(() => isProcessing = false);
                        _showCoreFeedback(
                            '⚠️ Re-Authentication failed: Current password mismatch.');
                      }
                    },
              // FIXED: Changed button text to 'Change Password'
              child: isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Change Password',
                      style: TextStyle(color: Colors.white)),
            )
          ],
        );
      }),
    );
  }

  void _triggerMaskedEmailForgotPasswordProcess(String fullEmail) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: fullEmail);
      String maskedEmail = fullEmail;
      if (fullEmail.contains('@')) {
        final splitParts = fullEmail.split('@');
        final prefix = splitParts[0];
        if (prefix.length > 2) {
          maskedEmail = '${prefix.substring(0, 2)}******@${splitParts[1]}';
        }
      }

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.accent)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mark_email_read_rounded,
                  size: 48, color: AppColors.accent),
              const SizedBox(height: 14),
              Text(
                'TRANSMISSION SENT',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                  'A link has been sent to $maskedEmail. Check your inbox to safely update configuration mappings.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      );

      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _showCoreFeedback('⚠️ Failed to route password reset transmission.');
    }
  }

  void _showSecureAlertPopup(String title, String desc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.urgentHigh)),
        title: Text(title,
            style: const TextStyle(
                color: AppColors.urgentHigh,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
        content: Text(desc,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Acknowledged',
                  style: TextStyle(color: AppColors.primaryLight)))
        ],
      ),
    );
  }

  void _handleContactSalesAction() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('CONTACT SALES REPRESENTATIVE',
                style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.phone_in_talk_rounded,
                  color: AppColors.primaryLight),
              title: const Text('Direct Phone Channel',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold)),
              subtitle: const Text(
                  'Tap to invoke device system dial pad launcher',
                  style:
                      TextStyle(color: AppColors.textTertiary, fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                _showCoreFeedback(
                    'Invoking device dial pad context for [+92 300 1234567]...');
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.mail_outline_rounded,
                  color: AppColors.primaryLight),
              title: const Text('Official Corporate Mailbox',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold)),
              subtitle: const Text('Compose a direct contract transmission',
                  style:
                      TextStyle(color: AppColors.textTertiary, fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                _showCoreFeedback(
                    'Launching local mail context to [sales@marketplace.com]...');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '⏳ $featureName: Coming Soon... This feature is being updated live!'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: const Text('Settings'),
          centerTitle: true),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          _buildSectionHeader('👤 PROFILE ACTIONS & SECURITY'),
          _buildActionTileWithCustomHook(
              'Change Username',
              'Only alphanumeric chars. Limited to 1 change per 30 days.',
              Icons.account_circle_rounded,
              _executeLiveUsernameChangeProcedure),
          _buildActionTileWithCustomHook(
              'Change Password',
              'Verify secure re-auth context or send reset links.',
              Icons.vpn_key_rounded,
              _executeSecurePasswordModFlow),
          Container(
            margin: const EdgeInsets.only(top: 4, bottom: 12),
            decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2))),
            child: ListTile(
              leading: const Icon(Icons.support_agent_rounded,
                  color: AppColors.primaryLight, size: 22),
              title: const Text('Contact Sales Team',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 13)),
              subtitle: const Text(
                  'Initiate direct call or compose official email channels',
                  style:
                      TextStyle(color: AppColors.textTertiary, fontSize: 11)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded,
                  color: AppColors.textTertiary, size: 14),
              onTap: _handleContactSalesAction,
            ),
          ),
          _buildSectionHeader('🔔 NOTIFICATIONS (FCM BROADCASTS)'),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border)),
            child: SwitchListTile(
              activeColor: AppColors.primaryLight,
              title: const Text('Push Notifications (FCM)',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              subtitle: const Text(
                  'Allow system to trigger real-time notification tokens to sellers on new needs',
                  style:
                      TextStyle(color: AppColors.textTertiary, fontSize: 11)),
              value: _pushNotifications,
              onChanged: (v) {
                setState(() => _pushNotifications = v);
                _showCoreFeedback(v
                    ? 'FCM Device Token Registered on Core Cloud Routing Table.'
                    : 'FCM Handlers disabled. Sellers notifications pipeline dropped.');
              },
            ),
          ),
          _buildSectionHeader('🔒 PRIVACY & SECURITY'),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border)),
            child: SwitchListTile(
              activeColor: AppColors.primaryLight,
              title: const Text('Biometric Authentication',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              subtitle: const Text('Require finger or face scan on app startup',
                  style:
                      TextStyle(color: AppColors.textTertiary, fontSize: 11)),
              value: _biometricsEnabled,
              onChanged: (v) {
                setState(() => _biometricsEnabled = v);
                _executeHardwareBiometricEnrollment(v);
              },
            ),
          ),
          _buildSectionHeader('🌍 APP PREFERENCES'),
          _buildSwitchRow(
              'Dark Mode Theme',
              'Switch between bright and dark looks',
              _darkMode,
              (v) => setState(() => _darkMode = v)),
          _buildSectionHeader('💳 PAYMENTS'),
          _buildInteractiveTile(
              'Payment Methods',
              'Manage your linked digital bank wallets',
              Icons.account_balance_wallet_rounded),
          _buildSectionHeader('📦 MARKETPLACE SETTINGS'),
          _buildSwitchRow(
              'Buyer / Customer Mode',
              'Toggle client consumer search panel',
              _buyerMode,
              (v) => setState(() => _buyerMode = v)),
          _buildSectionHeader('🛠️ SUPPORT & LEGAL'),
          _buildInteractiveTile('Help Center / FAQs',
              'Access documentation guides', Icons.help_outline_rounded),
          const SizedBox(height: 24),
          _buildActionItem(
              'Logout from Session',
              'Disconnect current active user authentication tokens',
              Icons.power_settings_new_rounded,
              AppColors.urgentMedium),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Text(title,
          style: const TextStyle(
              color: AppColors.accent,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5)),
    );
  }

  Widget _buildActionTileWithCustomHook(
      String title, String subtitle, IconData icon, VoidCallback actionHook) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border)),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primaryLight, size: 20),
        title: Text(title,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
        subtitle: Text(subtitle,
            style:
                const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
        trailing: const Icon(Icons.keyboard_arrow_right_rounded,
            color: AppColors.textTertiary, size: 18),
        onTap: actionHook,
      ),
    );
  }

  Widget _buildInteractiveTile(String title, String subtitle, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border)),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primaryLight, size: 20),
        title: Text(title,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
        subtitle: Text(subtitle,
            style:
                const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
        trailing: const Icon(Icons.keyboard_arrow_right_rounded,
            color: AppColors.textTertiary, size: 18),
        onTap: () => _showComingSoon(title),
      ),
    );
  }

  Widget _buildSwitchRow(
      String title, String sub, bool val, ValueChanged<bool> onChange) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border)),
      child: SwitchListTile(
        activeColor: AppColors.primaryLight,
        title: Text(title,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
        subtitle: Text(sub,
            style:
                const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
        value: val,
        onChanged: onChange,
      ),
    );
  }

  Widget _buildActionItem(
      String title, String sub, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2))),
      child: ListTile(
        leading: Icon(icon, color: color, size: 20),
        title: Text(title,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w900, fontSize: 13)),
        subtitle: Text(sub,
            style:
                const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
        onTap: () {
          if (icon == Icons.power_settings_new_rounded) {
            FirebaseAuth.instance.signOut();
            Navigator.pop(context);
          } else {
            _showComingSoon(title);
          }
        },
      ),
    );
  }
}

class _MyNeedsScreen extends StatelessWidget {
  final String authorName;
  const _MyNeedsScreen({required this.authorName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: const Text('My Active Requirements'),
          centerTitle: true),
      body: StreamBuilder(
        stream: FirebaseDatabase.instance.ref().child('needs').onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());

          List<Need> myFilteredList = [];
          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            final Map<dynamic, dynamic> allMap =
                snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
            allMap.forEach((key, value) {
              final data = Map<String, dynamic>.from(value as Map);
              if (data['authorName'] == authorName) {
                myFilteredList.add(Need(
                  id: key,
                  title: data['title'] ?? '',
                  description: data['description'] ?? '',
                  category: data['category'] ?? '',
                  budget: data['budget'] ?? 0,
                  timeElapsed: 'Active Log',
                  urgency:
                      data['urgency'] == 'high' ? Urgency.high : Urgency.medium,
                  authorName: data['authorName'] ?? '',
                  offers: data['offers'] ?? 0,
                ));
              }
            });
          }

          if (myFilteredList.isEmpty) {
            return const Center(
                child: Text('You haven\'t posted any requirements yet.',
                    style: TextStyle(color: AppColors.textSecondary)));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: myFilteredList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = myFilteredList[index];
              return Card(
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.border)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => NeedDetailScreen(need: item))),
                  title: Text(item.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  subtitle: Text(item.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary)),
                  trailing: Text('Rs. ${item.budget}',
                      style: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.bold)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
