import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/chat_service.dart';
import '../models/message_model.dart';
import '../theme/app_colors.dart';
import '../providers/theme_provider.dart';

class ChatScreen extends StatefulWidget {
  final String needId;
  final String needTitle;
  final String otherUserId;
  final String otherUserName;

  const ChatScreen({
    super.key,
    required this.needId,
    required this.needTitle,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  bool _isSending = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatService.markMessagesAsSeen(
        needId: widget.needId,
        otherUserId: widget.otherUserId,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (animated) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _controller.clear();

    try {
      await _chatService.sendMessage(
        receiverId: widget.otherUserId,
        receiverName: widget.otherUserName,
        needId: widget.needId,
        needTitle: widget.needTitle,
        content: text,
        type: 'text',
      );
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to send: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final Color bg = isDark ? AppColors.background : const Color(0xFFF1F5F9);
    final Color composerBg = isDark ? AppColors.surface : Colors.white;
    final Color bubbleBg =
        isDark ? AppColors.surfaceMuted : const Color(0xFFE2E8F0);
    final Color inputFill =
        isDark ? AppColors.surfaceMuted : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: bg,
      appBar: _buildAppBar(isDark),
      body: Column(children: [
        // Need context banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppColors.primary.withOpacity(0.08),
          child: Row(children: [
            const Icon(Icons.link_rounded, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Re: ${widget.needTitle}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ]),
        ),

        // Messages list
        Expanded(
          child: StreamBuilder<List<MessageModel>>(
            stream: _chatService.getMessages(
              needId: widget.needId,
              otherUserId: widget.otherUserId,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryLight));
              }

              final messages = snapshot.data ?? [];

              if (messages.isEmpty) {
                return _buildEmptyState();
              }

              _chatService.markMessagesAsSeen(
                needId: widget.needId,
                otherUserId: widget.otherUserId,
              );

              _scrollToBottom(animated: false);

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMe = msg.senderId == _currentUserId;

                  final showDate = index == 0 ||
                      !_isSameDay(messages[index - 1].timestamp, msg.timestamp);

                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showDate) _DateSeparator(date: msg.timestamp),
                        _ChatBubble(
                          message: msg,
                          isMe: isMe,
                          isDark: isDark,
                          bubbleBg: bubbleBg,
                        ),
                      ]);
                },
              );
            },
          ),
        ),

        // Composer
        _buildComposer(composerBg, inputFill, isDark),
      ]),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  PreferredSizeWidget _buildAppBar(bool isDark) {
    final Color appBarBg = isDark ? AppColors.surface : Colors.white;
    return AppBar(
      backgroundColor: appBarBg,
      elevation: 0,
      titleSpacing: 0,
      title: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.accent.withOpacity(0.15),
          child: Text(
            widget.otherUserName.isNotEmpty
                ? widget.otherUserName[0].toUpperCase()
                : '?',
            style: const TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w800,
                fontSize: 16),
          ),
        ),
        const SizedBox(width: 12),
        Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.otherUserName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              const Text('NeedHub',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ]),
      ]),
      actions: [
        IconButton(icon: const Icon(Icons.more_vert_rounded), onPressed: () {}),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.chat_bubble_outline_rounded,
              color: AppColors.primary, size: 38),
        ),
        const SizedBox(height: 16),
        const Text('Start the conversation!',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontSize: 16)),
        const SizedBox(height: 6),
        Text('Say hello to ${widget.otherUserName}',
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ]),
    );
  }

  Widget _buildComposer(Color bg, Color inputFill, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: bg,
        border: Border(
            top: BorderSide(
                color: isDark ? AppColors.divider : const Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          // Attach icon
          _ComposerIcon(
            icon: Icons.attach_file_rounded,
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('📎 File sharing — Firebase Storage required'),
                  behavior: SnackBarBehavior.floating),
            ),
          ),
          const SizedBox(width: 8),

          // Text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: inputFill,
                borderRadius: BorderRadius.circular(26),
              ),
              child: TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                minLines: 1,
                onSubmitted: (_) => _sendMessage(),
                style: TextStyle(
                    color: isDark
                        ? AppColors.textPrimary
                        : const Color(0xFF0F172A)),
                decoration: const InputDecoration(
                  hintText: 'Type a message…',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send / Voice button
          GestureDetector(
            onTap: _hasText ? _sendMessage : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                gradient: _hasText
                    ? const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight])
                    : LinearGradient(
                        colors: [AppColors.border, AppColors.border]),
                shape: BoxShape.circle,
                boxShadow: _hasText
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(
                      _hasText ? Icons.send_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Chat Bubble ──────────────────────────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool isDark;
  final Color bubbleBg;

  const _ChatBubble({
    required this.message,
    required this.isMe,
    required this.isDark,
    required this.bubbleBg,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ Offer message special style
    if (message.type == 'offer') {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          decoration: BoxDecoration(
            color: isMe ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.accent.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.local_offer_rounded,
                      size: 16, color: AppColors.accent),
                  SizedBox(width: 8),
                  Text(
                    '💰 Offer',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                message.content,
                style: TextStyle(
                  color: isMe ? Colors.white : AppColors.textPrimary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message.formattedTime,
                style: TextStyle(
                  color: isMe ? Colors.white60 : AppColors.textTertiary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ System message style
    if (message.type == 'system') {
      return Align(
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.accent.withOpacity(0.3),
            ),
          ),
          child: Text(
            message.content,
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    // ✅ Regular text message
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.74),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : bubbleBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.senderName,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11),
                ),
              ),
            Text(
              message.content,
              style: TextStyle(
                color: isMe
                    ? Colors.white
                    : (isDark
                        ? AppColors.textPrimary
                        : const Color(0xFF0F172A)),
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(
                message.formattedTime,
                style: TextStyle(
                  color: isMe ? Colors.white60 : AppColors.textTertiary,
                  fontSize: 10,
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 4),
                _StatusIcon(status: message.status),
              ],
            ]),
          ],
        ),
      ),
    );
  }
}

// ─── Status tick icon ─────────────────────────────────────────────────────────
class _StatusIcon extends StatelessWidget {
  final String status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'seen':
        return const Icon(Icons.done_all_rounded,
            size: 14, color: Colors.lightBlue);
      case 'delivered':
        return const Icon(Icons.done_all_rounded,
            size: 14, color: Colors.white60);
      default:
        return const Icon(Icons.done_rounded, size: 14, color: Colors.white60);
    }
  }
}

// ─── Date separator ───────────────────────────────────────────────────────────
class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  String get _label {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(_label,
              style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ]),
    );
  }
}

// ─── Composer icon button ─────────────────────────────────────────────────────
class _ComposerIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ComposerIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: AppColors.textSecondary, size: 22),
      ),
    );
  }
}
