import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../models/need_model.dart';
import '../models/offer_model.dart';
import '../repositories/marketplace_repository.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';
import 'offer_sheet.dart';
import 'need_detail_screen.dart';

class SellerDashboardFeed extends StatefulWidget {
  const SellerDashboardFeed({super.key});

  @override
  State<SellerDashboardFeed> createState() => _SellerDashboardFeedState();
}

class _SellerDashboardFeedState extends State<SellerDashboardFeed> {
  final List<Need> _needs = [];
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController =
      ScrollController(keepScrollOffset: false);
  bool _isLoading = true;
  String? _error;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _listenToNeeds();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // ✅ FIXED: Get urgency color
  Color _getUrgencyColor(Urgency urgency) {
    if (urgency == Urgency.high) {
      return AppColors.urgentHigh;
    } else if (urgency == Urgency.medium) {
      return AppColors.urgentMedium;
    } else {
      return AppColors.urgentLow;
    }
  }

  // ✅ FIXED: Get urgency label
  String _getUrgencyLabel(Urgency urgency) {
    if (urgency == Urgency.high) {
      return 'High';
    } else if (urgency == Urgency.medium) {
      return 'Medium';
    } else {
      return 'Low';
    }
  }

  void _listenToNeeds() {
    final dbRef = FirebaseDatabase.instance.ref().child('needs');
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    _subscription?.cancel();

    _subscription = dbRef.onValue.listen((event) {
      final List<Need> tempNeeds = [];

      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> allMap =
            event.snapshot.value as Map<dynamic, dynamic>;

        allMap.forEach((key, value) {
          final data = Map<String, dynamic>.from(value as Map);
          final String authorId = data['authorId'] ?? data['userId'] ?? '';

          // Skip own needs
          if (authorId == currentUserId) return;

          // ✅ FIXED: Get urgency
          Urgency urgency = Urgency.medium;
          final String urgencyStr = data['urgency'] ?? '';
          if (urgencyStr == 'high') {
            urgency = Urgency.high;
          } else if (urgencyStr == 'low') {
            urgency = Urgency.low;
          }

          tempNeeds.add(
            Need(
              id: key,
              title: data['title'] ?? 'Untitled',
              description: data['description'] ?? '',
              category: data['category'] ?? 'General',
              budget: data['budget'] ?? 0,
              timeElapsed: _getTimeAgo(data['timestamp']),
              urgency: urgency,
              authorName: data['authorName'] ?? 'Anonymous',
              offers: data['offers'] ?? 0,
              userId: data['userId'] ?? data['authorId'] ?? '',
              userName: data['userName'] ?? data['authorName'] ?? '',
              companyName: data['company'],
              condition: data['condition'] != null
                  ? (data['condition'] == 'New'
                      ? ProductCondition.new_
                      : ProductCondition.used)
                  : null,
              paymentMethod: data['paymentMethod'] != null
                  ? (data['paymentMethod'] == 'Cash'
                      ? PaymentMethod.cash
                      : PaymentMethod.onlineDeposit)
                  : null,
              location: data['location'],
              isPremium: data['isPremium'] ?? false,
              authorId: authorId,
            ),
          );
        });
      }

      setState(() {
        _needs.clear();
        _needs.addAll(tempNeeds);
        _isLoading = false;
        _error = null;
      });
    }, onError: (error) {
      print('❌ Error: $error');
      setState(() {
        _isLoading = false;
        _error = error.toString();
      });
    });
  }

  String _getTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    try {
      if (timestamp is! int) return 'Just now';
      final postDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final difference = DateTime.now().difference(postDate);
      if (difference.inSeconds < 60) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays < 7) return '${difference.inDays}d ago';
      if (difference.inDays < 30) {
        return '${(difference.inDays / 7).floor()}w ago';
      }
      return '${postDate.day}/${postDate.month}/${postDate.year}';
    } catch (_) {
      return 'Just now';
    }
  }

  void _showOfferSheet(BuildContext context, Need need) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OfferSheet(need: need),
    );
  }

  void _openNeedDetail(Need need) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NeedDetailScreen(need: need),
      ),
    );
  }

  Stream<OfferModel?> _offerStreamFor(Need need) {
    return _chatService.watchOfferForChat(
      needId: need.id,
      otherUserId: need.userId ?? need.authorId ?? '',
    );
  }

  void _openAcceptedChat(Need need, OfferModel offer) {
    final buyerId = need.userId ?? need.authorId ?? '';
    if (buyerId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          needId: need.id,
          needTitle: need.title,
          otherUserId: buyerId,
          otherUserName: need.userName ?? need.authorName,
          initialOfferId: offer.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    String userName = 'User';
    if (user != null) {
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        userName = user.displayName!;
      } else if (user.email != null) {
        userName = user.email!.split('@').first;
      }
    }

    final c = context.palette;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      color: c.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '🔵 Seller Mode',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            color: AppColors.primaryLight,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading needs...',
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 48,
                                color: AppColors.urgentHigh,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error loading needs',
                                style: TextStyle(
                                  color: AppColors.urgentHigh,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _isLoading = true;
                                    _error = null;
                                  });
                                  _listenToNeeds();
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _needs.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inbox_rounded,
                                    size: 48,
                                    color: c.textTertiary,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No needs available from other users',
                                    style: TextStyle(
                                      color: c.textSecondary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Check back later for new requests',
                                    style: TextStyle(
                                      color: c.textTertiary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              primary: false,
                              itemCount: _needs.length,
                              padding: const EdgeInsets.all(16),
                              itemBuilder: (context, index) {
                                final need = _needs[index];
                                return KeyedSubtree(
                                  key: ValueKey(need.id),
                                  child: _buildNeedCard(need, c),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeedCard(Need need, AppPalette c) {
    return GestureDetector(
      onTap: () => _openNeedDetail(need),
      child: Card(
        color: c.surface,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    need.category.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'PKR ${need.budget}',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              if (need.companyName != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Company: ${need.companyName}',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Condition: ${need.condition?.label ?? 'N/A'} | Payment: ${need.paymentMethod?.label ?? 'N/A'}',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                need.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.textPrimary,
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Posted ${need.timeElapsed}',
                style: TextStyle(
                  color: c.textTertiary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 16),
              StreamBuilder<OfferModel?>(
                stream: _offerStreamFor(need),
                builder: (context, snapshot) {
                  final offer = snapshot.data;
                  final isAccepted = offer?.status == 'accepted';

                  if (!isAccepted) {
                    return SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showOfferSheet(context, need),
                        icon: const Icon(
                          Icons.local_offer_rounded,
                          size: 16,
                        ),
                        label: const Text('Make Offer'),
                      ),
                    );
                  }

                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      onPressed: () => _openAcceptedChat(need, offer!),
                      icon: const Icon(
                        Icons.chat_bubble_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Chat',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
