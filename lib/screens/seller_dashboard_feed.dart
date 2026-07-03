import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../theme/app_colors.dart';
import '../models/need_model.dart';
import '../models/need_model.dart' as legacy;
import '../models/offer_model.dart';
import '../repositories/marketplace_repository.dart';
import 'chat_conversation_room_screen.dart';
import 'offer_sheet.dart';
import 'need_detail_screen.dart'; // ✅ ADD THIS IMPORT

class SellerDashboardFeed extends StatefulWidget {
  const SellerDashboardFeed({super.key});

  @override
  State<SellerDashboardFeed> createState() => _SellerDashboardFeedState();
}

class _SellerDashboardFeedState extends State<SellerDashboardFeed> {
  final List<Need> _needs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _listenToNeeds();
  }

  void _listenToNeeds() {
    final dbRef = FirebaseDatabase.instance.ref().child('needs');
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    dbRef.onValue.listen((event) {
      final List<Need> tempNeeds = [];

      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> allMap =
            event.snapshot.value as Map<dynamic, dynamic>;

        allMap.forEach((key, value) {
          final data = Map<String, dynamic>.from(value as Map);

          final String authorId = data['authorId'] ?? data['userId'] ?? '';

          // Skip own needs
          if (authorId == currentUserId) return;

          Urgency urgency = Urgency.medium;
          if (data['urgency'] == 'high') {
            urgency = Urgency.high;
          } else if (data['urgency'] == 'low') {
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
              userId: data['userId'] ?? data['authorId'],
              userName: data['userName'] ?? data['authorName'],
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

  // ✅ Open Need Detail
  void _openNeedDetail(Need need) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NeedDetailScreen(need: need),
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ HEADER WITH USER NAME
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
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  // ✅ Seller Mode Badge
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

            // Body
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: AppColors.primaryLight,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Loading needs...',
                            style: TextStyle(
                              color: AppColors.textSecondary,
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
                                  color: AppColors.textSecondary,
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
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inbox_rounded,
                                    size: 48,
                                    color: AppColors.textTertiary,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No needs available',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Check back later for new requests',
                                    style: TextStyle(
                                      color: AppColors.textTertiary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _needs.length,
                              padding: const EdgeInsets.all(16),
                              itemBuilder: (context, index) {
                                final item = _needs[index];
                                return _buildNeedCard(item);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeedCard(Need need) {
    return GestureDetector(
      onTap: () => _openNeedDetail(need), // ✅ ON TAP - Open Detail
      child: Card(
        color: AppColors.surface,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category + Budget
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
              // Company
              if (need.companyName != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Company: ${need.companyName}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              // Condition + Payment
              const SizedBox(height: 8),
              Text(
                'Condition: ${need.condition?.label ?? 'N/A'} | Payment: ${need.paymentMethod?.label ?? 'N/A'}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              // Description
              const SizedBox(height: 12),
              Text(
                need.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
              // Posted time
              const SizedBox(height: 8),
              Text(
                'Posted ${need.timeElapsed}',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),
              // Buttons
              const SizedBox(height: 16),
              Row(
                children: [
                  // Make Offer Button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showOfferSheet(context, need),
                      icon: const Icon(
                        Icons.local_offer_rounded,
                        size: 16,
                      ),
                      label: const Text('Make Offer'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Chat Button
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatConversationRoomScreen(
                              targetUserNodeId:
                                  need.userId ?? need.authorId ?? '',
                              targetUserDisplayName:
                                  need.userName ?? need.authorName,
                            ),
                          ),
                        );
                      },
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
