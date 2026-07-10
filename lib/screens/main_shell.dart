import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../models/need_model.dart' as legacy;
import '../theme/app_colors.dart';
import '../providers/theme_provider.dart';
import '../services/notification_service.dart';
import 'home_screen.dart';
import 'need_detail_screen.dart';
import 'post_need_screen.dart';
import 'profile_screen.dart';
import 'seller_dashboard_feed.dart';
import 'inbox_screen.dart';
import 'notification_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tabIndex = 0;
  int _postSignal = 0;
  bool _isSellerModeActive = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _listenToUserRole();
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
            _isSellerModeActive = data['isSellerMode'] ?? false;
          });
        }
      }
    });
  }

  String _convertToTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    try {
      int millis = 0;
      if (timestamp is int) {
        millis = timestamp;
      } else if (timestamp is Map && timestamp['.sv'] != null) {
        return 'Just now';
      } else {
        return 'Just now';
      }
      final postDate = DateTime.fromMillisecondsSinceEpoch(millis);
      final currentDate = DateTime.now();
      final difference = currentDate.difference(postDate);
      if (difference.inSeconds < 60) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes} mins ago';
      if (difference.inHours < 24) return '${difference.inHours} hours ago';
      if (difference.inDays < 7) return '${difference.inDays} days ago';
      if (difference.inDays < 30) {
        int weeks = (difference.inDays / 7).floor();
        return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
      }
      return '${postDate.day}/${postDate.month}/${postDate.year}';
    } catch (e) {
      return 'Just now';
    }
  }

  Future<void> _openPostNeed() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PostNeedScreen()),
    );
    setState(() {
      _postSignal++;
    });
  }

  void _openDetail(legacy.Need need) {
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final Color surface = isDark ? AppColors.surface : Colors.white;

    return Scaffold(
      extendBody: true,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton:
          _isSellerModeActive ? null : _GlowingFab(onPressed: _openPostNeed),
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        title: const Text('NeedHub'),
        actions: [
          if (_currentUserId != null)
            StreamBuilder<int>(
              stream: NotificationService().getUnreadCount(_currentUserId!),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none_rounded),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationScreen(),
                          ),
                        );
                      },
                    ),
                    if (count > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            count > 9 ? '9+' : '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
      body: StreamBuilder(
        stream: FirebaseDatabase.instance.ref().child('needs').onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          List<legacy.Need> liveNeeds = [];

          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            final Map<dynamic, dynamic> allMap =
                snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
            allMap.forEach((key, value) {
              final data = Map<String, dynamic>.from(value as Map);
              legacy.Urgency dynamicUrgency = legacy.Urgency.medium;
              if (data['urgency'] == 'high') {
                dynamicUrgency = legacy.Urgency.high;
              } else if (data['urgency'] == 'low') {
                dynamicUrgency = legacy.Urgency.low;
              }
              final dynamicTimeText = _convertToTimeAgo(data['timestamp']);
              liveNeeds.add(legacy.Need(
                id: key,
                title: data['title'] ?? 'Untitled',
                description: data['description'] ?? '',
                category: data['category'] ?? 'General',
                budget: data['budget'] ?? 0,
                timeElapsed: dynamicTimeText,
                urgency: dynamicUrgency,
                authorName: data['authorName'] ?? 'Anonymous',
                offers: data['offers'] ?? 0,
                companyName: data['company'],
                condition: data['condition'] == null
                    ? null
                    : (data['condition'] == 'Used'
                        ? legacy.ProductCondition.used
                        : legacy.ProductCondition.new_),
                paymentMethod: data['paymentMethod'] == null
                    ? null
                    : (data['paymentMethod'] == 'Online Deposit'
                        ? legacy.PaymentMethod.onlineDeposit
                        : legacy.PaymentMethod.cash),
                location: data['location'],
                authorId: data['authorId'] ?? data['userId'],
                userId: data['userId'],
                userName: data['userName'],
                isPremium: data['isPremium'] ?? false,
              ));
            });
            liveNeeds = liveNeeds.reversed.toList();
          }

          return IndexedStack(
            index: _tabIndex,
            children: [
              snapshot.connectionState == ConnectionState.waiting
                  ? const Center(child: CircularProgressIndicator())
                  : _isSellerModeActive
                      ? const SellerDashboardFeed()
                      : HomeScreen(
                          needs: liveNeeds,
                          postSignal: _postSignal,
                          onOpenDetail: _openDetail,
                        ),
              _SavedNeedsTab(onOpenDetail: _openDetail),
              const SizedBox.shrink(),
              const InboxScreen(),
              const ProfileScreen(),
            ],
          );
        },
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _tabIndex,
        onTap: _onTabSelected,
      ),
    );
  }
}

class _SavedNeedsTab extends StatelessWidget {
  final void Function(legacy.Need need) onOpenDetail;
  const _SavedNeedsTab({required this.onOpenDetail});

  String _convertToTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    try {
      if (timestamp is! int) return 'Just now';
      final postDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final difference = DateTime.now().difference(postDate);
      if (difference.inSeconds < 60) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes} mins ago';
      if (difference.inHours < 24) return '${difference.inHours} hours ago';
      if (difference.inDays < 7) return '${difference.inDays} days ago';
      if (difference.inDays < 30) {
        return '${(difference.inDays / 7).floor()} weeks ago';
      }
      return '${postDate.day}/${postDate.month}/${postDate.year}';
    } catch (_) {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDark = themeProvider.isDarkMode;
    final Color bg = isDark ? AppColors.background : const Color(0xFFF1F5F9);
    final Color surface = isDark ? AppColors.surface : Colors.white;
    final Color textPrimary =
        isDark ? AppColors.textPrimary : const Color(0xFF0F172A);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please login to view saved needs'));
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        title: Text('Saved Needs', style: TextStyle(color: textPrimary)),
        iconTheme: IconThemeData(color: textPrimary),
        centerTitle: true,
      ),
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

          return StreamBuilder(
            stream: FirebaseDatabase.instance.ref().child('needs').onValue,
            builder: (context, AsyncSnapshot<DatabaseEvent> needsSnapshot) {
              if (needsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              List<legacy.Need> bookmarkedNeeds = [];
              if (needsSnapshot.hasData &&
                  needsSnapshot.data!.snapshot.value != null) {
                final Map<dynamic, dynamic> allMap =
                    needsSnapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                allMap.forEach((key, value) {
                  if (savedIds.contains(key)) {
                    final data = Map<String, dynamic>.from(value as Map);
                    legacy.Urgency dynamicUrgency = legacy.Urgency.medium;
                    if (data['urgency'] == 'high') {
                      dynamicUrgency = legacy.Urgency.high;
                    }
                    if (data['urgency'] == 'low') {
                      dynamicUrgency = legacy.Urgency.low;
                    }
                    bookmarkedNeeds.add(legacy.Need(
                      id: key,
                      title: data['title'] ?? '',
                      description: data['description'] ?? '',
                      category: data['category'] ?? '',
                      budget: data['budget'] ?? 0,
                      timeElapsed: _convertToTimeAgo(data['timestamp']),
                      urgency: dynamicUrgency,
                      authorName: data['authorName'] ?? 'Anonymous',
                      offers: data['offers'] ?? 0,
                      companyName: data['company'],
                      condition: data['condition'] == null
                          ? null
                          : (data['condition'] == 'Used'
                              ? legacy.ProductCondition.used
                              : legacy.ProductCondition.new_),
                      paymentMethod: data['paymentMethod'] == null
                          ? null
                          : (data['paymentMethod'] == 'Online Deposit'
                              ? legacy.PaymentMethod.onlineDeposit
                              : legacy.PaymentMethod.cash),
                      location: data['location'],
                      authorId: data['authorId'] ?? data['userId'],
                      userId: data['userId'] ?? data['authorId'],
                      userName: data['userName'] ?? data['authorName'],
                      isPremium: data['isPremium'] ?? false,
                    ));
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

class HomeScreenCardViewPlaceholder extends StatelessWidget {
  final legacy.Need need;
  final void Function(legacy.Need need) onOpenDetail;
  const HomeScreenCardViewPlaceholder(
      {super.key, required this.need, required this.onOpenDetail});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDark = themeProvider.isDarkMode;
    final Color surface = isDark ? AppColors.surface : Colors.white;
    final Color border = isDark ? AppColors.border : const Color(0xFFE2E8F0);
    final Color textPrimary =
        isDark ? AppColors.textPrimary : const Color(0xFF0F172A);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        onTap: () => onOpenDetail(need),
        title: Text(
          need.title,
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary),
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

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex, required this.onTap});
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDark = themeProvider.isDarkMode;
    final Color navBg = isDark ? AppColors.surface : Colors.white;
    final Color navBorder =
        isDark ? AppColors.divider : const Color(0xFFE2E8F0);
    final Color navShadow = isDark ? AppColors.shadow : Colors.black12;

    return Container(
      decoration: BoxDecoration(
        color: navBg,
        border: Border(top: BorderSide(color: navBorder)),
        boxShadow: [
          BoxShadow(
              color: navShadow, blurRadius: 20, offset: const Offset(0, -4)),
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
                  onTap: () => onTap(0)),
              _NavItem(
                  icon: Icons.bookmark_rounded,
                  label: 'Saved',
                  selected: currentIndex == 1,
                  onTap: () => onTap(1)),
              const SizedBox(width: 64),
              _NavItem(
                  icon: Icons.chat_bubble_rounded,
                  label: 'Messages',
                  selected: currentIndex == 3,
                  onTap: () => onTap(3)),
              _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  selected: currentIndex == 4,
                  onTap: () => onTap(4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap});
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
  const _PlaceholderTab(
      {required this.icon, required this.title, required this.message});
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

class _GlowingFab extends StatelessWidget {
  const _GlowingFab({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _GlowingFabContent(onPressed: onPressed);
  }
}

class _GlowingFabContent extends StatefulWidget {
  const _GlowingFabContent({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_GlowingFabContent> createState() => _GlowingFabState();
}

class _GlowingFabState extends State<_GlowingFabContent>
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
