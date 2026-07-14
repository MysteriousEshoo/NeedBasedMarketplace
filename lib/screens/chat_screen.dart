import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/message_model.dart';
import '../models/offer_model.dart';
import '../providers/theme_provider.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../widgets/voice_message_bubble.dart';

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
  final AudioRecorder _inlineRecorder = AudioRecorder();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  late final Stream<OfferModel?> _offerStream;
  late final Stream<List<MessageModel>> _messagesStream;

  bool _isSending = false;
  bool _hasText = false;
  bool _decisionDialogShown = false;
  bool _isUpdatingOffer = false;
  bool _isInlineRecording = false;
  Duration _inlineRecordingDuration = Duration.zero;
  Timer? _inlineRecordingTimer;
  String? _inlineRecordingPath;

  @override
  void initState() {
    super.initState();
    _offerStream = _chatService.watchOfferForChat(
      needId: widget.needId,
      otherUserId: widget.otherUserId,
    );
    // Created once here — NOT inside build(). Building it in build() spawned a
    // brand-new stream on every offer-stream emit, resetting connectionState to
    // `waiting` and flashing the loading spinner over the messages repeatedly.
    _messagesStream = _chatService.getMessages(
      needId: widget.needId,
      otherUserId: widget.otherUserId,
    );
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText && mounted) {
        setState(() => _hasText = hasText);
      }
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
    _inlineRecordingTimer?.cancel();
    _inlineRecorder.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _currentUserName {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    return user?.email?.split('@').first ?? 'Buyer';
  }

  bool _isCurrentUserSeller(OfferModel? offer) {
    return offer != null && offer.sellerId == _currentUserId;
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
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<bool> _ensureMicPermission() async {
    final mic = await Permission.microphone.request();
    if (mic.isGranted) return true;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required')),
      );
    }
    return false;
  }

  Future<bool> _ensureCameraPermission() async {
    final camera = await Permission.camera.request();
    if (camera.isGranted) return true;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission is required')),
      );
    }
    return false;
  }

  Future<void> _startInlineRecording() async {
    if (_isSending || _isInlineRecording) return;
    if (!await _ensureMicPermission()) return;

    try {
      final path =
          '${Directory.systemTemp.path}${Platform.pathSeparator}voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _inlineRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 96000,
          sampleRate: 44100,
        ),
        path: path,
      );

      if (!mounted) return;
      setState(() {
        _isInlineRecording = true;
        _inlineRecordingPath = path;
        _inlineRecordingDuration = Duration.zero;
      });

      _inlineRecordingTimer?.cancel();
      _inlineRecordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_isInlineRecording) return;
        setState(() {
          _inlineRecordingDuration += const Duration(seconds: 1);
        });
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not start recording: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _finishInlineRecording({required bool send}) async {
    if (!_isInlineRecording) return;

    final fallbackPath = _inlineRecordingPath;
    final durationSeconds = _inlineRecordingDuration.inSeconds;
    _inlineRecordingTimer?.cancel();

    String? path;
    try {
      path = await _inlineRecorder.stop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not stop recording: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _isInlineRecording = false;
      _inlineRecordingDuration = Duration.zero;
      _inlineRecordingPath = null;
    });

    final finalPath = path ?? fallbackPath;
    if (finalPath == null) return;

    final file = File(finalPath);
    if (send) {
      await _sendVoiceMessage(
        file,
        durationSeconds: durationSeconds > 0 ? durationSeconds : 1,
      );
    } else if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _sendVoiceMessage(
    File audioFile, {
    int durationSeconds = 0,
  }) async {
    if (_isSending) return;
    setState(() => _isSending = true);

    try {
      await _chatService.sendVoiceMessage(
        receiverId: widget.otherUserId,
        receiverName: widget.otherUserName,
        needId: widget.needId,
        needTitle: widget.needTitle,
        audioFile: audioFile,
        durationSeconds: durationSeconds,
      );
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send voice: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showFilePicker() {
    final c = context.palette;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Share File',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  _FilePickerOption(
                    icon: Icons.image_rounded,
                    label: 'Gallery',
                    color: Colors.blue,
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                  _FilePickerOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: Colors.green,
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                  _FilePickerOption(
                    icon: Icons.folder_rounded,
                    label: 'Document',
                    color: Colors.orange,
                    onTap: _pickDocument,
                  ),
                  _FilePickerOption(
                    icon: Icons.video_library_rounded,
                    label: 'Video',
                    color: Colors.purple,
                    onTap: _pickVideo,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _closePickerSheet() {
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.pop(context);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera && !await _ensureCameraPermission()) {
      return;
    }

    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked == null) return;
      _closePickerSheet();
      await _sendFile(File(picked.path), 'image');
    } catch (e) {
      _showSnack('Could not pick image: $e', isError: true);
    }
  }

  Future<void> _pickVideo() async {
    try {
      final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (picked == null) return;
      _closePickerSheet();
      await _sendFile(File(picked.path), 'video');
    } catch (e) {
      _showSnack('Could not pick video: $e', isError: true);
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xlsx', 'ppt', 'zip'],
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null || path.isEmpty) {
        _showSnack('This document could not be opened.', isError: true);
        return;
      }
      _closePickerSheet();
      await _sendFile(File(path), 'document');
    } catch (e) {
      _showSnack('Could not pick document: $e', isError: true);
    }
  }

  Future<void> _sendFile(File file, String type) async {
    if (_isSending) return;
    if (!await file.exists()) {
      _showSnack('Selected file was not found.', isError: true);
      return;
    }

    setState(() => _isSending = true);

    try {
      final fileName = _fileNameFromPath(file.path);
      final fileSize = await file.length();
      await _chatService.sendFileMessage(
        receiverId: widget.otherUserId,
        receiverName: widget.otherUserName,
        needId: widget.needId,
        needTitle: widget.needTitle,
        file: file,
        type: type,
        fileName: fileName,
        fileSize: fileSize,
      );
      _scrollToBottom();
    } catch (e) {
      _showSnack('Failed to send file: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendMessage({
    required bool chatDisabled,
    required OfferModel? offer,
  }) async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    if (chatDisabled) {
      _showSnack(_disabledMessage(offer));
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
      );
      _scrollToBottom();
    } catch (e) {
      _showSnack('Failed to send: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleMenuSelection(String value, OfferModel? offer) async {
    switch (value) {
      case 'view_peer':
        _showPeerDetails(offer);
        break;
      case 'delete_chat':
        await _confirmDeleteChat();
        break;
    }
  }

  Future<void> _confirmDeleteChat() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete chat?'),
        content: const Text(
          'This removes the chat from your inbox only. The other user will still have their copy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      await _chatService.deleteChatForUser(
        needId: widget.needId,
        otherUserId: widget.otherUserId,
      );
      if (!mounted) return;
      Navigator.pop(context);
      _showSnack('Chat deleted.');
    } catch (e) {
      _showSnack('Could not delete chat: $e', isError: true);
    }
  }

  Future<Map<String, dynamic>> _loadPeerDetails(OfferModel? knownOffer) async {
    final offer = knownOffer ??
        await _chatService.getOfferForChat(
          needId: widget.needId,
          otherUserId: widget.otherUserId,
        );
    final need = await _chatService.getNeedDetails(widget.needId);
    return {
      'offer': offer,
      'need': need,
    };
  }

  void _showPeerDetails(OfferModel? offerFromStream) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return FutureBuilder<Map<String, dynamic>>(
          future: _loadPeerDetails(offerFromStream),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _DetailsSheet(
                title: 'Loading details',
                icon: Icons.hourglass_empty_rounded,
                children: [
                  SizedBox(height: 44),
                  Center(child: CircularProgressIndicator()),
                  SizedBox(height: 44),
                ],
              );
            }

            final data = snapshot.data ?? {};
            final offer = data['offer'] as OfferModel?;
            final need = data['need'] as Map<String, dynamic>?;
            final viewingBuyer = _isCurrentUserSeller(offer);

            return _DetailsSheet(
              title: viewingBuyer ? 'View Buyer' : 'View Seller',
              icon: viewingBuyer
                  ? Icons.person_search_rounded
                  : Icons.storefront_rounded,
              children: viewingBuyer
                  ? _buyerNeedDetails(need)
                  : _sellerOfferDetails(offer, need),
            );
          },
        );
      },
    );
  }

  List<Widget> _sellerOfferDetails(
    OfferModel? offer,
    Map<String, dynamic>? need,
  ) {
    if (offer == null) {
      return [
        const _DetailRow(
          label: 'Offer',
          value: 'Offer details are not available yet.',
        ),
        _DetailRow(label: 'Need', value: widget.needTitle),
      ];
    }

    return [
      _DetailRow(label: 'Seller', value: offer.sellerName),
      _DetailRow(
        label: 'Price',
        value: 'PKR ${offer.offeredPrice.toStringAsFixed(0)}',
      ),
      _DetailRow(label: 'Delivery', value: offer.deliveryTime),
      _DetailRow(label: 'Status', value: _capitalize(offer.status)),
      _DetailRow(label: 'Need', value: offer.needTitle),
      if (offer.message.trim().isNotEmpty)
        _DetailRow(label: 'Offer Message', value: offer.message.trim()),
      if (need != null)
        _DetailRow(
          label: 'Buyer Need',
          value: _needText(need, 'description', fallback: widget.needTitle),
        ),
    ];
  }

  List<Widget> _buyerNeedDetails(Map<String, dynamic>? need) {
    if (need == null) {
      return [
        _DetailRow(label: 'Need', value: widget.needTitle),
        const _DetailRow(
          label: 'Details',
          value: 'Need details are not available yet.',
        ),
      ];
    }

    return [
      _DetailRow(label: 'Buyer', value: _needText(need, 'authorName')),
      _DetailRow(label: 'Need', value: _needText(need, 'title')),
      _DetailRow(label: 'Category', value: _needText(need, 'category')),
      _DetailRow(label: 'Budget', value: _formatBudget(need['budget'])),
      if (_needText(need, 'location').isNotEmpty)
        _DetailRow(label: 'Location', value: _needText(need, 'location')),
      _DetailRow(label: 'Condition', value: _needText(need, 'condition')),
      _DetailRow(
        label: 'Payment',
        value: _needText(need, 'paymentMethod'),
      ),
      _DetailRow(label: 'Description', value: _needText(need, 'description')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bg = isDark ? AppColors.background : const Color(0xFFF1F5F9);
    final composerBg = isDark ? AppColors.surface : Colors.white;
    final bubbleBg = isDark ? AppColors.surfaceMuted : const Color(0xFFE2E8F0);
    final inputFill = isDark ? AppColors.surfaceMuted : const Color(0xFFF1F5F9);

    return StreamBuilder<OfferModel?>(
      stream: _offerStream,
      builder: (context, offerSnapshot) {
        final offer = offerSnapshot.data;
        _queueOfferDecisionDialog(offer);
        final chatDisabled = _isChatDisabled(offer);

        return Scaffold(
          backgroundColor: bg,
          appBar: _buildAppBar(isDark, offer),
          body: Column(
            children: [
              _buildNeedBanner(),
              if (offer != null) _buildOfferStatusBanner(offer),
              Expanded(
                child: StreamBuilder<List<MessageModel>>(
                  stream: _messagesStream,
                  builder: (context, snapshot) {
                    // Only show the spinner on the very first load, while we
                    // have no data at all. Once messages have arrived we keep
                    // showing them across refreshes instead of flashing the
                    // loader again.
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryLight,
                        ),
                      );
                    }

                    final messages = snapshot.data ?? [];
                    if (messages.isEmpty) return _buildEmptyState();

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
                              isMe: msg.senderId == _currentUserId,
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
                context,
                composerBg,
                inputFill,
                isDark,
                chatDisabled: chatDisabled,
                offer: offer,
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildNeedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.primary.withOpacity(0.08),
      child: Row(
        children: [
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
        ],
      ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${offer.sellerName} - Delivery: ${offer.deliveryTime}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.palette.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_canRespondToOffer(offer)) ...[
            const SizedBox(height: 10),
            Row(
              children: [
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
              ],
            ),
          ],
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark, OfferModel? offer) {
    final appBarBg = isDark ? AppColors.surface : Colors.white;
    final viewLabel =
        _isCurrentUserSeller(offer) ? 'View Buyer' : 'View Seller';

    return AppBar(
      backgroundColor: appBarBg,
      elevation: 0,
      titleSpacing: 0,
      title: Row(
        children: [
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'NeedHub',
                  style: TextStyle(
                    color: context.palette.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          tooltip: 'Chat options',
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (value) => _handleMenuSelection(value, offer),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'view_peer',
              child: Row(
                children: [
                  Icon(
                    _isCurrentUserSeller(offer)
                        ? Icons.person_search_rounded
                        : Icons.storefront_rounded,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(viewLabel),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete_chat',
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded, size: 20),
                  SizedBox(width: 12),
                  Text('Delete Chat'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildEmptyState() {
    final c = context.palette;
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
              Icons.chat_bubble_outline_rounded,
              color: AppColors.primary,
              size: 38,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Start the conversation!',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Say hello to ${widget.otherUserName}',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer(
    BuildContext context,
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
            style: TextStyle(
              color: context.palette.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    if (_isInlineRecording) {
      return _buildRecordingComposer(context, bg, isDark);
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
        child: Row(
          children: [
            _ComposerIcon(
              icon: Icons.attach_file_rounded,
              onTap: _showFilePicker,
            ),
            const SizedBox(width: 4),
            _ComposerIcon(
              icon: Icons.mic_rounded,
              onTap: _startInlineRecording,
            ),
            const SizedBox(width: 4),
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
                    color: isDark
                        ? AppColors.textPrimary
                        : const Color(0xFF0F172A),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onLongPressStart:
                  _hasText ? null : (_) => _startInlineRecording(),
              onTap: _hasText
                  ? () => _sendMessage(chatDisabled: chatDisabled, offer: offer)
                  : _startInlineRecording,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  gradient: _hasText
                      ? const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight],
                        )
                      : const LinearGradient(
                          colors: [AppColors.accent, AppColors.primaryLight],
                        ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_hasText ? AppColors.primary : AppColors.accent)
                          .withOpacity(0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingComposer(BuildContext context, Color bg, bool isDark) {
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
        child: Row(
          children: [
            IconButton(
              tooltip: 'Cancel voice',
              onPressed: () => _finishInlineRecording(send: false),
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: Colors.red.withOpacity(0.18)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mic_rounded, color: Colors.red, size: 20),
                    const SizedBox(width: 10),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(_inlineRecordingDuration),
                      style: TextStyle(
                        color: context.palette.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Recording',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.palette.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap:
                  _isSending ? null : () => _finishInlineRecording(send: true),
              child: Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: _isSending ? context.palette.border : AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: _isSending
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _fileNameFromPath(String path) {
    final parts = path.split(RegExp(r'[\\/]'));
    return parts.isEmpty ? 'File' : parts.last;
  }

  String _needText(
    Map<String, dynamic> need,
    String key, {
    String fallback = '',
  }) {
    final value = need[key];
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _formatBudget(Object? value) {
    final amount = int.tryParse(value?.toString() ?? '') ?? 0;
    if (amount <= 0) return 'Not specified';
    final raw = amount.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) buffer.write(',');
      buffer.write(raw[i]);
    }
    return 'PKR $buffer';
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
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
    if (message.type == 'voice') {
      return VoiceMessageBubble(
        message: message,
        isMe: isMe,
        bubbleBg: bubbleBg,
      );
    }

    if (message.type == 'image' && message.mediaUrl != null) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onTap: () => _openAttachment(context),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(4),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.74,
            ),
            decoration: BoxDecoration(
              color: isMe ? AppColors.primary : bubbleBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    message.mediaUrl!,
                    fit: BoxFit.cover,
                    width: MediaQuery.of(context).size.width * 0.68,
                    height: 220,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 160,
                      child: Center(child: Icon(Icons.broken_image, size: 42)),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                _BubbleMeta(message: message, isMe: isMe),
              ],
            ),
          ),
        ),
      );
    }

    if (message.type == 'video' || message.type == 'document') {
      final isVideo = message.type == 'video';
      return _AttachmentBubble(
        message: message,
        isMe: isMe,
        bubbleBg: bubbleBg,
        icon: isVideo ? Icons.play_circle_fill_rounded : Icons.description,
        title: message.fileName ?? (isVideo ? 'Video' : 'Document'),
        subtitle: _formatFileSize(message.fileSize),
        onTap: () => _openAttachment(context),
      );
    }

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
            color: isMe ? AppColors.primary : context.palette.surface,
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
                  color: isMe ? Colors.white : context.palette.textPrimary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              _BubbleMeta(message: message, isMe: isMe),
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
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.74,
        ),
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
            _BubbleMeta(message: message, isMe: isMe),
          ],
        ),
      ),
    );
  }

  Future<void> _openAttachment(BuildContext context) async {
    final url = message.mediaUrl;
    if (url == null || url.isEmpty) return;

    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open attachment')),
      );
    }
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return 'Tap to open';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _AttachmentBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final Color bubbleBg;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AttachmentBubble({
    required this.message,
    required this.isMe,
    required this.bubbleBg,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.74,
            minWidth: 220,
          ),
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
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isMe
                          ? Colors.white24
                          : AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: isMe ? Colors.white : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isMe ? Colors.white : context.palette.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                isMe ? Colors.white70 : context.palette.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _BubbleMeta(message: message, isMe: isMe),
            ],
          ),
        ),
      ),
    );
  }
}

class _BubbleMeta extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const _BubbleMeta({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message.formattedTime,
          style: TextStyle(
            color: isMe ? Colors.white60 : context.palette.textTertiary,
            fontSize: 10,
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 4),
          _StatusIcon(status: message.status),
        ],
      ],
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
      child: Row(
        children: [
          Expanded(child: Divider(color: context.palette.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              _label,
              style: TextStyle(
                color: context.palette.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Divider(color: context.palette.border)),
        ],
      ),
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
        child: Icon(icon, color: context.palette.textSecondary, size: 22),
      ),
    );
  }
}

class _FilePickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _FilePickerOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsSheet extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _DetailsSheet({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.54,
      minChildSize: 0.35,
      maxChildSize: 0.88,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: context.palette.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: context.palette.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final displayValue = value.trim().isEmpty ? 'Not specified' : value.trim();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.palette.surfaceMuted.withOpacity(0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.palette.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            displayValue,
            style: TextStyle(
              color: context.palette.textPrimary,
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
