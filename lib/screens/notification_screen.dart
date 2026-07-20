import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../models/notification_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../providers/theme_provider.dart';
import '../providers/settings_provider.dart';
import 'chat_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _handleNotificationTap(NotificationModel notification) async {
    if (_userId == null) return;

    await _notificationService.markAsSeen(_userId!, notification.id);

    if (!mounted || notification.data == null) return;

    if (notification.type == 'message') {
      final payload = _MessageNotificationPayload.tryParse(notification.data!);
      if (payload == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This message notification is missing chat details.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            needId: payload.needId,
            needTitle: payload.needTitle,
            otherUserId: payload.otherUserId,
            otherUserName: payload.otherUserName,
          ),
        ),
      );
      return;
    }

    if (notification.type != 'offer') return;

    final payload = _OfferNotificationPayload.tryParse(notification.data!);
    if (payload == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This offer notification is missing chat details.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          needId: payload.needId,
          needTitle: payload.needTitle,
          otherUserId: payload.otherUserId,
          otherUserName: payload.otherUserName,
          initialOfferId: payload.offerId,
          showOfferDecisionOnOpen: payload.action == 'offer_received',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final currentMode = settingsProvider.isBuyerMode ? 'buyer' : 'seller';
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
                      color: c.textTertiary,
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
              final audience = notification.audience ?? '';
              return _NotificationTile(
                notification: notification,
                fromOtherMode: audience.isNotEmpty && audience != currentMode,
                surface: surface,
                border: border,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () => _handleNotificationTap(notification),
              );
            },
          );
        },
      ),
    );
  }
}

class _MessageNotificationPayload {
  final String needId;
  final String needTitle;
  final String otherUserId;
  final String otherUserName;

  const _MessageNotificationPayload({
    required this.needId,
    required this.needTitle,
    required this.otherUserId,
    required this.otherUserName,
  });

  static _MessageNotificationPayload? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['action'] != 'chat_message') return null;

      final needId = (decoded['needId'] ?? '').toString();
      final otherUserId = (decoded['otherUserId'] ?? '').toString();
      if (needId.isEmpty || otherUserId.isEmpty) return null;

      return _MessageNotificationPayload(
        needId: needId,
        needTitle: (decoded['needTitle'] ?? 'Need').toString(),
        otherUserId: otherUserId,
        otherUserName: (decoded['otherUserName'] ?? 'User').toString(),
      );
    } catch (_) {
      return null;
    }
  }
}

class _OfferNotificationPayload {
  final String action;
  final String offerId;
  final String needId;
  final String needTitle;
  final String otherUserId;
  final String otherUserName;

  const _OfferNotificationPayload({
    required this.action,
    required this.offerId,
    required this.needId,
    required this.needTitle,
    required this.otherUserId,
    required this.otherUserName,
  });

  static _OfferNotificationPayload? tryParse(String raw) {
    final parts = raw.split('|');

    if (parts.length >= 8 &&
        (parts.first == 'offer_received' ||
            parts.first == 'offer_submitted' ||
            parts.first == 'offer_status')) {
      return _OfferNotificationPayload(
        action: parts[0],
        offerId: parts[1],
        needId: parts[2],
        needTitle: parts[3],
        otherUserId: parts[4],
        otherUserName: parts[5],
      );
    }

    if (parts.length == 6) {
      return _OfferNotificationPayload(
        action: 'offer_received',
        offerId: parts[0],
        needId: parts[1],
        needTitle: parts[2],
        otherUserId: parts[3],
        otherUserName: parts[4],
      );
    }

    return null;
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final bool fromOtherMode;
  final Color surface, border, textPrimary, textSecondary;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.fromOtherMode,
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
      case 'seller':
        return Icons.storefront_rounded;
      case 'need_match':
        return Icons.track_changes_rounded;
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
      case 'seller':
        return AppColors.primaryLight;
      case 'need_match':
        return AppColors.accent;
      default:
        return AppColors.urgentMedium;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
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
                  if (fromOtherMode)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'From your ${notification.audience} account',
                          style: const TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
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
                      color: c.textTertiary,
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
