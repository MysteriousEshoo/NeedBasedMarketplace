import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/need_model.dart';
import '../theme/app_colors.dart';
import '../widgets/pill_tag.dart';
import '../widgets/three_d_glass_card.dart';

class HomeScreen extends StatefulWidget {
  final List<Need> needs;
  final int postSignal;
  final void Function(Need need) onOpenDetail;

  const HomeScreen({
    super.key,
    required this.needs,
    required this.postSignal,
    required this.onOpenDetail,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final filteredNeeds = _selectedCategory == 'All'
        ? widget.needs
        : widget.needs.where((n) => n.category == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCyberpunkHeader(),
            const SizedBox(height: 20),
            _buildFuturisticSliderChips(),
            const SizedBox(height: 16),
            Expanded(
              child: filteredNeeds.isEmpty
                  ? _buildCyberpunkEmptyState()
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                      itemCount: filteredNeeds.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 24),
                      itemBuilder: (context, index) {
                        final need = filteredNeeds[index];
                        return _build3DMarketplaceItem(need);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCyberpunkHeader() {
    final user = FirebaseAuth.instance.currentUser;
    String currentUserName = 'User Core';

    if (user != null) {
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        currentUserName = user.displayName!;
      } else if (user.email != null) {
        currentUserName = user.email!.split('@').first;
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.surface, Color(0xFF141C30)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SYSTEM USER ACTIVE',
                  style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5),
                ),
                const SizedBox(height: 6),
                Text(
                  currentUserName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10, width: 1),
            ),
            child: IconButton(
              icon: const Icon(Icons.blur_on_rounded,
                  color: AppColors.primaryLight, size: 24),
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFuturisticSliderChips() {
    final categories = ['All', ...MockData.categories];
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.surface,
              side: BorderSide(
                color: isSelected ? AppColors.primaryLight : AppColors.border,
                width: 1.2,
              ),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              onSelected: (selected) {
                if (selected) setState(() => _selectedCategory = cat);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _build3DMarketplaceItem(Need need) {
    return ThreeDGlassCard(
      glowColor: need.urgency.color,
      onTap: () => widget.onOpenDetail(need),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PillTag(
                label: need.category.toUpperCase(),
                foreground: AppColors.accent,
                background: AppColors.accent.withValues(alpha: 0.1),
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.radar_rounded,
                      size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 6),
                  Text(
                    need.timeElapsed,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            need.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            need.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: AppColors.textSecondary, height: 1.5, fontSize: 14),
          ),
          const SizedBox(height: 18),
          Container(height: 1.2, color: AppColors.border),
          const SizedBox(height: 16),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'VALUATION METRIC',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rs. ${need.budget}',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const Spacer(), // <-- Is par se bhi const bilkul clear hai
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: need.urgency.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: need.urgency.color.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bolt_rounded,
                        size: 16, color: need.urgency.color),
                    const SizedBox(width: 4),
                    Text(
                      need.urgency.label.toUpperCase(),
                      style: TextStyle(
                        color: need.urgency.color,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCyberpunkEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.filter_hdr_outlined,
                size: 44, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 16),
          const Text(
            'GRID VACANT',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}
