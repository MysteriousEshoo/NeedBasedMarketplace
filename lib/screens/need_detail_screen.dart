import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/need_model.dart';
import '../theme/app_colors.dart';
import '../widgets/pill_tag.dart';
import '../widgets/primary_loading_button.dart';
import 'chat_screen.dart';

/// Screen 4 — Provider offer stream & detailed need view.
///
/// Displays the full need plus a persistent "Submit an Offer" action that
/// opens an interactive bottom sheet for pricing, delivery time and a
/// cover letter.
class NeedDetailScreen extends StatelessWidget {
  const NeedDetailScreen({super.key, required this.need});

  final Need need;

  void _openOfferSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SubmitOfferSheet(need: need),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Need Details'),
        actions: [
          // LIVE REALTIME BOOKMARK SYSTEM WITH AUTO-TOGGLE & BACKGROUND FEEDBACK
          StreamBuilder(
            stream: FirebaseDatabase.instance
                .ref()
                .child('users_saved_needs')
                .child(FirebaseAuth.instance.currentUser?.uid ?? '')
                .child(need.id)
                .onValue,
            builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
              final bool isSaved =
                  snapshot.hasData && snapshot.data!.snapshot.value != null;

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  // Dynamic Background Darkening feedback
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
                        .child(need.id);

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
                  label: need.category,
                  foreground: AppColors.accent,
                  background: AppColors.accent.withValues(alpha: 0.08),
                ),
                const SizedBox(width: 8),
                PillTag(
                  label: need.urgency.label,
                  icon: Icons.local_fire_department_rounded,
                  foreground: need.urgency.color,
                  background: need.urgency.softColor,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              need.title,
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
              need.description,
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
            need.authorName.substring(0, 1),
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
              need.authorName,
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
                  '4.9 · Posted ${need.timeElapsed}',
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
                need.formattedBudget,
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
                '${need.offers} offers',
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
            _SquareIconButton(
              icon: Icons.chat_bubble_outline_rounded,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatScreen(peerName: need.authorName),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _openOfferSheet(context),
                icon: const Icon(Icons.send_rounded, size: 20),
                label: const Text('Submit an Offer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A square, outlined icon button used beside the primary CTA.
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

// ----------------------------------------------------------------------------
// Submit offer bottom sheet
// ----------------------------------------------------------------------------

class _SubmitOfferSheet extends StatefulWidget {
  const _SubmitOfferSheet({required this.need});

  final Need need;

  @override
  State<_SubmitOfferSheet> createState() => _SubmitOfferSheetState();
}

class _SubmitOfferSheetState extends State<_SubmitOfferSheet> {
  late double _price;
  String _deliveryTime = '3 days';
  final _coverController = TextEditingController();
  bool _isSending = false;

  static const _deliveryOptions = [
    '24 hours',
    '3 days',
    '1 week',
    '2 weeks',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    _price = widget.need.budget.toDouble();
  }

  @override
  void dispose() {
    _coverController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _isSending = true);
    await Future.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
        content: const Text('Your premium offer was sent!'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final minBudget = (widget.need.budget * 0.5).roundToDouble();
    final maxBudget = (widget.need.budget * 1.5).roundToDouble();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  height: 5,
                  width: 44,
                  margin: const EdgeInsets.only(bottom: 22),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text('Submit an Offer', style: textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'Stand out with a clear price and a thoughtful note.',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Price slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Your price',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  Text(
                    'PKR ${_price.round()}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: AppColors.surfaceMuted,
                  thumbColor: AppColors.primary,
                  overlayColor: AppColors.primary.withValues(alpha: 0.15),
                  trackHeight: 6,
                ),
                child: Slider(
                  value: _price.clamp(minBudget, maxBudget),
                  min: minBudget,
                  max: maxBudget,
                  onChanged: (v) => setState(() => _price = v),
                ),
              ),
              const SizedBox(height: 16),

              // Delivery time
              const Text(
                'Delivery time',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _deliveryTime,
                isExpanded: true,
                borderRadius: BorderRadius.circular(16),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.schedule_rounded),
                ),
                items: _deliveryOptions
                    .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                    .toList(),
                onChanged: (v) => setState(() => _deliveryTime = v!),
              ),
              const SizedBox(height: 20),

              // Cover letter
              const Text(
                'Cover letter',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _coverController,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText:
                      'Introduce yourself and explain why you are the best fit…',
                ),
              ),
              const SizedBox(height: 24),
              PrimaryLoadingButton(
                label: 'Send Premium Offer',
                icon: Icons.workspace_premium_rounded,
                isLoading: _isSending,
                onPressed: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
