import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/need_model.dart';
import '../theme/app_colors.dart';
import '../widgets/pill_tag.dart';
import '../widgets/primary_loading_button.dart';
import 'chat_screen.dart';
import 'offer_sheet.dart';

class NeedDetailScreen extends StatefulWidget {
  const NeedDetailScreen({super.key, required this.need});

  final Need need;

  @override
  State<NeedDetailScreen> createState() => _NeedDetailScreenState();
}

class _NeedDetailScreenState extends State<NeedDetailScreen> {
  bool _isSellerMode = false;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  // ✅ REAL-TIME: Check if user is in Seller Mode
  void _checkUserRole() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        if (mounted) {
          setState(() {
            _isSellerMode = data['isSellerMode'] ?? false;
          });
        }
      }
    });
  }

  void _openOfferSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OfferSheet(need: widget.need),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Need Details'),
        actions: [
          StreamBuilder(
            stream: FirebaseDatabase.instance
                .ref()
                .child('users_saved_needs')
                .child(FirebaseAuth.instance.currentUser?.uid ?? '')
                .child(widget.need.id)
                .onValue,
            builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
              final bool isSaved =
                  snapshot.hasData && snapshot.data!.snapshot.value != null;

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: isSaved
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Removed from saved needs')),
                      );
                    } else {
                      await ref.set(true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Added to saved needs')),
                      );
                    }
                  },
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {},
          ),
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: _buildBottomAction(context),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                PillTag(
                  label: widget.need.category,
                  foreground: AppColors.accent,
                  background: AppColors.accent.withValues(alpha: 0.08),
                ),
                const SizedBox(width: 8),
                PillTag(
                  label: widget.need.urgency.label,
                  icon: Icons.local_fire_department_rounded,
                  foreground: widget.need.urgency.color,
                  background: widget.need.urgency.softColor,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              widget.need.title,
              style: textTheme.headlineMedium
                  ?.copyWith(fontSize: 26, height: 1.25),
            ),
            const SizedBox(height: 18),
            _buildAuthorRow(context),
            const SizedBox(height: 20),
            _buildBudgetCard(context),
            const SizedBox(height: 24),
            Text('Description', style: textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(
              widget.need.description,
              style: textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            Text('Highlights', style: textTheme.titleLarge),
            const SizedBox(height: 12),
            _buildHighlights(),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthorRow(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.accent.withValues(alpha: 0.12),
          child: Text(
            widget.need.authorName.substring(0, 1),
            style: const TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.need.authorName,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            Row(
              children: [
                const Icon(Icons.star_rounded,
                    size: 16, color: AppColors.urgentMedium),
                const SizedBox(width: 3),
                Text(
                  '4.9 · Posted ${widget.need.timeElapsed}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBudgetCard(BuildContext context) {
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
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Client budget',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.need.formattedBudget,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${widget.need.offers} offers',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              Text(
                'submitted',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHighlights() {
    const items = [
      (Icons.location_on_outlined, 'Location', 'Remote / Pakistan'),
      (Icons.schedule_rounded, 'Timeline', 'Within 2 weeks'),
      (Icons.verified_user_outlined, 'Verified', 'Payment protected'),
    ];
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        Icon(item.$1, size: 20, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$2,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        item.$3,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  // ✅ BOTTOM ACTION - Offer button SIRF Seller Mode mein
  Widget _buildBottomAction(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Chat Button - Always visible
            _SquareIconButton(
              icon: Icons.chat_bubble_outline_rounded,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatScreen(peerName: widget.need.authorName),
                ),
              ),
            ),

            // ✅ Offer Button - ONLY in Seller Mode
            if (_isSellerMode) ...[
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openOfferSheet(context),
                  icon: const Icon(Icons.send_rounded, size: 20),
                  label: const Text('Make Offer'),
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
// Square Icon Button
// ----------------------------------------------------------------------------
class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 56,
          width: 56,
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
