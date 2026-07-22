import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/need_model.dart';
import '../models/need_model.dart' as legacy;
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../widgets/three_d_glass_card.dart';
import '../widgets/motion.dart';
import '../widgets/pill_tag.dart';
import 'offer_sheet.dart';
import 'verify_email_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<legacy.Need> needs;
  final int postSignal;
  final void Function(legacy.Need need) onOpenDetail;

  /// Role is owned by [MainShell] (single source of truth) and passed down so
  /// the greeting badge here and the post FAB in the shell can never disagree.
  final bool isSellerMode;

  const HomeScreen({
    super.key,
    required this.needs,
    required this.postSignal,
    required this.onOpenDetail,
    required this.isSellerMode,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _currentUserId;

  // Live profile bits for the greeting header.
  String _displayName = 'User';
  String? _photoUrl;
  bool _emailVerified = true;

  /// Categories for the filter chips — loaded from [MockData] which pulls
  /// from Firebase [AppConfigService] with hardcoded defaults as fallback.
  List<String> get _filterChips => ['All', ...MockData.categories];

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _initUserBasics();
    _listenToProfile();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initUserBasics() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _displayName = _deriveName(user);
    if (user.photoURL != null && user.photoURL!.isNotEmpty) {
      _photoUrl = user.photoURL;
    }
    // Nothing to verify for phone-only accounts; treat those as fine.
    _emailVerified = user.emailVerified || (user.email == null);
  }

  String _deriveName(User user) {
    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      return user.displayName!.trim();
    }
    if (user.email != null && user.email!.isNotEmpty) {
      return user.email!.split('@').first;
    }
    return 'User';
  }

  /// Keeps the greeting name + avatar in sync with the live profile record so
  /// edits made on the Profile screen show up here immediately.
  void _listenToProfile() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseDatabase.instance
        .ref()
        .child('users')
        .child(user.uid)
        .onValue
        .listen((event) {
      final value = event.snapshot.value;
      if (value is! Map || !mounted) return;
      final data = Map<String, dynamic>.from(value);
      final name = _firstNonEmpty(data, ['name', 'displayName']);
      final photo = _firstNonEmpty(data, ['photoUrl', 'photoURL']);
      setState(() {
        if (name != null) _displayName = name;
        if (photo != null) _photoUrl = photo;
      });
    });
  }

  String? _firstNonEmpty(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  Future<void> _openEmailVerification() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
    );
    // Re-read the freshest auth state whichever way the screen was closed.
    try {
      await FirebaseAuth.instance.currentUser?.reload();
    } catch (_) {}
    final user = FirebaseAuth.instance.currentUser;
    if (!mounted) return;
    setState(() {
      _emailVerified =
          (result == true) || (user?.emailVerified ?? false) || (user?.email == null);
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

  // Delete a single need from Firebase RTDB
  Future<void> _deleteNeed(legacy.Need need) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Need?'),
        content: Text('Are you sure you want to delete "${need.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.urgentHigh,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await FirebaseDatabase.instance
          .ref()
          .child('needs')
          .child(need.id)
          .remove();
      // Also remove associated offers
      await FirebaseDatabase.instance
          .ref()
          .child('offers')
          .child(need.id)
          .remove();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Need deleted successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting need: $e'),
            backgroundColor: AppColors.urgentHigh,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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

    final String userName = _displayName;

    final filteredNeeds = widget.needs.where((need) {
      if (!widget.isSellerMode) {
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
            // Header — avatar + greeting
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildHeaderAvatar(surfaceColor),
                  const SizedBox(width: 14),
                  Expanded(
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
                          'Hello, $userName 👋',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: widget.isSellerMode
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.isSellerMode ? '🔵 Seller Mode' : '🟢 Buyer Mode',
                            style: TextStyle(
                              color: widget.isSellerMode
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
                ],
              ),
            ),

            // Trust banner — asks the user to verify their email.
            if (!_emailVerified) _buildVerifyBanner(),

            // Everything below the greeting scrolls together (search, filter
            // chips and the needs feed) with an always-visible scrollbar so
            // the user can see how far they've scrolled and how much remains.
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                trackVisibility: true,
                interactive: true,
                thickness: 5,
                radius: const Radius.circular(8),
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    // Search Bar
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: TextStyle(color: textPrimary, fontSize: 15),
                            decoration: InputDecoration(
                              hintText:
                                  'Search by keyword, category, or title...',
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
                            onChanged: (val) =>
                                setState(() => _searchQuery = val),
                          ),
                        ),
                      ),
                    ),

                    // Category Chips
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: SizedBox(
                          height: 44,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filterChips.length,
                            itemBuilder: (context, index) {
                              final cat = _filterChips[index];
                              final isSelected = _selectedCategory == cat;
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: ChoiceChip(
                                  label: Text(cat),
                                  selected: isSelected,
                                  selectedColor: AppColors.primary,
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : textSecondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  backgroundColor: surfaceColor,
                                  side: BorderSide(
                                    color: isSelected
                                        ? AppColors.primary
                                        : borderColor,
                                  ),
                                  onSelected: (bool selected) {
                                    setState(() => _selectedCategory =
                                        selected ? cat : 'All');
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 16)),

                    // Need List
                    if (filteredNeeds.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                widget.isSellerMode
                                    ? Icons.search_off_rounded
                                    : Icons.hourglass_empty_rounded,
                                size: 48,
                                color: textTertiary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.isSellerMode
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
                                widget.isSellerMode
                                    ? 'Check back later for new requests'
                                    : 'Tap + to post your first need',
                                style: TextStyle(
                                  color: textTertiary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList.builder(
                          itemCount: filteredNeeds.length,
                          itemBuilder: (context, index) {
                            final need = filteredNeeds[index];
                            return EntranceMotion(
                              delay: Duration(
                                  milliseconds: (index * 70).clamp(0, 500)),
                              child: _buildModernNeedCard(need),
                            );
                          },
                        ),
                      ),

                    // Breathing room so the last card clears the bottom nav.
                    const SliverToBoxAdapter(child: SizedBox(height: 90)),
                  ],
                ),
              ),
            ),
          ],
        ),
          ),
        ],
      ),
    );
  }

  // Profile picture shown next to the greeting. Falls back to the first
  // letter of the name, then a person icon, when no photo is available.
  Widget _buildHeaderAvatar(Color surfaceColor) {
    final bool hasPhoto = _photoUrl != null && _photoUrl!.isNotEmpty;
    final String initial =
        _displayName.trim().isNotEmpty ? _displayName.trim()[0].toUpperCase() : '';

    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: CircleAvatar(
        radius: 26,
        backgroundColor: surfaceColor,
        backgroundImage: hasPhoto ? NetworkImage(_photoUrl!) : null,
        child: hasPhoto
            ? null
            : (initial.isNotEmpty
                ? Text(
                    initial,
                    style: const TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : const Icon(Icons.person_rounded,
                    color: AppColors.primaryLight, size: 26)),
      ),
    );
  }

  // "Verify your email" trust prompt shown until the account is verified.
  Widget _buildVerifyBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _openEmailVerification,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.urgentMedium.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.urgentMedium.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.urgentMedium.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.gpp_maybe_rounded,
                      color: AppColors.urgentMedium, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Verify your email',
                        style: TextStyle(
                          color: AppColors.urgentMedium,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Confirm your email to build trust with buyers & sellers.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: AppColors.urgentMedium, size: 14),
              ],
            ),
          ),
        ),
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
              if (widget.isSellerMode) ...[
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
              // Delete button for buyer mode (own needs only)
              if (!widget.isSellerMode && (need.authorId == _currentUserId || need.userId == _currentUserId)) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _deleteNeed(need),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.urgentHigh.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.urgentHigh.withValues(alpha: 0.3),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: const [
                        Icon(
                          Icons.delete_rounded,
                          size: 14,
                          color: AppColors.urgentHigh,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Delete',
                          style: TextStyle(
                            color: AppColors.urgentHigh,
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
