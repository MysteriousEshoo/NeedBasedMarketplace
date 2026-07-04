import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/need_model.dart';
import '../theme/app_colors.dart';
import 'need_detail_screen.dart';
import 'payment_methods_screen.dart';
import 'help_screen.dart';
import '../providers/theme_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/notification_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _currentUserName = 'Loading...';
  String _currentUserEmail = 'Loading...';
  int _myNeedsCount = 0;
  File? _selectedLocalImage;

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

  Future<void> _executeNativeImageUpload() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (image != null) {
        setState(() {
          _selectedLocalImage = File(image.path);
        });
        _showStatusToast('🎉 Image uploaded successfully!');
      }
    } catch (e) {
      _showStatusToast('⚠️ Error uploading image.');
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDarkMode = themeProvider.isDarkMode;

    final Color bg =
        isDarkMode ? AppColors.background : const Color(0xFFF1F5F9);
    final Color surface = isDarkMode ? AppColors.surface : Colors.white;
    final Color border =
        isDarkMode ? AppColors.border : const Color(0xFFE2E8F0);
    final Color textPrimary =
        isDarkMode ? AppColors.textPrimary : const Color(0xFF0F172A);
    final Color textSecondary =
        isDarkMode ? AppColors.textSecondary : const Color(0xFF475569);
    final Color textTertiary =
        isDarkMode ? AppColors.textTertiary : const Color(0xFF94A3B8);
    final Color headerGradientTop =
        isDarkMode ? const Color(0xFF0F1524) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildGradientHeader(
              headerGradientTop: headerGradientTop,
              bg: bg,
              surface: surface,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            const SizedBox(height: 20),
            _buildStatsRow(
              surface: surface,
              border: border,
              textPrimary: textPrimary,
              textTertiary: textTertiary,
            ),
            const SizedBox(height: 28),
            _buildMenuList(
              surface: surface,
              border: border,
              textPrimary: textPrimary,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientHeader({
    required Color headerGradientTop,
    required Color bg,
    required Color surface,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [headerGradientTop, bg],
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
                    backgroundColor: surface,
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
                onTap: _executeNativeImageUpload,
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
            style: TextStyle(
                fontWeight: FontWeight.w900,
                color: textPrimary,
                fontSize: 24,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          Text(
            _currentUserEmail,
            style: TextStyle(
                color: textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow({
    required Color surface,
    required Color border,
    required Color textPrimary,
    required Color textTertiary,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatCard(Icons.description_rounded, 'My Needs',
              '$_myNeedsCount', surface, border, textPrimary, textTertiary),
          _buildStatCard(Icons.handshake_rounded, 'Active Offers', '3', surface,
              border, textPrimary, textTertiary),
          _buildStatCard(Icons.verified_user_rounded, 'Status', 'Verified User',
              surface, border, textPrimary, textTertiary),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value,
      Color surface, Color border, Color textPrimary, Color textTertiary) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primaryLight, size: 22),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                    fontSize: 16)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuList({
    required Color surface,
    required Color border,
    required Color textPrimary,
  }) {
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
                      color: surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: border)),
                  child: ListTile(
                    leading: Icon(item['icon'] as IconData,
                        color: AppColors.primaryLight, size: 22),
                    title: Text(item['label'] as String,
                        style: TextStyle(
                            color: textPrimary,
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

// ----------------------------------------------------------------------------
// Saved Offers Pipeline Screen
// ----------------------------------------------------------------------------

class _SavedOffersPipelineScreen extends StatelessWidget {
  const _SavedOffersPipelineScreen();

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDarkMode = themeProvider.isDarkMode;
    final Color bg =
        isDarkMode ? AppColors.background : const Color(0xFFF1F5F9);
    final Color surface = isDarkMode ? AppColors.surface : Colors.white;
    final Color border =
        isDarkMode ? AppColors.border : const Color(0xFFE2E8F0);
    final Color textPrimary =
        isDarkMode ? AppColors.textPrimary : const Color(0xFF0F172A);
    final Color textSecondary =
        isDarkMode ? AppColors.textSecondary : const Color(0xFF475569);

    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
          backgroundColor: surface,
          title:
              Text('Saved Requirements', style: TextStyle(color: textPrimary)),
          iconTheme: IconThemeData(color: textPrimary),
          centerTitle: true),
      body: user == null
          ? Center(
              child: Text('Session missing.',
                  style: TextStyle(color: textPrimary)))
          : StreamBuilder(
              stream: FirebaseDatabase.instance
                  .ref()
                  .child('users_saved_needs')
                  .child(user.uid)
                  .onValue,
              builder: (context, AsyncSnapshot<DatabaseEvent> savedSnapshot) {
                if (savedSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!savedSnapshot.hasData ||
                    savedSnapshot.data!.snapshot.value == null) {
                  return Center(
                      child: Text('No bookmarked items found.',
                          style: TextStyle(color: textSecondary)));
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
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

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
                          color: surface,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: border)),
                          child: ListTile(
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        NeedDetailScreen(need: need))),
                            title: Text(need.title,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary)),
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
// FULL SETTINGS SCREEN
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
  bool _fingerprintEnabled = false;
  bool _faceIdEnabled = false;
  bool _isSellerMode = false;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSellerMode();
    _loadNotificationSettings();
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

  void _loadNotificationSettings() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseDatabase.instance
        .ref()
        .child('user_settings')
        .child(user.uid)
        .child('notifications')
        .get()
        .then((snapshot) {
      if (snapshot.exists) {
        if (mounted) {
          setState(() {
            _notificationsEnabled = snapshot.value as bool? ?? true;
          });
        }
      }
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

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseDatabase.instance
          .ref()
          .child('user_settings')
          .child(user.uid)
          .child('notifications')
          .set(value);

      _showCoreFeedback(
          value ? '🔔 Notifications enabled' : '🔕 Notifications disabled');
    } catch (e) {
      setState(() => _notificationsEnabled = !value);
      _showCoreFeedback('Error: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDarkMode = themeProvider.isDarkMode;

    final settingsProvider = Provider.of<SettingsProvider>(context);
    final bool isBuyerMode = settingsProvider.isBuyerMode;

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
        title: Text('Settings', style: TextStyle(color: currentText)),
        centerTitle: true,
        iconTheme: IconThemeData(color: currentText),
        elevation: 0,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          _buildSectionHeader('👤 PROFILE ACTIONS & SECURITY'),
          _buildActionTileWithCustomHook(
              'Change Username',
              'Only alphanumeric chars. Limited to 1 change per 30 days.',
              Icons.account_circle_rounded,
              _executeLiveUsernameChangeProcedure,
              currentSurface,
              currentBorder,
              currentText,
              currentSubText),
          _buildActionTileWithCustomHook(
              'Change Password',
              'Verify secure re-auth context or send reset links.',
              Icons.vpn_key_rounded,
              _executeSecurePasswordModFlow,
              currentSurface,
              currentBorder,
              currentText,
              currentSubText),

          Container(
            margin: const EdgeInsets.only(top: 4, bottom: 12),
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.2))),
            child: ListTile(
              leading: const Icon(Icons.support_agent_rounded,
                  color: AppColors.primaryLight, size: 22),
              title: Text('Contact Sales Team',
                  style: TextStyle(
                      color: currentText,
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

          _buildSectionHeader('🔔 NOTIFICATIONS'),

          // ✅ Notification Toggle
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color: currentSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: currentBorder)),
            child: SwitchListTile(
              activeColor: AppColors.primaryLight,
              title: Text('In-App Notifications',
                  style: TextStyle(
                      color: currentText,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              subtitle: Text(
                  _notificationsEnabled
                      ? 'You will receive real-time alerts for messages and offers'
                      : 'You will not receive any notifications',
                  style: TextStyle(color: currentSubText, fontSize: 11)),
              value: _notificationsEnabled,
              onChanged: _toggleNotifications,
            ),
          ),

          _buildSectionHeader('🔒 SECURITY & BIOMETRICS'),
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
                color: currentSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: currentBorder)),
            child: SwitchListTile(
              activeColor: AppColors.primaryLight,
              title: Text('Fingerprint Unlock',
                  style: TextStyle(
                      color: currentText,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              subtitle: Text(
                  'Unlock app using your device physical fingerprint scanner',
                  style: TextStyle(color: currentSubText, fontSize: 11)),
              value: _fingerprintEnabled,
              onChanged: (v) {
                setState(() => _fingerprintEnabled = v);
                _triggerBiometricSetupConsole('fingerprint');
              },
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
              title: Text('Face ID / Recognition',
                  style: TextStyle(
                      color: currentText,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              subtitle: Text(
                  'Enable quick device look vectors for seamless authentication routing',
                  style: TextStyle(color: currentSubText, fontSize: 11)),
              value: _faceIdEnabled,
              onChanged: (v) {
                setState(() => _faceIdEnabled = v);
                _triggerBiometricSetupConsole('faceid');
              },
            ),
          ),

          _buildSectionHeader('🌍 APP PREFERENCES'),
          _buildSwitchRow(
            'Dark Mode Theme',
            'Switch between bright and dark looks',
            isDarkMode,
            (v) {
              themeProvider.setDarkMode(v);
              _showCoreFeedback(v
                  ? '🌙 Premium Dark Mode activated.'
                  : '☀️ Clean Light Mode activated.');
            },
            currentSurface,
            currentBorder,
            currentText,
            currentSubText,
          ),

          _buildSectionHeader('💳 PAYMENTS'),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color: currentSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: currentBorder)),
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet_rounded,
                  color: AppColors.primaryLight, size: 20),
              title: Text('Payment Methods',
                  style: TextStyle(
                      color: currentText,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              subtitle: Text('Manage your linked digital bank wallets',
                  style: TextStyle(color: currentSubText, fontSize: 11)),
              trailing: const Icon(Icons.keyboard_arrow_right_rounded,
                  color: AppColors.textTertiary, size: 18),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const PaymentMethodsScreen()),
                );
              },
            ),
          ),

          _buildSectionHeader('📦 MARKETPLACE SETTINGS'),

          // ✅ Seller Mode Toggle
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color: currentSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: currentBorder)),
            child: SwitchListTile(
              activeColor: AppColors.primaryLight,
              title: Text('Seller Mode',
                  style: TextStyle(
                      color: currentText,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              subtitle: Text(
                  _isSellerMode
                      ? 'You can view all needs and submit offers'
                      : 'You can only view your own needs',
                  style: TextStyle(color: currentSubText, fontSize: 11)),
              value: _isSellerMode,
              onChanged: (value) async {
                await _toggleSellerMode(value);
                if (value) {
                  await settingsProvider.setBuyerMode(false);
                }
              },
            ),
          ),

          // ✅ Buyer Mode Toggle
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

          _buildSectionHeader('🛠️ SUPPORT & LEGAL'),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color: currentSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: currentBorder)),
            child: ListTile(
              leading: const Icon(Icons.help_outline_rounded,
                  color: AppColors.primaryLight, size: 20),
              title: Text('Help Center / FAQs',
                  style: TextStyle(
                      color: currentText,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              subtitle: Text('Access documentation guides',
                  style: TextStyle(color: currentSubText, fontSize: 11)),
              trailing: const Icon(Icons.keyboard_arrow_right_rounded,
                  color: AppColors.textTertiary, size: 18),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HelpScreen()),
                );
              },
            ),
          ),

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

  // --------------------------------------------------------------------------
  // Helper Methods
  // --------------------------------------------------------------------------

  void _triggerBiometricSetupConsole(String type) async {
    bool isFingerprint = type == 'fingerprint';
    if ((isFingerprint && !_fingerprintEnabled) ||
        (!isFingerprint && !_faceIdEnabled)) {
      _showCoreFeedback(
          '${isFingerprint ? "Fingerprint" : "Face ID"} unlock disabled.');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        final themeProvider =
            Provider.of<ThemeProvider>(context, listen: false);
        final bool isDarkMode = themeProvider.isDarkMode;

        Future.delayed(const Duration(milliseconds: 2500), () {
          if (!mounted) return;
          Navigator.pop(context);
          _showCoreFeedback(
              '🎉 ${isFingerprint ? "Fingerprint" : "Face ID"} activation setup completed successfully!');
        });

        final Color popBg = isDarkMode ? AppColors.surface : Colors.white;
        final Color popText =
            isDarkMode ? AppColors.textPrimary : Colors.black87;
        final Color popSubText =
            isDarkMode ? AppColors.textSecondary : Colors.black54;

        return AlertDialog(
          backgroundColor: popBg,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: AppColors.primary.withOpacity(0.5))),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    isFingerprint
                        ? Icons.fingerprint_rounded
                        : Icons.face_retouching_natural_rounded,
                    size: 72,
                    color: AppColors.primaryLight),
                const SizedBox(height: 20),
                Text(
                    isFingerprint
                        ? 'SCANNING FINGERPRINT...'
                        : 'RECOGNIZING FACE...',
                    style: TextStyle(
                        color: popText,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.5)),
                const SizedBox(height: 10),
                Text(
                    isFingerprint
                        ? 'Please place your registered finger firmly against the device biometric sensor layout matrix.'
                        : 'Please position your device directly in front of your face and look straight into the camera lens node.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: popSubText, fontSize: 12)),
                const SizedBox(height: 24),
                const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: AppColors.primaryLight)),
              ],
            ),
          ),
        );
      }),
    );
  }

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
        final themeProvider =
            Provider.of<ThemeProvider>(context, listen: false);
        final bool isDarkMode = themeProvider.isDarkMode;

        final Color popBg = isDarkMode ? AppColors.surface : Colors.white;
        final Color popText =
            isDarkMode ? AppColors.textPrimary : Colors.black87;
        return AlertDialog(
          backgroundColor: popBg,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.border)),
          title: Text('Update Username',
              style: TextStyle(
                  fontWeight: FontWeight.w900, color: popText, fontSize: 16)),
          content: TextField(
            controller: usernameInputController,
            style: TextStyle(color: popText),
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

  void _executeSecurePasswordModFlow() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final reEnterPassController = TextEditingController();
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        final themeProvider =
            Provider.of<ThemeProvider>(context, listen: false);
        final bool isDarkMode = themeProvider.isDarkMode;

        final Color popBg = isDarkMode ? AppColors.surface : Colors.white;
        final Color popText =
            isDarkMode ? AppColors.textPrimary : Colors.black87;
        return AlertDialog(
          backgroundColor: popBg,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.border)),
          title: Text('Change Password',
              style: TextStyle(
                  fontWeight: FontWeight.w900, color: popText, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPassController,
                  obscureText: true,
                  style: TextStyle(color: popText),
                  decoration: const InputDecoration(
                      labelText: 'Current Password',
                      labelStyle: TextStyle(color: AppColors.textSecondary)),
                ),
                TextField(
                  controller: newPassController,
                  obscureText: true,
                  style: TextStyle(color: popText),
                  decoration: const InputDecoration(
                      labelText: 'Enter New Password',
                      labelStyle: TextStyle(color: AppColors.textSecondary)),
                ),
                TextField(
                  controller: reEnterPassController,
                  obscureText: true,
                  style: TextStyle(color: popText),
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
        builder: (context) {
          final themeProvider =
              Provider.of<ThemeProvider>(context, listen: false);
          final bool isDarkMode = themeProvider.isDarkMode;

          return AlertDialog(
            backgroundColor: isDarkMode ? AppColors.surface : Colors.white,
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
                      color:
                          isDarkMode ? AppColors.textPrimary : Colors.black87,
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
          );
        },
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
      builder: (context) {
        final themeProvider =
            Provider.of<ThemeProvider>(context, listen: false);
        final bool isDarkMode = themeProvider.isDarkMode;

        return AlertDialog(
          backgroundColor: isDarkMode ? AppColors.surface : Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.urgentHigh)),
          title: Text(title,
              style: const TextStyle(
                  color: AppColors.urgentHigh,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          content: Text(desc,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Acknowledged',
                    style: TextStyle(color: AppColors.primaryLight)))
          ],
        );
      },
    );
  }

  void _handleContactSalesAction() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        final themeProvider =
            Provider.of<ThemeProvider>(context, listen: false);
        final bool isDarkMode = themeProvider.isDarkMode;

        return Padding(
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
                title: Text('Direct Phone Channel',
                    style: TextStyle(
                        color:
                            isDarkMode ? AppColors.textPrimary : Colors.black87,
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
                title: Text('Official Corporate Mailbox',
                    style: TextStyle(
                        color:
                            isDarkMode ? AppColors.textPrimary : Colors.black87,
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
        );
      },
    );
  }

  void _showComingSoon(String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⏳ $featureName: Coming Soon...'),
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

  // --------------------------------------------------------------------------
  // Build Helper Widgets
  // --------------------------------------------------------------------------

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
      String title,
      String subtitle,
      IconData icon,
      VoidCallback actionHook,
      Color surface,
      Color border,
      Color text,
      Color subText) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border)),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primaryLight, size: 20),
        title: Text(title,
            style: TextStyle(
                color: text, fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle:
            Text(subtitle, style: TextStyle(color: subText, fontSize: 11)),
        trailing: const Icon(Icons.keyboard_arrow_right_rounded,
            color: AppColors.textTertiary, size: 18),
        onTap: actionHook,
      ),
    );
  }

  Widget _buildSwitchRow(
      String title,
      String sub,
      bool val,
      ValueChanged<bool> onChange,
      Color surface,
      Color border,
      Color text,
      Color subText) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border)),
      child: SwitchListTile(
        activeColor: AppColors.primaryLight,
        title: Text(title,
            style: TextStyle(
                color: text, fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(sub, style: TextStyle(color: subText, fontSize: 11)),
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
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2))),
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

// ----------------------------------------------------------------------------
// My Needs Screen
// ----------------------------------------------------------------------------

class _MyNeedsScreen extends StatelessWidget {
  final String authorName;
  const _MyNeedsScreen({required this.authorName});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDarkMode = themeProvider.isDarkMode;
    final Color bg =
        isDarkMode ? AppColors.background : const Color(0xFFF1F5F9);
    final Color surface = isDarkMode ? AppColors.surface : Colors.white;
    final Color border =
        isDarkMode ? AppColors.border : const Color(0xFFE2E8F0);
    final Color textPrimary =
        isDarkMode ? AppColors.textPrimary : const Color(0xFF0F172A);
    final Color textSecondary =
        isDarkMode ? AppColors.textSecondary : const Color(0xFF475569);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
          backgroundColor: surface,
          title: Text('My Active Requirements',
              style: TextStyle(color: textPrimary)),
          iconTheme: IconThemeData(color: textPrimary),
          centerTitle: true),
      body: StreamBuilder(
        stream: FirebaseDatabase.instance.ref().child('needs').onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

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
            return Center(
                child: Text('You haven\'t posted any requirements yet.',
                    style: TextStyle(color: textSecondary)));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: myFilteredList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = myFilteredList[index];
              return Card(
                color: surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: border)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => NeedDetailScreen(need: item))),
                  title: Text(item.title,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: textPrimary)),
                  subtitle: Text(item.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textSecondary)),
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
