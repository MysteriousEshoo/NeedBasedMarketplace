import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/need_model.dart';
import '../theme/app_colors.dart';
import 'home_screen.dart';
import 'need_detail_screen.dart';
import 'post_need_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final List<Need> _needs = []; // Firebase dynamic feed handle karega
  int _tabIndex = 0;
  int _postSignal = 0;

  Future<void> _openPostNeed() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PostNeedScreen()),
    );
  }

  void _openDetail(Need need) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NeedDetailScreen(need: need)),
    );
  }

  void _onTabSelected(int index) {
    if (index == 2) {
      _openPostNeed();
      return;
    }
    setState(() => _tabIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _GlowingFab(onPressed: _openPostNeed),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          // Index 0: Home Feed
          HomeScreen(
            needs: _needs,
            postSignal: _postSignal,
            onOpenDetail: _openDetail,
          ),

          // Index 1: LIVE SAVED NEEDS TAB (Relational Data Fetching Architecture)
          _SavedNeedsTab(onOpenDetail: _openDetail),

          // Index 2: FAB Spacer
          const SizedBox.shrink(),

          // Index 3: Messages
          const _PlaceholderTab(
            icon: Icons.chat_bubble_rounded,
            title: 'Messages',
            message: 'All your conversations with providers will live here.',
          ),

          // Index 4: Profile
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _tabIndex,
        onTap: _onTabSelected,
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// PROFESSIONAL SUB-WIDGET: Saved Needs Live View (Inline Optimized)
// ----------------------------------------------------------------------------
class _SavedNeedsTab extends StatelessWidget {
  final void Function(Need need) onOpenDetail;
  const _SavedNeedsTab({required this.onOpenDetail});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please login to view saved needs'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Needs'),
        centerTitle: true,
      ),
      // Step 1: Listen to User's Saved IDs Tree
      body: StreamBuilder(
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
            return const _PlaceholderTab(
              icon: Icons.bookmark_border_rounded,
              title: 'No Saved Needs',
              message:
                  'Your bookmarked requirements will appear here once added.',
            );
          }

          final Map<dynamic, dynamic> savedMap =
              savedSnapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          final Set<String> savedIds =
              savedMap.keys.map((e) => e.toString()).toSet();

          // Step 2: Fetch Master Needs Feed and Intersect
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
                            : (data['urgency'] == 'low'
                                ? Urgency.low
                                : Urgency.medium),
                        authorName: data['authorName'] ?? 'Anonymous',
                        offers: data['offers'] ?? 0,
                      ),
                    );
                  }
                });
              }

              if (bookmarkedNeeds.isEmpty) {
                return const _PlaceholderTab(
                  icon: Icons.bookmark_border_rounded,
                  title: 'No Saved Needs',
                  message:
                      'Your bookmarked requirements will appear here once added.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: bookmarkedNeeds.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final need = bookmarkedNeeds[index];
                  // Using HomeScreen's Need Card view
                  return HomeScreenCardViewPlaceholder(
                      need: need, onOpenDetail: onOpenDetail);
                },
              );
            },
          );
        },
      ),
    );
  }
}

// Temporary internal adapter to use the dynamic card
// Temporary internal adapter to use the dynamic card
class HomeScreenCardViewPlaceholder extends StatelessWidget {
  final Need need;
  final void Function(Need need) onOpenDetail;
  const HomeScreenCardViewPlaceholder(
      {super.key, required this.need, required this.onOpenDetail});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        // FIXED: Yeh onTap missing tha jiski wajah se click kaam nahi kar raha tha!
        onTap: () => onOpenDetail(need),
        title: Text(
          need.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(need.description,
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
        trailing: Text(
          'Rs. ${need.budget}',
          style: const TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.bold,
              fontSize: 15),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Bottom navigation
// ----------------------------------------------------------------------------
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadow, blurRadius: 20, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                selected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              // FIXED: Replaced Explore placeholder with Saved tab link
              _NavItem(
                icon: Icons.bookmark_rounded,
                label: 'Saved',
                selected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              const SizedBox(width: 64), // FAB gap
              _NavItem(
                icon: Icons.chat_bubble_rounded,
                label: 'Messages',
                selected: currentIndex == 3,
                onTap: () => onTap(3),
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                selected: currentIndex == 4,
                onTap: () => onTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textTertiary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.1 : 1,
              duration: const Duration(milliseconds: 200),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 96,
                width: 96,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 44, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              Text(title,
                  style: textTheme.headlineMedium?.copyWith(fontSize: 24)),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge
                    ?.copyWith(color: AppColors.textSecondary, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowingFab extends StatefulWidget {
  const _GlowingFab({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_GlowingFab> createState() => _GlowingFabState();
}

class _GlowingFabState extends State<_GlowingFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final glow = 14 + _controller.value * 16;
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.45),
                blurRadius: glow,
                spreadRadius: _controller.value * 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        );
      },
      child: FloatingActionButton(
        onPressed: widget.onPressed,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }
}
