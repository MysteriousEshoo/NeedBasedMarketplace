import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/need_model.dart' as legacy;
import '../theme/app_colors.dart';
import '../widgets/three_d_glass_card.dart';
import '../widgets/motion.dart';
import '../widgets/pill_tag.dart';
import 'offer_sheet.dart';

class HomeScreen extends StatefulWidget {
  final List<legacy.Need> needs;
  final int postSignal;
  final void Function(legacy.Need need) onOpenDetail;

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

  bool _isSellerMode = false;
  String? _currentUserId;

  final List<String> _localCategories = [
    'All',
    'Mobile Phone',
    'Tech & Development',
    'Local Services',
    'Electronics',
    'Vehicles'
  ];

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _listenToUserRole();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _listenToUserRole() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        if (mounted) {
          setState(() {
            _isSellerMode = data['isSellerMode'] ?? false;
          });
        }
      }
    });
  }

  void _makeOffer(legacy.Need need) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OfferSheet(need: need),
    );
  }

  // ✅ FIXED: Get urgency color
  Color _getUrgencyColor(legacy.Urgency urgency) {
    if (urgency == legacy.Urgency.high) {
      return AppColors.urgentHigh;
    } else if (urgency == legacy.Urgency.medium) {
      return AppColors.urgentMedium;
    } else {
      return AppColors.urgentLow;
    }
  }

  // ✅ FIXED: Get urgency label
  String _getUrgencyLabel(legacy.Urgency urgency) {
    if (urgency == legacy.Urgency.high) {
      return 'High';
    } else if (urgency == legacy.Urgency.medium) {
      return 'Medium';
    } else {
      return 'Low';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color surfaceColor = isDark ? AppColors.surface : Colors.white;
    final Color borderColor =
        isDark ? AppColors.border : const Color(0xFFE2E8F0);
    final Color textPrimary =
        isDark ? AppColors.textPrimary : const Color(0xFF0F172A);
    final Color textSecondary =
        isDark ? AppColors.textSecondary : const Color(0xFF475569);
    final Color textTertiary =
        isDark ? AppColors.textTertiary : const Color(0xFF94A3B8);

    final user = FirebaseAuth.instance.currentUser;
    String userName = 'User';
    if (user != null) {
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        userName = user.displayName!;
      } else if (user.email != null) {
        userName = user.email!.split('@').first;
      }
    }

    final filteredNeeds = widget.needs.where((need) {
      if (!_isSellerMode) {
        final String authorId = need.authorId ?? need.userId ?? '';
        if (authorId != _currentUserId) {
          return false;
        }
      }

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
      backgroundColor: isDark ? AppColors.background : const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          if (isDark) const Positioned.fill(child: FloatingOrbsBackground()),
          SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'WELCOME BACK',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userName,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _isSellerMode
                          ? AppColors.primary.withOpacity(0.15)
                          : AppColors.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _isSellerMode ? '🔵 Seller Mode' : '🟢 Buyer Mode',
                      style: TextStyle(
                        color: _isSellerMode
                            ? AppColors.primary
                            : AppColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Search by keyword, category, or title...',
                    hintStyle: TextStyle(
                      color: textTertiary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppColors.primaryLight,
                      size: 22,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: textTertiary,
                              size: 18,
                            ),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
            ),

            // Category Chips
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _localCategories.length,
                itemBuilder: (context, index) {
                  final cat = _localCategories[index];
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                      backgroundColor: surfaceColor,
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : borderColor,
                      ),
                      onSelected: (bool selected) {
                        setState(
                            () => _selectedCategory = selected ? cat : 'All');
                      },
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Need List
            Expanded(
              child: filteredNeeds.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isSellerMode
                                ? Icons.search_off_rounded
                                : Icons.hourglass_empty_rounded,
                            size: 48,
                            color: textTertiary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _isSellerMode
                                ? 'No needs available'
                                : 'You haven\'t posted any needs yet',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isSellerMode
                                ? 'Check back later for new requests'
                                : 'Tap + to post your first need',
                            style: TextStyle(
                              color: textTertiary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredNeeds.length,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemBuilder: (context, index) {
                        final need = filteredNeeds[index];
                        return EntranceMotion(
                          delay: Duration(milliseconds: (index * 70).clamp(0, 500)),
                          child: _buildModernNeedCard(need),
                        );
                      },
                    ),
            ),
          ],
        ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ✅ NEED CARD - FIXED
  // ============================================================
  Widget _buildModernNeedCard(legacy.Need need) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardTextPrimary =
        isDark ? AppColors.textPrimary : const Color(0xFF0F172A);
    final Color cardTextSecondary =
        isDark ? AppColors.textSecondary : const Color(0xFF475569);
    final Color cardTextTertiary =
        isDark ? AppColors.textTertiary : const Color(0xFF94A3B8);
    final Color cardDivider =
        isDark ? AppColors.border : const Color(0xFFE2E8F0);

    return ThreeDGlassCard(
      glowColor: _getUrgencyColor(need.urgency),
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
                  Icon(
                    Icons.radar_rounded,
                    size: 14,
                    color: cardTextTertiary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    need.timeElapsed,
                    style: TextStyle(
                      color: cardTextSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
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
              color: cardTextPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            need.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cardTextSecondary,
              height: 1.5,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 18),
          Container(height: 1.2, color: cardDivider),
          const SizedBox(height: 16),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VALUATION METRIC',
                    style: TextStyle(
                      color: cardTextTertiary,
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
                  color: _getUrgencyColor(need.urgency).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        _getUrgencyColor(need.urgency).withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      size: 16,
                      color: _getUrgencyColor(need.urgency),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getUrgencyLabel(need.urgency).toUpperCase(),
                      style: TextStyle(
                        color: _getUrgencyColor(need.urgency),
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isSellerMode) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _makeOffer(need),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.handshake_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Offer',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
