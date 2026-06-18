import 'package:flutter/material.dart';

import '../models/need_model.dart';
import '../theme/app_colors.dart';
import '../widgets/pill_tag.dart';
import 'need_detail_screen.dart';
import 'post_need_screen.dart';

/// Screen 2 — Buyer/Provider home dashboard with a dynamic needs feed.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedFilter = 0;

  void _openPostNeed() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PostNeedScreen()),
    );
  }

  void _openDetail(Need need) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NeedDetailScreen(need: need)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _GlowingFab(onPressed: _openPostNeed),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildTopBar()),
            SliverToBoxAdapter(child: _buildGreeting()),
            SliverToBoxAdapter(child: _buildFilterChips()),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            _buildSectionHeader(),
            _buildFeed(),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Sections
  // --------------------------------------------------------------------------

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.accent, AppColors.accentLight],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              'AK',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          const Spacer(),
          _buildIconButton(Icons.tune_rounded, onTap: () {}),
          const SizedBox(width: 12),
          _buildNotificationButton(),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, {required VoidCallback onTap}) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(icon, size: 22, color: AppColors.textPrimary),
        ),
      ),
    );
  }

  Widget _buildNotificationButton() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _buildIconButton(Icons.notifications_none_rounded, onTap: () {}),
        Positioned(
          right: 6,
          top: 6,
          child: Container(
            height: 18,
            width: 18,
            decoration: BoxDecoration(
              color: AppColors.urgentHigh,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.background, width: 2),
            ),
            alignment: Alignment.center,
            child: const Text(
              '3',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGreeting() {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assalam-o-Alaikum, Ayesha',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'What do you need today?',
            style: textTheme.headlineMedium?.copyWith(fontSize: 26),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: MockData.filterChips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final selected = index == _selectedFilter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                MockData.filterChips[index],
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Active Needs',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              'See all',
              style: TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeed() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList.separated(
        itemCount: MockData.needs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) => _NeedCard(
          need: MockData.needs[index],
          onTap: () => _openDetail(MockData.needs[index]),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Need card
// ----------------------------------------------------------------------------

/// A premium card representing a single need in the feed.
class _NeedCard extends StatelessWidget {
  const _NeedCard({required this.need, required this.onTap});

  final Need need;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PillTag(
                    label: need.category,
                    foreground: AppColors.accent,
                    background: AppColors.accent.withValues(alpha: 0.08),
                  ),
                  const Spacer(),
                  Text(
                    need.timeElapsed,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                need.title,
                style: textTheme.titleMedium?.copyWith(
                  fontSize: 17,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                need.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 14),
              Row(
                children: [
                  PillTag(
                    label: need.formattedBudget,
                    icon: Icons.account_balance_wallet_rounded,
                    foreground: AppColors.budgetTag,
                    background: AppColors.budgetTagSoft,
                  ),
                  const SizedBox(width: 8),
                  PillTag(
                    label: need.urgency.label,
                    icon: Icons.local_fire_department_rounded,
                    foreground: need.urgency.color,
                    background: need.urgency.softColor,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(Icons.bookmark_border_rounded,
                          size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${need.offers}',
                        style: textTheme.labelLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
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
// Glowing FAB
// ----------------------------------------------------------------------------

/// An extended FAB with a soft, continuously breathing glow.
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
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.45),
                blurRadius: glow,
                spreadRadius: _controller.value * 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        );
      },
      child: FloatingActionButton.extended(
        onPressed: widget.onPressed,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        icon: const Icon(Icons.add_rounded, size: 24),
        label: const Text(
          'Post a Need',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    );
  }
}
