import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_colors.dart';
import '../models/need_model.dart'; // ✅ Added Data Model Import Node
import '../models/offer_model.dart'; // ✅ Added Offer Model Import Node
import '../repositories/marketplace_repository.dart';
import 'chat_conversation_room_screen.dart';

class SellerDashboardFeed extends StatelessWidget {
  final MarketplaceRepository _repo = MarketplaceRepository();
  SellerDashboardFeed({super.key});

  void _showOfferSubmissionSheet(BuildContext context, String needId) {
    final priceController = TextEditingController();
    final msgController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('PROPOSE PRIVATE QUOTATION',
                  style: TextStyle(
                      color: AppColors.accent, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: priceController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'Your Proposed Price Matching Threshold'),
                validator: (v) => (v == null ||
                        double.tryParse(v) == null ||
                        double.parse(v) <= 0)
                    ? 'Valid numerical threshold allocation tracking required'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: msgController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'Optional Message Notes Package Parameters'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  onPressed: () async {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    final currentUser = FirebaseAuth.instance.currentUser;
                    final dynamicOffer = OfferModel(
                      id: const Uuid().v4(),
                      needId: needId,
                      sellerId: currentUser?.uid ?? '',
                      sellerName:
                          currentUser?.displayName ?? 'Verified Seller Engine',
                      offeredPrice: double.parse(priceController.text.trim()),
                      message: msgController.text.trim(),
                      createdAt: DateTime.now(),
                    );
                    await _repo.submitSellerOffer(dynamicOffer);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            '🎉 Quote pipeline transmission absolute packages dispatched!')));
                  },
                  child: const Text('Submit Offer Node',
                      style: TextStyle(color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<List<NeedModel>>(
        stream: _repo.streamActiveNeeds(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child:
                    CircularProgressIndicator(color: AppColors.primaryLight));
          }
          final needs = snapshot.data ?? [];
          if (needs.isEmpty) {
            return const Center(
                child: Text(
                    'No active consumer requirements mapped onto real-time data metrics.',
                    style: TextStyle(color: AppColors.textSecondary)));
          }
          return ListView.builder(
            itemCount: needs.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, idx) {
              final item = needs[idx];
              final currentUserId =
                  FirebaseAuth.instance.currentUser?.uid ?? '';

              // Prevent rendering self-made needs in seller feed channels mapping boundaries
              if (item.userId == currentUserId) return const SizedBox.shrink();

              return Card(
                color: AppColors.surface,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(item.category.toUpperCase(),
                              style: const TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                          Text('\$ ${item.budget.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16)),
                        ],
                      ),
                      if (item.company != null) ...[
                        const SizedBox(height: 6),
                        Text(
                            'Target Architecture Configuration: ${item.company == 'Others' ? item.customCompanyName : item.company}',
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                      ],
                      const SizedBox(height: 8),
                      Text(
                          'Condition Node Matrix: ${item.condition} | Strategy: ${item.paymentMethod}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 12),
                      Text(item.description,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              height: 1.4,
                              fontSize: 13)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _showOfferSubmissionSheet(context, item.id),
                              icon: const Icon(Icons.local_offer_rounded,
                                  size: 16),
                              label: const Text('Offer'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary),
                              onPressed: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            ChatConversationRoomScreen(
                                                targetUserNodeId: item.userId,
                                                targetUserDisplayName:
                                                    item.userName)));
                              },
                              icon: const Icon(Icons.chat_bubble_rounded,
                                  size: 16, color: Colors.white),
                              label: const Text('Connect Chat',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
