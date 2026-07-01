import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/need_model.dart';
import '../theme/app_colors.dart';
import '../providers/theme_provider.dart';
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
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Theme-aware colors
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDark = themeProvider.isDarkMode;

    final Color bg = isDark ? AppColors.background : const Color(0xFFF1F5F9);
    final Color surface = isDark ? AppColors.surface : Colors.white;
    final Color border = isDark ? AppColors.border : const Color(0xFFE2E8F0);
    final Color textPrimary =
        isDark ? AppColors.textPrimary : const Color(0xFF0F172A);
    final Color textSecondary =
        isDark ? AppColors.textSecondary : const Color(0xFF475569);
    final Color textTertiary =
        isDark ? AppColors.textTertiary : const Color(0xFF94A3B8);

    final filteredNeeds = widget.needs.where((need) {
      final matchesCategory =
          _selectedCategory == 'All' || need.category == _selectedCategory;
      final matchesSearch = need.title
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          need.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          need.category.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(textPrimary: textPrimary),
              _buildSearchBar(
                  surface: surface,
                  border: border,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  textTertiary: textTertiary,
                  isDark: isDark),
              const SizedBox(height: 12),
              _buildCategoryChips(surface: surface, border: border),
              const SizedBox(height: 16),
              Expanded(
                child: filteredNeeds.isEmpty
                    ? _buildEmptyState(
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        surface: surface,
                        border: border)
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                        itemCount: filteredNeeds.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 24),
                        itemBuilder: (context, index) {
                          final need = filteredNeeds[index];
                          return _buildNeedCard(need, surface, border,
                              textPrimary, textSecondary, textTertiary);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({required Color textPrimary}) {
    final user = FirebaseAuth.instance.currentUser;
    String currentUserName = 'User Core';
    if (user != null) {
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        currentUserName = user.displayName!;
      } else if (user.email != null) {
        currentUserName = user.email!.split('@').first;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Column(
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
              const SizedBox(height: 4),
              Text(
                currentUserName,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              final bool isDark = themeProvider.isDarkMode;
              return Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color:
                      isDark ? AppColors.surfaceMuted : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: isDark ? Colors.white10 : const Color(0xFFCBD5E1),
                      width: 1),
                ),
                child: IconButton(
                  icon: const Icon(Icons.blur_on_rounded,
                      color: AppColors.primaryLight, size: 24),
                  onPressed: () {},
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar({
    required Color surface,
    required Color border,
    required Color textPrimary,
    required Color textSecondary,
    required Color textTertiary,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0xFFE2E8F0),
            width: 1.2),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black45 : Colors.black12,
            blurRadius: 12,
            offset: const Offset(-4, 6),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(
            color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
        cursorColor: AppColors.primaryLight,
        decoration: InputDecoration(
          hintText: 'Search needs by keyword, type, title...',
          hintStyle: TextStyle(
              color: textTertiary, fontSize: 14, fontWeight: FontWeight.w500),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppColors.primaryLight, size: 22),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon:
                      Icon(Icons.close_rounded, color: textSecondary, size: 18),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : Icon(Icons.tune_rounded, color: textTertiary, size: 18),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildCategoryChips({required Color surface, required Color border}) {
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
              backgroundColor: surface,
              side: BorderSide(
                color: isSelected ? AppColors.primaryLight : border,
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

  Widget _buildNeedCard(Need need, Color surface, Color border,
      Color textPrimary, Color textSecondary, Color textTertiary) {
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
                    style: TextStyle(
                        color: textSecondary,
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
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            need.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: textSecondary, height: 1.5, fontSize: 14),
          ),
          const SizedBox(height: 18),
          Container(height: 1.2, color: border),
          const SizedBox(height: 16),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VALUATION METRIC',
                    style: TextStyle(
                      color: textTertiary,
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
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: need.urgency.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: need.urgency.color.withValues(alpha: 0.3),
                      width: 1.5),
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
                          letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required Color textPrimary,
    required Color textSecondary,
    required Color surface,
    required Color border,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surface,
              shape: BoxShape.circle,
              border: Border.all(color: border),
            ),
            child: const Icon(Icons.filter_hdr_outlined,
                size: 44, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 16),
          Text(
            'NO MATCHES FOUND',
            style: TextStyle(
                color: textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          Text(
            'Try refining your active search string.',
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
