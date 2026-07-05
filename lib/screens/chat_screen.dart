import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';
import '../models/message_model.dart';
import '../models/offer_model.dart';
import '../theme/app_colors.dart';
import '../providers/theme_provider.dart';

class ChatScreen extends StatefulWidget {
  final String needId;
  final String needTitle;
  final String otherUserId;
  final String otherUserName;
  final String? initialOfferId;
  final bool showOfferDecisionOnOpen;

  const ChatScreen({
    super.key,
    required this.needId,
    required this.needTitle,
    required this.otherUserId,
    required this.otherUserName,
    this.initialOfferId,
    this.showOfferDecisionOnOpen = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  late final Stream<OfferModel?> _offerStream;
  bool _isSending = false;
  bool _hasText = false;
  bool _decisionDialogShown = false;
  bool _isUpdatingOffer = false;

  @override
  void initState() {
    super.initState();
    _offerStream = _chatService.watchOfferForChat(
      needId: widget.needId,
      otherUserId: widget.otherUserId,
    );
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

  String get _currentUserName {
    final user = FirebaseAuth.instance.currentUser;
    return user?.displayName ?? user?.email?.split('@').first ?? 'Buyer';
  }

  bool _canRespondToOffer(OfferModel? offer) {
    return offer != null &&
        offer.status == 'pending' &&
        offer.sellerId != _currentUserId;
  }

  bool _isChatDisabled(OfferModel? offer) {
    if (offer == null) return widget.initialOfferId != null;
    return offer.status != 'accepted';
  }

  String _disabledMessage(OfferModel? offer) {
    if (offer == null) return 'Loading offer details...';
    if (offer.status == 'pending' && _canRespondToOffer(offer)) {
      return 'Accept this offer to continue the chat, or reject it to close this seller for this need.';
    }
    if (offer.status == 'pending') {
      return 'Waiting for the buyer to accept this offer.';
    }
    if (offer.status == 'rejected') {
      return 'This offer was rejected. Chat is closed for this seller on this need.';
    }
    return 'Chat is unavailable for this offer.';
  }

  void _queueOfferDecisionDialog(OfferModel? offer) {
    if (!widget.showOfferDecisionOnOpen ||
        _decisionDialogShown ||
        !_canRespondToOffer(offer)) {
      return;
    }
    if (widget.initialOfferId != null && offer!.id != widget.initialOfferId) {
      return;
    }

    _decisionDialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showOfferDecisionDialog(offer!);
    });
  }

  Future<void> _handleOfferDecision(
    OfferModel offer, {
    required bool accepted,
  }) async {
    if (_isUpdatingOffer) return;

    final status = accepted ? 'accepted' : 'rejected';
    final sellerName =
        offer.sellerName.isNotEmpty ? offer.sellerName : widget.otherUserName;
    final systemMessage = accepted
        ? 'Offer accepted. You can now continue this chat.'
        : 'Offer rejected. This chat is now closed for this seller.';

    setState(() => _isUpdatingOffer = true);

    try {
      await _chatService.updateOfferDecision(
        needId: widget.needId,
        needTitle: widget.needTitle,
        offerId: offer.id,
        buyerId: _currentUserId,
        buyerName: _currentUserName,
        sellerId: offer.sellerId,
        sellerName: sellerName,
        status: status,
      );

      await _chatService.sendSystemMessage(
        receiverId: offer.sellerId,
        receiverName: sellerName,
        needId: widget.needId,
        needTitle: widget.needTitle,
        content: systemMessage,
        offerId: offer.id,
        offerStatus: status,
        chatDisabled: !accepted,
      );

      await _notificationService.sendNotification(
        userId: offer.sellerId,
        title: accepted ? 'Offer Accepted' : 'Offer Rejected',
        body: accepted
            ? 'Your offer for "${widget.needTitle}" was accepted. You can continue the chat.'
            : 'Your offer for "${widget.needTitle}" was rejected by the buyer.',
        type: 'offer',
        data:
            'offer_status|${offer.id}|${widget.needId}|${widget.needTitle}|$_currentUserId|$_currentUserName|${offer.deliveryTime}|${offer.offeredPrice.toStringAsFixed(0)}',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accepted
              ? 'Offer accepted. Chat is now enabled.'
              : 'Offer rejected. Chat is now closed.'),
          backgroundColor: accepted ? AppColors.accent : Colors.grey,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update offer: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingOffer = false);
    }
  }

  void _showOfferDecisionDialog(OfferModel offer) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Offer from ${offer.sellerName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Price: PKR ${offer.offeredPrice.toStringAsFixed(0)}'),
              const SizedBox(height: 6),
              Text('Delivery: ${offer.deliveryTime}'),
              if (offer.message.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(offer.message.trim()),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: _isUpdatingOffer
                  ? null
                  : () {
                      Navigator.pop(dialogContext);
                      _handleOfferDecision(offer, accepted: false);
                    },
              child: const Text(
                'Reject',
                style: TextStyle(color: Colors.red),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
              ),
              onPressed: _isUpdatingOffer
                  ? null
                  : () {
                      Navigator.pop(dialogContext);
                      _handleOfferDecision(offer, accepted: true);
                    },
              child: const Text(
                'Accept',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
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

  Future<void> _sendMessage({
    required bool chatDisabled,
    required OfferModel? offer,
  }) async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    if (chatDisabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_disabledMessage(offer)),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

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
      body: StreamBuilder<OfferModel?>(
        stream: _offerStream,
        builder: (context, offerSnapshot) {
          final offer = offerSnapshot.data;
          _queueOfferDecisionDialog(offer);
          final chatDisabled = _isChatDisabled(offer);

          return Column(children: [
            _buildNeedBanner(),
            if (offer != null) _buildOfferStatusBanner(offer),
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
                        color: AppColors.primaryLight,
                      ),
                    );
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
                          !_isSameDay(
                            messages[index - 1].timestamp,
                            msg.timestamp,
                          );

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
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            _buildComposer(
              composerBg,
              inputFill,
              isDark,
              chatDisabled: chatDisabled,
              offer: offer,
            ),
          ]);
        },
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildNeedBanner() {
    return Container(
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
    );
  }

  Widget _buildOfferStatusBanner(OfferModel offer) {
    final statusColor = switch (offer.status) {
      'accepted' => AppColors.accent,
      'rejected' => Colors.red,
      _ => AppColors.urgentMedium,
    };
    final statusLabel = switch (offer.status) {
      'accepted' => 'Accepted offer',
      'rejected' => 'Rejected offer',
      _ => 'Pending offer',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.08),
        border: Border(
          bottom: BorderSide(color: statusColor.withOpacity(0.18)),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.local_offer_rounded, size: 16, color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$statusLabel - PKR ${offer.offeredPrice.toStringAsFixed(0)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: statusColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Text(
          '${offer.sellerName} - Delivery: ${offer.deliveryTime}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (_canRespondToOffer(offer)) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isUpdatingOffer
                    ? null
                    : () => _handleOfferDecision(offer, accepted: false),
                child: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                ),
                onPressed: _isUpdatingOffer
                    ? null
                    : () => _handleOfferDecision(offer, accepted: true),
                child: const Text(
                  'Accept',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

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
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.otherUserName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const Text(
                'NeedHub',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
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
          child: const Icon(
            Icons.chat_bubble_outline_rounded,
            color: AppColors.primary,
            size: 38,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Start the conversation!',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Say hello to ${widget.otherUserName}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ]),
    );
  }

  Widget _buildComposer(
    Color bg,
    Color inputFill,
    bool isDark, {
    required bool chatDisabled,
    required OfferModel? offer,
  }) {
    if (chatDisabled) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.divider : const Color(0xFFE2E8F0),
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Text(
            _disabledMessage(offer),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.divider : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          _ComposerIcon(
            icon: Icons.attach_file_rounded,
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File sharing requires Firebase Storage.'),
                behavior: SnackBarBehavior.floating,
              ),
            ),
          ),
          const SizedBox(width: 8),
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
                onSubmitted: (_) =>
                    _sendMessage(chatDisabled: chatDisabled, offer: offer),
                style: TextStyle(
                  color:
                      isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                ),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
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
          GestureDetector(
            onTap: _hasText
                ? () => _sendMessage(chatDisabled: chatDisabled, offer: offer)
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                gradient: _hasText
                    ? const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                      )
                    : LinearGradient(
                        colors: [AppColors.border, AppColors.border],
                      ),
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
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
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
                  Icon(
                    Icons.local_offer_rounded,
                    size: 16,
                    color: AppColors.accent,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Offer',
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
                    fontSize: 11,
                  ),
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

class _StatusIcon extends StatelessWidget {
  final String status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'seen':
        return const Icon(
          Icons.done_all_rounded,
          size: 14,
          color: Colors.lightBlue,
        );
      case 'delivered':
        return const Icon(
          Icons.done_all_rounded,
          size: 14,
          color: Colors.white60,
        );
      default:
        return const Icon(
          Icons.done_rounded,
          size: 14,
          color: Colors.white60,
        );
    }
  }
}

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
          child: Text(
            _label,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ]),
    );
  }
}

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
