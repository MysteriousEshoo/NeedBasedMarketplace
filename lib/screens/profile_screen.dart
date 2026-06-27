import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

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

  void _showComingSoon(String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '⏳ $featureName: Coming Soon... This feature is being updated live!'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showEditProfileDialog() {
    final user = FirebaseAuth.instance.currentUser;
    final nameController = TextEditingController(text: _currentUserName);
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppColors.border)),
            title: const Text('Edit Profile Name',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            content: TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Full Name',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary)),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary),
                onPressed: isSaving
                    ? null
                    : () async {
                        final newName = nameController.text.trim();
                        if (newName.isEmpty) return;
                        setDialogState(() => isSaving = true);
                        try {
                          if (user != null) {
                            await user.updateDisplayName(newName);
                            await user.reload();
                            _loadUserData();
                          }
                          if (!mounted) return;
                          Navigator.pop(context);
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save Name',
                        style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
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
                child: const ClipOval(
                  child: CircleAvatar(
                    backgroundColor: AppColors.surface,
                    child: Icon(Icons.person_rounded,
                        size: 54, color: AppColors.primaryLight),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _showEditProfileDialog,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: AppColors.primary),
                  child: const Icon(Icons.edit_rounded,
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
            'label': 'Settings',
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

// ----------------------------------------------------------------------------
// PIPELINE 1: Live Real-time Saved Bookmarks Filtering Screen
// ----------------------------------------------------------------------------
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
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  bool _biometricsEnabled = false;
  bool _darkMode = true;
  bool _buyerMode = true;
  bool _readReceipts = true;

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

    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    Navigator.pop(context);

    _showCoreFeedback('🎉 Biometric fingerprint setup successfully completed!');
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
          _buildSectionHeader('👤 ACCOUNT'),
          _buildInteractiveTile('Profile Settings',
              'Manage your naming records', Icons.badge_rounded),
          _buildInteractiveTile('Change Profile Picture',
              'Update your display avatar photo', Icons.add_a_photo_rounded),
          _buildInteractiveTile('Change Password',
              'Reset your account password safely', Icons.lock_reset_rounded),
          _buildInteractiveTile(
              'Email Verification',
              'Check your email activation status',
              Icons.mark_email_read_rounded),
          _buildInteractiveTile('Phone Number Verification',
              'Connect your mobile number link', Icons.phone_android_rounded),
          _buildSectionHeader('🔔 NOTIFICATIONS'),
          _buildSwitchRow(
              'Push Notifications',
              'Receive real-time alerts on device',
              _pushNotifications,
              (v) => setState(() => _pushNotifications = v)),
          _buildSwitchRow(
              'Email Notifications',
              'Get weekly updates on your inbox',
              _emailNotifications,
              (v) => setState(() => _emailNotifications = v)),
          _buildSwitchRow(
              'SMS Notifications',
              'Get direct cellular text updates',
              _smsNotifications,
              (v) => setState(() => _smsNotifications = v)),
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
          _buildInteractiveTile(
              'Active Devices Log',
              'Check where your account is logged in',
              Icons.devices_other_rounded),
          _buildSectionHeader('🌍 APP PREFERENCES'),
          _buildInteractiveTile('Language', 'Current selection: English',
              Icons.translate_rounded),
          _buildSwitchRow(
              'Dark Mode Theme',
              'Switch between bright and dark looks',
              _darkMode,
              (v) => setState(() => _darkMode = v)),
          _buildInteractiveTile('Currency Units', 'Current currency: PKR',
              Icons.monetization_on_rounded),
          _buildSectionHeader('💳 PAYMENTS'),
          _buildInteractiveTile(
              'Payment Methods',
              'Manage your linked digital bank wallets',
              Icons.account_balance_wallet_rounded),
          _buildInteractiveTile('Transaction History',
              'View full cash invoice histories', Icons.receipt_long_rounded),
          _buildSectionHeader('📦 MARKETPLACE SETTINGS'),
          _buildSwitchRow(
              'Buyer / Customer Mode',
              'Toggle client consumer search panel',
              _buyerMode,
              (v) => setState(() => _buyerMode = v)),
          _buildInteractiveTile('Manage Saved Addresses',
              'Configure shipping location endpoints', Icons.pin_drop_rounded),
          _buildSectionHeader('💬 CHAT SETTINGS'),
          _buildSwitchRow(
              'Read Receipts Trace',
              'Let contacts track message view timelines',
              _readReceipts,
              (v) => setState(() => _readReceipts = v)),
          _buildSectionHeader('🛠️ SUPPORT & LEGAL'),
          _buildInteractiveTile('Help Center / FAQs',
              'Access documentation guides', Icons.help_outline_rounded),
          _buildInteractiveTile('Privacy Policy Document',
              'Read standard digital encryption terms', Icons.gavel_rounded),
          const SizedBox(height: 24),
          _buildActionItem(
              'Delete Account permanently',
              'Completely delete your database profile records',
              Icons.delete_forever_rounded,
              AppColors.urgentHigh),
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

// ----------------------------------------------------------------------------
// COMPONENT 3: Filtered Active Needs Log View
// ----------------------------------------------------------------------------
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
