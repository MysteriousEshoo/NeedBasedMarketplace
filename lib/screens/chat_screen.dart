import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A single chat entry. A message is either text or an embedded proposal.
class _Message {
  const _Message({
    required this.text,
    required this.isMine,
    this.time = '',
    this.proposal,
  });

  final String text;
  final bool isMine;
  final String time;
  final _Proposal? proposal;
}

/// An attached proposal card rendered inside the conversation.
class _Proposal {
  const _Proposal({required this.budget, required this.delivery});
  final String budget;
  final String delivery;
}

/// Screen 5 — Real-time-looking chat interface.
///
/// Features an online-status header, asymmetric chat bubbles, an embedded
/// proposal card with an "Accept Offer" action, and a sleek composer.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.peerName});

  final String peerName;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _composerController = TextEditingController();
  final _scrollController = ScrollController();
  bool _offerAccepted = false;

  final List<_Message> _messages = [
    const _Message(
      text: 'Hi! I saw your need for a Flutter developer. I can help.',
      isMine: false,
      time: '09:41',
    ),
    const _Message(
      text: 'That sounds great. Have you built delivery apps before?',
      isMine: true,
      time: '09:42',
    ),
    const _Message(
      text:
          'Yes — three of them, all with live tracking and payments. '
          'Here is my formal offer:',
      isMine: false,
      time: '09:44',
    ),
    const _Message(
      text: '',
      isMine: false,
      proposal: _Proposal(budget: 'PKR 80,000', delivery: '2 weeks'),
    ),
  ];

  @override
  void dispose() {
    _composerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _composerController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_Message(text: text, isMine: true, time: 'now'));
      _composerController.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildHeader(),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                if (message.proposal != null) {
                  return _ProposalCard(
                    proposal: message.proposal!,
                    accepted: _offerAccepted,
                    onAccept: () => setState(() => _offerAccepted = true),
                  );
                }
                return _ChatBubble(message: message);
              },
            ),
          ),
          _buildComposer(),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Header
  // --------------------------------------------------------------------------

  PreferredSizeWidget _buildHeader() {
    return AppBar(
      titleSpacing: 0,
      title: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.accent.withValues(alpha: 0.12),
                child: Text(
                  widget.peerName.substring(0, 1),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  height: 13,
                  width: 13,
                  decoration: BoxDecoration(
                    color: AppColors.online,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.peerName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const Text(
                'Online now',
                style: TextStyle(
                  color: AppColors.online,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(icon: const Icon(Icons.call_outlined), onPressed: () {}),
        IconButton(icon: const Icon(Icons.more_vert_rounded), onPressed: () {}),
        const SizedBox(width: 4),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Composer
  // --------------------------------------------------------------------------

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file_rounded,
                  color: AppColors.textSecondary),
              onPressed: () {},
            ),
            Expanded(
              child: TextField(
                controller: _composerController,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  fillColor: AppColors.surfaceMuted,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(26),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(26),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _send,
              child: Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Chat bubble
// ----------------------------------------------------------------------------

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final _Message message;

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.74,
        ),
        decoration: BoxDecoration(
          color: isMine ? AppColors.primary : AppColors.surfaceMuted,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMine ? 20 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 20),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isMine ? Colors.white : AppColors.textPrimary,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            if (message.time.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                message.time,
                style: TextStyle(
                  color: isMine
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Proposal card
// ----------------------------------------------------------------------------

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.proposal,
    required this.accepted,
    required this.onAccept,
  });

  final _Proposal proposal;
  final bool accepted;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.budgetTagSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.description_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Formal Proposal',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _detailColumn('Agreed budget', proposal.budget),
                ),
                Container(width: 1, height: 36, color: AppColors.divider),
                Expanded(
                  child: _detailColumn('Delivery', proposal.delivery),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: accepted ? null : onAccept,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      accepted ? AppColors.surfaceMuted : AppColors.primary,
                  foregroundColor:
                      accepted ? AppColors.textSecondary : Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: Icon(
                  accepted
                      ? Icons.check_circle_rounded
                      : Icons.handshake_rounded,
                  size: 20,
                ),
                label: Text(accepted ? 'Offer Accepted' : 'Accept Offer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
