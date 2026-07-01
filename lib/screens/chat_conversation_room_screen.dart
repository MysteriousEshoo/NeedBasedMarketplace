import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_colors.dart';
import '../models/chat_message_model.dart';
import '../services/realtime_chat_service.dart';

class ChatConversationRoomScreen extends StatefulWidget {
  final String targetUserNodeId;
  final String targetUserDisplayName;

  const ChatConversationRoomScreen(
      {super.key,
      required this.targetUserNodeId,
      required this.targetUserDisplayName});

  @override
  State<ChatConversationRoomScreen> createState() =>
      _ChatConversationRoomScreenState();
}

class _ChatConversationRoomScreenState
    extends State<ChatConversationRoomScreen> {
  final _chatService = RealtimeChatService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  late String _channelId;
  bool _isTransmittingMedia = false;

  @override
  void initState() {
    super.initState();
    _channelId =
        _chatService.getChatChannelId(_currentUserId, widget.targetUserNodeId);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _dispatchTextMessagePacket() async {
    final txt = _textController.text.trim();
    if (txt.isEmpty) return;
    _textController.clear();

    final packet = ChatMessageModel(
      id: '',
      senderId: _currentUserId,
      timestamp: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'text',
      content: txt,
      seen: false,
    );
    await _chatService.pushMessagePacket(_channelId, packet);
    _scrollToBottomTerminal();
  }

  void _pickAndUploadAsset(ImageSource source, String type) async {
    final picker = ImagePicker();
    final pickedFile = type == 'video'
        ? await picker.pickVideo(source: source)
        : await picker.pickImage(source: source);

    if (pickedFile == null) return;
    setState(() => _isTransmittingMedia = true);

    try {
      final downloadUrl = await _chatService.uploadChatAsset(
          _channelId, File(pickedFile.path), type);
      final packet = ChatMessageModel(
        id: '',
        senderId: _currentUserId,
        timestamp: DateTime.now().millisecondsSinceEpoch.toString(),
        type: type,
        content: downloadUrl,
        seen: false,
      );
      await _chatService.pushMessagePacket(_channelId, packet);
      _scrollToBottomTerminal();
    } catch (_) {
      // Graceful error logging
    } finally {
      if (mounted) setState(() => _isTransmittingMedia = false);
    }
  }

  void _scrollToBottomTerminal() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          title: Text(widget.targetUserDisplayName),
          backgroundColor: AppColors.surface,
          elevation: 0),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessageModel>>(
              stream: _chatService.streamChatMessages(_channelId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primaryLight));
                }
                final msgs = snapshot.data ?? [];
                return ListView.builder(
                  controller: _scrollController,
                  itemCount: msgs.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, idx) {
                    final m = msgs[idx];
                    final bool isMe = m.senderId == _currentUserId;
                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(16).copyWith(
                              bottomRight: isMe
                                  ? const Radius.circular(0)
                                  : const Radius.circular(16),
                              bottomLeft: !isMe
                                  ? const Radius.circular(0)
                                  : const Radius.circular(16)),
                        ),
                        child: m.type == 'text'
                            ? Text(m.content,
                                style: TextStyle(
                                    color: isMe
                                        ? Colors.white
                                        : AppColors.textPrimary))
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(m.content,
                                    width: 200,
                                    height: 200,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.broken_image))),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_isTransmittingMedia)
            const LinearProgressIndicator(color: AppColors.primaryLight),
          Container(
            padding: const EdgeInsets.all(12),
            color: AppColors.surface,
            child: Row(
              children: [
                IconButton(
                    icon: const Icon(Icons.image_rounded,
                        color: AppColors.primaryLight),
                    onPressed: () =>
                        _pickAndUploadAsset(ImageSource.gallery, 'image')),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                        hintText: 'Type clean secure message...',
                        border: InputBorder.none),
                  ),
                ),
                IconButton(
                    icon: const Icon(Icons.send_rounded,
                        color: AppColors.primary),
                    onPressed: _dispatchTextMessagePacket),
              ],
            ),
          )
        ],
      ),
    );
  }
}
