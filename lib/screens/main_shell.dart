import 'package:flutter/material.dart';
import '../models/need_model.dart';
import '../theme/app_colors.dart';
import 'home_screen.dart';
import 'need_detail_screen.dart';
import 'post_need_screen.dart';

/// The root authenticated shell.
///
/// Owns the single source of truth for the in-memory needs feed, the active
/// bottom-navigation tab, and the "Post a Need" flow. Children receive the
/// data and callbacks they need, keeping state lifted in one place.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  /// Mutable feed — seeded from mock data, mutated in memory at runtime.
  final List<Need> _needs = List<Need>.from(MockData.needs);

  int _tabIndex = 0;

  /// Bumped whenever a need is posted so [HomeScreen] can reset its filter
  /// and surface the freshly added item at the top of the feed.
  int _postSignal = 0;

  // --------------------------------------------------------------------------
  // Actions
  // --------------------------------------------------------------------------

  Future<void> _openPostNeed() async {
    final created = await Navigator.of(context).push<Need>(
      MaterialPageRoute(builder: (_) => const PostNeedScreen()),
    );
    if (created == null || !mounted) return;

    setState(() {
      _needs.insert(0, created);
      _tabIndex = 0;
      _postSignal++;
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 3),
          content: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text('Your need is live at the top of the feed!'),
              ),
            ],
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
  }

  void _openDetail(Need need) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NeedDetailScreen(need: need)),
    );
  }

  void _onTabSelected(int index) {
    // The center tab is reserved for the FAB action.
    if (index == 2) {
      _openPostNeed();
      return;
    }
    setState(() => _tabIndex = index);
  }

  // --------------------------------------------------------------------------
  // Build
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _GlowingFab(onPressed: _openPostNeed),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          HomeScreen(
            needs: _needs,
            postSignal: _postSignal,
            onOpenDetail: _openDetail,
          ),
          const _PlaceholderTab(
            icon: Icons.explore_rounded,
            title: 'Explore',
            message:
                'Discover trending needs and top providers near you. This tab '
                'is part of the next milestone.',
          ),
          // Index 2 is intercepted by the FAB; never shown.
          const SizedBox.shrink(),
          const _PlaceholderTab(
            icon: Icons.chat_bubble_rounded,
            title: 'Messages',
            message:
                'All your conversations with providers will live here, with '
                'real-time updates and read receipts.',
          ),
          const _PlaceholderTab(
            icon: Icons.person_rounded,
            title: 'Profile',
            message:
                'Manage your account, reviews and saved needs from a single '
                'polished profile hub.',
          ),
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
// Bottom navigation
// ----------------------------------------------------------------------------

/// A custom, notched bottom navigation bar with five slots — the middle slot
/// is left empty to make room for the docked [_GlowingFab].
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
        top: false,
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
              _NavItem(
                icon: Icons.explore_rounded,
                label: 'Explore',
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

// ----------------------------------------------------------------------------
// Placeholder tabs
// ----------------------------------------------------------------------------

/// A graceful empty state used by the secondary tabs so navigation always
/// lands on something polished rather than a blank screen.
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
                style: textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Glowing FAB
// ----------------------------------------------------------------------------

/// A circular FAB with a soft, continuously breathing glow, docked into the
/// notch of the bottom navigation bar.
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
