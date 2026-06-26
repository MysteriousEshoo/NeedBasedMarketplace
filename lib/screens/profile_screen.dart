import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/need_model.dart';
import '../theme/app_colors.dart';
import 'need_detail_screen.dart'; // REQUIRED: For redirection click

/// Premium, scrollable profile screen with gradient header, stats, and menu.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildGradientHeader(),
            const SizedBox(height: 28),
            _buildStatsRow(),
            const SizedBox(height: 32),
            _buildMenuList(),
            const SizedBox(height: 20),
            _buildLogoutButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Gradient header with avatar and edit overlay.
  Widget _buildGradientHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.primary.withValues(alpha: 0.02),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        children: [
          // Avatar with edit overlay
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Container(
                    color: AppColors.primaryLight.withValues(alpha: 0.1),
                    child: const Center(
                      child: Icon(
                        Icons.person_rounded,
                        size: 60,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
              // Edit icon overlay
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.primary,
                      content: const Text('Edit Profile coming soon'),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      duration: const Duration(milliseconds: 1500),
                    ),
                  );
                },
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Name
          Text(
            'Ayesha Khan',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontSize: 24,
                ),
          ),
          const SizedBox(height: 6),
          // Email
          Text(
            'ayesha.khan@email.com',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  /// Stats row showing key metrics.
  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatCard(
            icon: Icons.description_rounded,
            label: 'Active Needs',
            value: '6',
          ),
          _buildStatCard(
            icon: Icons.handshake_rounded,
            label: 'Total Offers',
            value: '12',
          ),
          _buildStatCard(
            icon: Icons.calendar_today_rounded,
            label: 'Member Since',
            value: '2024',
          ),
        ],
      ),
    );
  }

  /// Individual stat card with icon, label, and value.
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: AppColors.primary,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// Clean menu list with rounded tiles and live navigation redirection.
  Widget _buildMenuList() {
    final menuItems = [
      {
        'icon': Icons.description_rounded,
        'label': 'My Needs',
        'action': () => _showMenuAction('My Needs'),
      },
      {
        'icon': Icons.bookmark_rounded,
        'label': 'Saved Offers',
        'action': () {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => _StandaloneSavedNeedsScreen(),
            ),
          );
        },
      },
      {
        'icon': Icons.credit_card_rounded,
        'label': 'Payment Methods',
        'action': () => _showMenuAction('Payment Methods'),
      },
      {
        'icon': Icons.settings_rounded,
        'label': 'Settings',
        'action': () => _showMenuAction('Settings'),
      },
      {
        'icon': Icons.help_center_rounded,
        'label': 'Help & Support',
        'action': () => _showMenuAction('Help & Support'),
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: List.generate(
          menuItems.length,
          (index) {
            final item = menuItems[index];
            return Padding(
              padding: EdgeInsets.only(
                  bottom: index < menuItems.length - 1 ? 10 : 0),
              child: GestureDetector(
                onTap: item['action'] as VoidCallback,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border, width: 0.8),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 6,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        item['label'] as String,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppColors.textTertiary,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Logout button at the bottom with soft red tint.
  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => _showLogoutConfirmation(),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.urgentHigh.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.urgentHigh.withValues(alpha: 0.2),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.urgentHigh.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.logout_rounded,
                color: AppColors.urgentHigh,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'Logout',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.urgentHigh,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show menu action feedback.
  void _showMenuAction(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
        content: Text('$action coming soon'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  /// Show logout confirmation dialog.
  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        backgroundColor: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.urgentHigh.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.urgentHigh,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Logout?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to logout from your account?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Cancel',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppColors.primary,
                            content: const Text('Logged out successfully'),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            duration: const Duration(milliseconds: 1500),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.urgentHigh,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Logout',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// STANDALONE SUB-SCREEN: Profile "My Saved" Collection (FULLY CLICKABLE)
// ----------------------------------------------------------------------------
class _StandaloneSavedNeedsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Saved Needs'),
        centerTitle: true,
      ),
      body: StreamBuilder(
        stream: FirebaseDatabase.instance
            .ref()
            .child('users_saved_needs')
            .child(user?.uid ?? '')
            .onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> savedSnapshot) {
          if (savedSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!savedSnapshot.hasData ||
              savedSnapshot.data!.snapshot.value == null) {
            return const Center(
              child: Text('No saved needs found.',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }

          final Map<dynamic, dynamic> savedMap =
              savedSnapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          final Set<String> savedIds =
              savedMap.keys.map((e) => e.toString()).toSet();

          return StreamBuilder(
            stream: FirebaseDatabase.instance.ref().child('needs').onValue,
            builder: (context, AsyncSnapshot<DatabaseEvent> needsSnapshot) {
              if (needsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              List<Need> bookmarkedNeeds = [];

              if (needsSnapshot.hasData &&
                  needsSnapshot.data!.snapshot.value != null) {
                final Map<dynamic, dynamic> allMap =
                    needsSnapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                allMap.forEach((key, value) {
                  if (savedIds.contains(key)) {
                    final data = Map<String, dynamic>.from(value as Map);
                    bookmarkedNeeds.add(
                      Need(
                        id: key,
                        title: data['title'] ?? '',
                        description: data['description'] ?? '',
                        category: data['category'] ?? '',
                        budget: data['budget'] ?? 0,
                        timeElapsed: 'Saved',
                        urgency: data['urgency'] == 'high'
                            ? Urgency.high
                            : Urgency.medium,
                        authorName: data['authorName'] ?? 'Anonymous',
                        offers: data['offers'] ?? 0,
                      ),
                    );
                  }
                });
              }

              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: bookmarkedNeeds.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final need = bookmarkedNeeds[index];

                  // FIXED: Added full interactive GestureDetector for smooth redirection
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NeedDetailScreen(need: need),
                        ),
                      );
                    },
                    child: Card(
                      margin: EdgeInsets.zero,
                      color: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(need.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(need.description,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Rs. ${need.budget}',
                                style: const TextStyle(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_ios_rounded,
                                size: 14, color: AppColors.textTertiary),
                          ],
                        ),
                      ),
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
