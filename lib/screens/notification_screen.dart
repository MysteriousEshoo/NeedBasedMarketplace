import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../services/chat_service.dart';
import '../models/notification_model.dart';
import '../theme/app_colors.dart';
import '../providers/theme_provider.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  final DatabaseReference _firebaseDatabase = FirebaseDatabase.instance.ref();
  final ChatService _chatService = ChatService();
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _acceptOffer(
    String offerId,
    String needId,
    String needTitle,
    String sellerId,
    String sellerName,
    NotificationModel notification,
  ) async {
    if (_userId == null) return;

    try {
      await _firebaseDatabase
          .child('offers')
          .child(needId)
          .child(offerId)
          .child('status')
          .set('accepted');

      await _notificationService.sendNotification(
        userId: sellerId,
        title: '🎉 Offer Accepted!',
        body: 'Your offer for "$needTitle" has been accepted by the buyer!',
        type: 'system',
        data: needId,
      );

      await _chatService.sendSystemMessage(
        receiverId: sellerId,
        needId: needId,
        needTitle: needTitle,
        content: '🎉 Offer Accepted! You can now chat with the buyer.',
      );

      await _notificationService.markAsSeen(_userId!, notification.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Offer accepted! Chat is now enabled.'),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectOffer(
    String offerId,
    String needId,
    NotificationModel notification,
  ) async {
    try {
      await _firebaseDatabase
          .child('offers')
          .child(needId)
          .child(offerId)
          .child('status')
          .set('rejected');

      await _notificationService.markAsSeen(_userId!, notification.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Offer rejected.'),
          backgroundColor: Colors.grey,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showOfferActionDialog(
    BuildContext context,
    String offerId,
    String needId,
    String needTitle,
    String sellerId,
    String sellerName,
    NotificationModel notification,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📩 Offer Received'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Need: $needTitle'),
            const SizedBox(height: 8),
            Text(notification.body),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _rejectOffer(offerId, needId, notification);
            },
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
            ),
            onPressed: () {
              Navigator.pop(context);
              _acceptOffer(
                offerId,
                needId,
                needTitle,
                sellerId,
                sellerName,
                notification,
              );
            },
            child: const Text('Accept Offer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final Color bg = isDark ? AppColors.background : const Color(0xFFF1F5F9);
    final Color surface = isDark ? AppColors.surface : Colors.white;
    final Color border = isDark ? AppColors.border : const Color(0xFFE2E8F0);
    final Color textPrimary =
        isDark ? AppColors.textPrimary : const Color(0xFF0F172A);
    final Color textSecondary =
        isDark ? AppColors.textSecondary : const Color(0xFF475569);

    if (_userId == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: surface,
          title: Text('Notifications', style: TextStyle(color: textPrimary)),
        ),
        body: Center(
          child: Text('Please login', style: TextStyle(color: textSecondary)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        title: Text(
          'Notifications',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: IconThemeData(color: textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded),
            onPressed: () {
              _notificationService.markAllAsSeen(_userId!);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All notifications marked as read'),
                  backgroundColor: AppColors.accent,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _notificationService.getNotifications(_userId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryLight),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      color: AppColors.primary,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'re all caught up!',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationTile(
                notification: notification,
                surface: surface,
                border: border,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () {
                  _notificationService.markAsSeen(_userId!, notification.id);

                  if (notification.type == 'offer' &&
                      notification.data != null) {
                    final parts = notification.data!.split('|');
                    if (parts.length == 3) {
                      final offerId = parts[0];
                      final needId = parts[1];
                      final needTitle = parts[2];

                      _firebaseDatabase
                          .child('offers')
                          .child(needId)
                          .child(offerId)
                          .get()
                          .then((snap) {
                        if (snap.exists) {
                          final data = snap.value as Map<dynamic, dynamic>;
                          final sellerId = data['sellerId'] ?? '';
                          final sellerName = data['sellerName'] ?? 'Seller';

                          _showOfferActionDialog(
                            context,
                            offerId,
                            needId,
                            needTitle,
                            sellerId,
                            sellerName,
                            notification,
                          );
                        }
                      });
                    }
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Notification Tile ──────────────────────────────────────────────────────
class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final Color surface, border, textPrimary, textSecondary;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
  });

  IconData _getIcon(String type) {
    switch (type) {
      case 'offer':
        return Icons.local_offer_rounded;
      case 'message':
        return Icons.chat_bubble_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'offer':
        return AppColors.accent;
      case 'message':
        return AppColors.primary;
      default:
        return AppColors.urgentMedium;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSeen = notification.seen;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSeen ? surface : AppColors.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSeen ? border : AppColors.primary.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _getColor(notification.type).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getIcon(notification.type),
                color: _getColor(notification.type),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontWeight: isSeen ? FontWeight.w600 : FontWeight.w800,
                      color: textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.formattedTime,
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (!isSeen)
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
