import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/chat_service.dart';
import '../theme/app_colors.dart';
import '../providers/theme_provider.dart';
import '../providers/settings_provider.dart';
import 'chat_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final ChatService _chatService = ChatService();
  late final String _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final isBuyerMode = settingsProvider.isBuyerMode;

    final Color bg = isDark ? AppColors.background : const Color(0xFFF1F5F9);
    final Color surface = isDark ? AppColors.surface : Colors.white;
    final Color border = isDark ? AppColors.border : const Color(0xFFE2E8F0);
    final Color textPrimary =
        isDark ? AppColors.textPrimary : const Color(0xFF0F172A);
    final Color textSecondary =
        isDark ? AppColors.textSecondary : const Color(0xFF475569);
    final Color textTertiary =
        isDark ? AppColors.textTertiary : const Color(0xFF94A3B8);

    if (_currentUserId.isEmpty) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: surface,
          title: Text('Messages', style: TextStyle(color: textPrimary)),
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
          isBuyerMode ? 'Messages · Buyer' : 'Messages · Seller',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800),
        ),
        iconTheme: IconThemeData(color: textPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: border),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        // Buyer mode only shows chats where this user is the buyer, seller
        // mode only the chats where they are the seller. Both stay stored in
        // the database until the user deletes them.
        key: ValueKey(isBuyerMode),
        stream: _chatService.getUserChats(
          _currentUserId,
          acceptedOnly: true,
          role: isBuyerMode ? 'buyer' : 'seller',
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryLight),
            );
          }

          final chats = snapshot.data ?? [];

          if (chats.isEmpty) {
            return _buildEmpty(isBuyerMode, textSecondary, textTertiary);
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: chats.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final chat = chats[index];
              return _ChatTile(
                chat: chat,
                surface: surface,
                border: border,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                textTertiary: textTertiary,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmpty(
    bool isBuyerMode,
    Color textSecondary,
    Color textTertiary,
  ) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.chat_bubble_outline_rounded,
            color: AppColors.primary,
            size: 38,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isBuyerMode ? 'No approved seller chats yet' : 'No approved chats yet',
          style: TextStyle(
            color: textSecondary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isBuyerMode
              ? 'Accepted offer chats will appear here'
              : 'When a buyer accepts your offer, the chat will appear here',
          textAlign: TextAlign.center,
          style: TextStyle(color: textTertiary, fontSize: 13),
        ),
      ]),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final Map<String, dynamic> chat;
  final Color surface, border, textPrimary, textSecondary, textTertiary;

  const _ChatTile({
    required this.chat,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
  });

  String _formatTime(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch(ts as int);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final needId = chat['needId'] as String? ?? '';
    final needTitle = chat['needTitle'] as String? ?? 'Need';
    final peerId = chat['peerId'] as String? ?? '';
    final peerName = chat['peerName'] as String? ?? 'User';
    final lastMsg = chat['lastMessage'] as String? ?? '';
    final unread = chat['unreadCount'] as int? ?? 0;
    final offerId = chat['offerId'] as String?;
    final time = _formatTime(chat['lastTimestamp']);
    final initial = peerName.isNotEmpty ? peerName[0].toUpperCase() : '?';

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            needId: needId,
            needTitle: needTitle,
            otherUserId: peerId,
            otherUserName: peerName,
            initialOfferId: offerId,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Row(children: [
          Stack(children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.accent.withOpacity(0.12),
              child: Text(
                initial,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            if (unread > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.urgentHigh,
                    shape: BoxShape.circle,
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(
                    peerName,
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(time, style: TextStyle(color: textTertiary, fontSize: 11)),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                Expanded(
                  child: Text(
                    needTitle,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Accepted',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 3),
              Text(
                lastMsg,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: unread > 0 ? textPrimary : textSecondary,
                  fontSize: 13,
                  fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
