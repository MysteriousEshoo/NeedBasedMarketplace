import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/need_model.dart';
import '../theme/app_colors.dart';
import '../providers/theme_provider.dart';
import '../widgets/pill_tag.dart';
import '../widgets/primary_loading_button.dart';
import 'offer_sheet.dart';
import 'chat_screen.dart';

class NeedDetailScreen extends StatefulWidget {
  const NeedDetailScreen({super.key, required this.need});
  final Need need;

  @override
  State<NeedDetailScreen> createState() => _NeedDetailScreenState();
}

class _NeedDetailScreenState extends State<NeedDetailScreen> {
  bool _isSellerMode = false;
  String? _sellerId;

  @override
  void initState() {
    super.initState();
    _listenUserRole();
    _findChatSeller();
  }

  void _listenUserRole() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snap) {
      if (snap.exists && mounted) {
        setState(() {
          _isSellerMode = snap.data()?['isSellerMode'] ?? false;
        });
      }
    });
  }

  void _findChatSeller() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final needId = widget.need.id;

    if (widget.need.authorId == currentUserId) {
      FirebaseDatabase.instance
          .ref()
          .child('chats')
          .child(needId)
          .onValue
          .listen((event) {
        if (event.snapshot.value != null) {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          data.forEach((channelId, value) {
            final channelData = Map<String, dynamic>.from(value as Map);
            if (channelData.isNotEmpty) {
              final firstMsg = channelData.values.first;
              if (firstMsg is Map) {
                final senderId = firstMsg['senderId'] ?? '';
                if (senderId != currentUserId && mounted) {
                  setState(() {
                    _sellerId = senderId;
                  });
                }
              }
            }
          });
        }
      });
    } else {
      _sellerId = widget.need.authorId;
    }
  }

  void _openOfferSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OfferSheet(need: widget.need),
    );
  }

  void _openChat() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final needAuthorId = widget.need.authorId ?? widget.need.userId ?? '';

    if (needAuthorId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot find user info'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String otherUserId;
    String otherUserName;

    if (currentUserId == needAuthorId) {
      if (_sellerId != null && _sellerId!.isNotEmpty) {
        otherUserId = _sellerId!;
        otherUserName = 'Seller';
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No seller has responded yet'),
            backgroundColor: AppColors.urgentMedium,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    } else {
      otherUserId = needAuthorId;
      otherUserName = widget.need.authorName;
    }

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(
        needId: widget.need.id,
        needTitle: widget.need.title,
        otherUserId: otherUserId,
        otherUserName: otherUserName,
      ),
    ));
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

    return Scaffold(
      backgroundColor: bg,
      appBar: _buildAppBar(surface, textPrimary),
      bottomNavigationBar: _buildBottomBar(surface, border),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            Row(children: [
              PillTag(
                label: widget.need.category,
                foreground: AppColors.accent,
                background: AppColors.accent.withOpacity(0.08),
              ),
              const SizedBox(width: 8),
              PillTag(
                label: widget.need.urgency.label,
                icon: Icons.local_fire_department_rounded,
                foreground: widget.need.urgency.color,
                background: widget.need.urgency.softColor,
              ),
            ]),
            const SizedBox(height: 18),
            Text(widget.need.title,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontSize: 26, height: 1.25, color: textPrimary)),
            const SizedBox(height: 18),
            _buildAuthorRow(textPrimary, textSecondary),
            const SizedBox(height: 20),
            _buildBudgetCard(),
            const SizedBox(height: 24),
            if (widget.need.companyName != null &&
                widget.need.companyName!.isNotEmpty) ...[
              _buildInfoRow(Icons.phone_android_rounded, 'Company',
                  widget.need.companyName!, textPrimary, textSecondary),
              const SizedBox(height: 12),
            ],
            if (widget.need.condition != null) ...[
              _buildInfoRow(Icons.verified_rounded, 'Condition',
                  widget.need.condition!.label, textPrimary, textSecondary),
              const SizedBox(height: 12),
            ],
            if (widget.need.paymentMethod != null) ...[
              _buildInfoRow(Icons.payments_rounded, 'Payment',
                  widget.need.paymentMethod!.label, textPrimary, textSecondary),
              const SizedBox(height: 12),
            ],
            Text('Description',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: textPrimary)),
            const SizedBox(height: 10),
            Text(widget.need.description,
                style:
                    TextStyle(color: textSecondary, height: 1.6, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(Color surface, Color textPrimary) {
    return AppBar(
      backgroundColor: surface,
      title: Text('Need Details',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700)),
      iconTheme: IconThemeData(color: textPrimary),
      actions: [
        StreamBuilder(
          stream: FirebaseDatabase.instance
              .ref()
              .child('users_saved_needs')
              .child(FirebaseAuth.instance.currentUser?.uid ?? '')
              .child(widget.need.id)
              .onValue,
          builder: (context, AsyncSnapshot<DatabaseEvent> snap) {
            final isSaved = snap.hasData && snap.data!.snapshot.value != null;
            return IconButton(
              icon: Icon(
                isSaved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: isSaved ? AppColors.accent : AppColors.textSecondary,
              ),
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;
                final ref = FirebaseDatabase.instance
                    .ref()
                    .child('users_saved_needs')
                    .child(user.uid)
                    .child(widget.need.id);
                if (isSaved) {
                  await ref.remove();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Removed from saved'),
                          behavior: SnackBarBehavior.floating),
                    );
                  }
                } else {
                  await ref.set(true);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Added to saved'),
                          behavior: SnackBarBehavior.floating),
                    );
                  }
                }
              },
            );
          },
        ),
        IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildAuthorRow(Color textPrimary, Color textSecondary) {
    final initial = widget.need.authorName.isNotEmpty
        ? widget.need.authorName[0].toUpperCase()
        : '?';
    return Row(children: [
      CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.accent.withOpacity(0.12),
        child: Text(initial,
            style: const TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w800,
                fontSize: 18)),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.need.authorName,
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 15, color: textPrimary)),
        Row(children: [
          const Icon(Icons.schedule_rounded,
              size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text('Posted ${widget.need.timeElapsed}',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
        ]),
      ]),
    ]);
  }

  Widget _buildBudgetCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Client budget',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(widget.need.formattedBudget,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 24)),
        ]),
        const Spacer(),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${widget.need.offers} offers',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16)),
          Text('submitted',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.8), fontSize: 13)),
        ]),
      ]),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      Color textPrimary, Color textSecondary) {
    return Row(children: [
      Container(
        height: 42,
        width: 42,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: AppColors.primary),
      ),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: textSecondary, fontSize: 12)),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 15, color: textPrimary)),
      ]),
    ]);
  }

  Widget _buildBottomBar(Color surface, Color border) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isMyNeed = widget.need.authorId == currentUserId;

    bool showChat = true;
    if (isMyNeed) {
      showChat = _sellerId != null && _sellerId!.isNotEmpty;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (showChat)
              _SquareIconButton(
                icon: Icons.chat_bubble_outline_rounded,
                onTap: _openChat,
              ),
            if (showChat) const SizedBox(width: 12),
            if (_isSellerMode && !isMyNeed)
              Expanded(
                child: FilledButton.icon(
                  onPressed: _openOfferSheet,
                  icon: const Icon(Icons.local_offer_rounded, size: 18),
                  label: const Text('Make Offer'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            if (isMyNeed)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Edit Need'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SquareIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 54,
          width: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1.4),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
      ),
    );
  }
}
