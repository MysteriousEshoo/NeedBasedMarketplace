import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/need_model.dart';
import '../theme/app_colors.dart';
import '../widgets/pill_tag.dart';

/// Screen 2 — Buyer/Provider home dashboard with a dynamic, filterable feed.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.needs,
    required this.postSignal,
    required this.onOpenDetail,
  });

  /// The full, up-to-date feed provided by the parent shell.
  final List<Need> needs;

  /// Increments whenever a new need is posted, used to reset the filter so
  /// the freshly added item is guaranteed to be visible.
  final int postSignal;

  /// Opens the detail screen for a tapped need.
  final void Function(Need need) onOpenDetail;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedFilter = 0;
  String _searchQuery = ''; // FIXED: Added query string to track search input
  final _searchController =
      TextEditingController(); // FIXED: Controller for clear button

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A need was just posted — snap back to "Trending" so it shows on top.
    if (widget.postSignal != oldWidget.postSignal && _selectedFilter != 0) {
      setState(() {
        _selectedFilter = 0;
        _searchQuery = '';
        _searchController.clear();
      });
    }
  }

  /// Maps a filter chip label to its corresponding icon.
  IconData _getChipIcon(String chipLabel) {
    switch (chipLabel) {
      case 'Trending':
        return Icons.local_fire_department_rounded;
      case 'Urgent':
        return Icons.bolt_rounded;
      case 'Tech':
        return Icons.code_rounded;
      case 'Tutoring':
        return Icons.school_rounded;
      case 'Services':
        return Icons.handshake_rounded;
      case 'Repairs':
        return Icons.build_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  /// FIXED: The feed now filters through BOTH active category chips AND the search bar input!
  List<Need> get _filteredNeeds {
    final chip = MockData.filterChips[_selectedFilter];
    List<Need> activeList = widget.needs;

    // 1. First step: Filter by category chip selection
    if (chip == 'Urgent') {
      activeList =
          widget.needs.where((n) => n.urgency == Urgency.high).toList();
    } else if (chip != 'Trending') {
      final keyword = chip.toLowerCase().split(' ').first;
      activeList = widget.needs
          .where((n) => n.category.toLowerCase().contains(keyword))
          .toList();
    }

    // 2. Second step: Apply live text search matching title or description
    if (_searchQuery.isNotEmpty) {
      activeList = activeList.where((n) {
        final titleMatch =
            n.title.toLowerCase().contains(_searchQuery.toLowerCase());
        final descMatch =
            n.description.toLowerCase().contains(_searchQuery.toLowerCase());
        return titleMatch || descMatch;
      }).toList();
    }

    return activeList;
  }

  // --------------------------------------------------------------------------
  // Interactions
  // --------------------------------------------------------------------------

  void _showSnack(String message, {IconData icon = Icons.info_rounded}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.textPrimary,
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
  }

  void _openNotifications() {
    showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Notifications',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (context, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return Transform.scale(
          scale: 0.92 + curved.value * 0.08,
          child: Opacity(
            opacity: anim.value.clamp(0.0, 1.0),
            child: const _NotificationsPanel(),
          ),
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // Build
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildTopBar()),
          SliverToBoxAdapter(child: _buildGreeting()),
          SliverToBoxAdapter(child: _buildFilterChips()),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          _buildSectionHeader(),
          _buildFeed(),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
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
          // FIXED: Tapping avatar acts as a quick shortcut info hint now
          GestureDetector(
            onTap: () =>
                _showSnack('Profile tab is located at the bottom menu!'),
            child: Container(
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
          ),
          const Spacer(),
          _buildIconButton(
            Icons.tune_rounded,
            onTap: () => _showSnack(
              'Advanced filters are coming soon.',
              icon: Icons.tune_rounded,
            ),
          ),
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
        _buildIconButton(
          Icons.notifications_none_rounded,
          onTap: _openNotifications,
        ),
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
          const SizedBox(height: 16),
          _buildSearchBar(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          setState(() {
            _searchQuery = val.trim();
          });
        },
        decoration: InputDecoration(
          hintText: 'Search for requirements, skills, or tasks...',
          hintStyle: const TextStyle(
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 14, right: 10),
            child: Icon(
              Icons.search_rounded,
              color: AppColors.textSecondary,
              size: 22,
            ),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: AppColors.textSecondary),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          prefixIconConstraints: const BoxConstraints(minHeight: 48),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppColors.primary,
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.fromLTRB(0, 14, 16, 14),
        ),
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
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
          final chipLabel = MockData.filterChips[index];
          final chipIcon = _getChipIcon(chipLabel);
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14),
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    chipIcon,
                    size: 18,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    chipLabel,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader() {
    final count = _filteredNeeds.length;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Active Needs ($count)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            GestureDetector(
              onTap: () => _showSnack('Showing all active needs.'),
              child: const Text(
                'See all',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeed() {
    // Live database pipeline stream setup
    final Query dbQuery = FirebaseDatabase.instance.ref().child('needs');

    return StreamBuilder(
      stream: dbQuery.onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        // 1. Loading state jab tak internet se data nahi aata
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        List<Need> liveNeeds = [];

        // 2. Agar database mien data maujood hai
        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final Map<dynamic, dynamic> map =
              snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

          map.forEach((key, value) {
            final data = Map<String, dynamic>.from(value as Map);

            // Firebase ke raw data map ko hum Need model ki shakl mien dhalte hain
            liveNeeds.add(
              Need(
                id: key, // Unique Key generated by Firebase .push()
                title: data['title'] ?? '',
                description: data['description'] ?? '',
                category: data['category'] ?? '',
                budget: data['budget'] ?? 0,
                timeElapsed:
                    'Just now', // Baad mien is mien date format fit karenge
                urgency: data['urgency'] == 'high'
                    ? Urgency.high
                    : (data['urgency'] == 'low' ? Urgency.low : Urgency.medium),
                authorName: data['authorName'] ?? 'Anonymous',
                offers: data['offers'] ?? 0,
              ),
            );
          });

          // Naye nodes ko hamesha list mien sab se upar dikhane ke liye reverse chronologically manage kiya
          liveNeeds = liveNeeds.reversed.toList();
        }

        // 3. Filtering logic ko live data par apply karna
        final chip = MockData.filterChips[_selectedFilter];
        List<Need> activeList = liveNeeds;

        // Filter by category chip selection
        if (chip == 'Urgent') {
          activeList =
              liveNeeds.where((n) => n.urgency == Urgency.high).toList();
        } else if (chip != 'Trending') {
          final keyword = chip.toLowerCase().split(' ').first;
          activeList = liveNeeds
              .where((n) => n.category.toLowerCase().contains(keyword))
              .toList();
        }

        // Filter by live text search query
        if (_searchQuery.isNotEmpty) {
          activeList = activeList.where((n) {
            final titleMatch =
                n.title.toLowerCase().contains(_searchQuery.toLowerCase());
            final descMatch = n.description
                .toLowerCase()
                .contains(_searchQuery.toLowerCase());
            return titleMatch || descMatch;
          }).toList();
        }

        // 4. Agar filters ke baad koi result na mile
        if (activeList.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
              child: Column(
                children: [
                  Container(
                    height: 84,
                    width: 84,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      Icons.search_off_rounded,
                      size: 38,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('No matching results found',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    'Try another search keyword or adjust your category filter.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        // 5. Live cards list show karna
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.separated(
            itemCount: activeList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final need = activeList[index];
              return _NeedCard(
                key: ValueKey(need.id),
                need: need,
                onTap: () => widget.onOpenDetail(need),
              );
            },
          ),
        );
      },
    );
  }
}

// ----------------------------------------------------------------------------
// Need card
// ----------------------------------------------------------------------------

class _NeedCard extends StatelessWidget {
  const _NeedCard({super.key, required this.need, required this.onTap});

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
// Notifications panel
// ----------------------------------------------------------------------------

class _NotificationItem {
  const _NotificationItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.time,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String time;
}

class _NotificationsPanel extends StatelessWidget {
  const _NotificationsPanel();

  static const _items = <_NotificationItem>[
    _NotificationItem(
      icon: Icons.local_offer_rounded,
      color: AppColors.accent,
      title: 'New offer received',
      body: 'A provider offered PKR 78,000 on your Flutter MVP need.',
      time: '2m ago',
    ),
    _NotificationItem(
      icon: Icons.bolt_rounded,
      color: AppColors.urgentHigh,
      title: 'Your need is trending',
      body: 'Your AC repair request is in the top 5 today.',
      time: '40m ago',
    ),
    _NotificationItem(
      icon: Icons.verified_rounded,
      color: AppColors.primary,
      title: 'Profile verified',
      body: 'Your account has been verified. You now rank higher.',
      time: '3h ago',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Notifications', style: textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ..._items.map(
              (n) => Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: n.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(n.icon, color: n.color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  n.title,
                                  style: textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Text(
                                n.time,
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            n.body,
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
