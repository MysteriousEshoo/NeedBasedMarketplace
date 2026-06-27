import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/need_model.dart';
import '../theme/app_colors.dart';
import '../widgets/pill_tag.dart';

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
    // Corrected data flow logic ensuring real-time posted items render safely
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
            _buildProfessionalHeader(),
            const SizedBox(height: 16),
            _buildCategoryFilterBar(),
            const SizedBox(height: 12),
            Expanded(
              child: filteredNeeds.isEmpty
                  ? _buildCleanEmptyState()
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                      itemCount: filteredNeeds.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final need = filteredNeeds[index];
                        return _buildElevatedMarketplaceCard(need);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Interactive Header with real-time authentication profile binding
  Widget _buildProfessionalHeader() {
    final user = FirebaseAuth.instance.currentUser;
    String currentUserName = 'User';

    if (user != null) {
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        currentUserName = user.displayName!;
      } else if (user.email != null) {
        currentUserName = user.email!.split('@').first;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome back,',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                currentUserName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.notifications_none_rounded,
                  color: AppColors.textPrimary, size: 26),
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }

  /// Clean inline horizontal category selection chips
  Widget _buildCategoryFilterBar() {
    final categories = ['All', ...MockData.categories];
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
              onSelected: (selected) {
                if (selected) setState(() => _selectedCategory = cat);
              },
            ),
          );
        },
      ),
    );
  }

  /// Clean, layered marketplace card UI layout
  Widget _buildElevatedMarketplaceCard(Need need) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => widget.onOpenDetail(need),
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              size: 14, color: AppColors.textTertiary),
                          const SizedBox(width: 4),
                          Text(
                            need.timeElapsed,
                            style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    need.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    need.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.4,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: AppColors.divider),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Budget'.toUpperCase(),
                            style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Rs. ${need.budget}',
                            style: const TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w800,
                                fontSize: 16),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: need.urgency.softColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: need.urgency.color.withValues(alpha: 0.2),
                              width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.local_fire_department_rounded,
                                size: 14, color: need.urgency.color),
                            const SizedBox(width: 4),
                            Text(
                              need.urgency.label,
                              style: TextStyle(
                                  color: need.urgency.color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCleanEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.find_in_page_outlined,
              size: 48, color: AppColors.textTertiary),
          SizedBox(height: 12),
          Text(
            'No active requirements listed yet.',
            style: TextStyle(
                color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
