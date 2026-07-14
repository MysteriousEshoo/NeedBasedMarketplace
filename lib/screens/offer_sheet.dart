import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/need_model.dart' as legacy;
import '../models/offer_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../services/notification_service.dart';
import '../services/history_service.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

class OfferSheet extends StatefulWidget {
  final legacy.Need need;

  const OfferSheet({super.key, required this.need});

  @override
  State<OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends State<OfferSheet> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _deliveryOptions = [
    '24 hours',
    '3 days',
    '1 week',
    '2 weeks',
    '1 month',
    'Custom',
  ];
  String _selectedDelivery = '3 days';
  bool _showCustomDelivery = false;
  final _customDeliveryController = TextEditingController();

  @override
  void dispose() {
    _priceController.dispose();
    _messageController.dispose();
    _customDeliveryController.dispose();
    super.dispose();
  }

  Future<void> _submitOffer() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('Please login to submit an offer');
        setState(() => _isSubmitting = false);
        return;
      }

      final existingOfferSnapshot = await FirebaseDatabase.instance
          .ref()
          .child('offers')
          .child(widget.need.id)
          .get();

      bool hasExistingOffer = false;
      if (existingOfferSnapshot.exists && existingOfferSnapshot.value is Map) {
        final offersMap = existingOfferSnapshot.value as Map<dynamic, dynamic>;
        hasExistingOffer = offersMap.values.any((value) {
          if (value is! Map) return false;
          final offerData = Map<String, dynamic>.from(value);
          return offerData['sellerId'] == user.uid;
        });
      }

      if (hasExistingOffer) {
        _showError('You have already submitted an offer for this need!');
        setState(() => _isSubmitting = false);
        return;
      }

      String sellerName = 'Anonymous';
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        sellerName = user.displayName!;
      } else if (user.email != null) {
        sellerName = user.email!.split('@').first;
      }

      final buyerId = widget.need.authorId ?? widget.need.userId ?? '';
      if (buyerId.isEmpty) {
        _showError('Buyer not found');
        setState(() => _isSubmitting = false);
        return;
      }

      String deliveryTime = _selectedDelivery;
      if (_selectedDelivery == 'Custom') {
        deliveryTime = _customDeliveryController.text.trim();
        if (deliveryTime.isEmpty) {
          _showError('Please enter custom delivery time');
          setState(() => _isSubmitting = false);
          return;
        }
      }

      final offer = OfferModel(
        id: '',
        needId: widget.need.id,
        sellerId: user.uid,
        sellerName: sellerName,
        offeredPrice: double.parse(_priceController.text.trim()),
        message: _messageController.text.trim(),
        createdAt: DateTime.now(),
        status: 'pending',
        needTitle: widget.need.title,
        deliveryTime: deliveryTime,
      );

      final offerRef = FirebaseDatabase.instance
          .ref()
          .child('offers')
          .child(widget.need.id)
          .push();

      await offerRef.set(offer.toMap());

      // 📜 History: record this sent offer (fire-and-forget).
      HistoryService.log(
        type: HistoryService.typeOfferSent,
        title: widget.need.title,
        subtitle:
            'Offer: PKR ${_priceController.text.trim()} • Delivery: $deliveryTime',
        refId: widget.need.id,
      );

      final needRef = FirebaseDatabase.instance
          .ref()
          .child('needs')
          .child(widget.need.id)
          .child('offers');

      await needRef.set(widget.need.offers + 1);

      final notificationService = NotificationService();
      await notificationService.sendNotification(
        userId: buyerId,
        title: '📩 New Offer Received!',
        body:
            '$sellerName offered PKR ${_priceController.text.trim()} for "${widget.need.title}" (Delivery: $deliveryTime)',
        type: 'offer',
        data:
            'offer_received|${offerRef.key}|${widget.need.id}|${widget.need.title}|${user.uid}|$sellerName|$deliveryTime|${_priceController.text.trim()}',
      );

      await notificationService.sendNotification(
        userId: user.uid,
        title: '✅ Offer Submitted!',
        body:
            'Your offer of PKR ${_priceController.text.trim()} for "${widget.need.title}" has been sent (Delivery: $deliveryTime)',
        type: 'offer',
        data:
            'offer_submitted|${offerRef.key}|${widget.need.id}|${widget.need.title}|$buyerId|${widget.need.authorName}|$deliveryTime|${_priceController.text.trim()}',
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      final chatService = ChatService();

      await chatService.sendMessage(
        receiverId: buyerId,
        receiverName: widget.need.authorName.isNotEmpty
            ? widget.need.authorName
            : 'Buyer',
        needId: widget.need.id,
        needTitle: widget.need.title,
        content:
            '💰 Offer: PKR ${_priceController.text.trim()}\n⏱️ Delivery: $deliveryTime\n\n${_messageController.text.trim()}',
        type: 'offer',
        offerId: offerRef.key,
        offerStatus: 'pending',
        chatDisabled: true,
      );

      if (!mounted) return;

      _showSuccess('Offer submitted successfully! 🎉');

      Navigator.pop(context);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            needId: widget.need.id,
            needTitle: widget.need.title,
            otherUserId: buyerId,
            otherUserName: widget.need.authorName,
            initialOfferId: offerRef.key,
          ),
        ),
      );
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showError('Error: ${e.toString()}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.urgentHigh,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.accent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.surface : Colors.white;
    // Keyboard height — so the sheet lifts above the keyboard instead of
    // letting it cover the Submit button.
    final double keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // Cap height so the sheet never exceeds the screen (respects SafeArea
      // via the extra bottom padding on the scroll view).
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + keyboardInset,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                height: 5,
                width: 44,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Submit an Offer',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'For: ${widget.need.title}',
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Your Price (PKR)',
                      prefixIcon: const Icon(Icons.currency_rupee_rounded),
                      hintText: 'e.g. 5000',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Please enter a price';
                      }
                      final price = double.tryParse(v);
                      if (price == null || price <= 0) {
                        return 'Price must be greater than 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedDelivery,
                    dropdownColor: bgColor,
                    style: TextStyle(color: c.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Delivery Time',
                      prefixIcon: Icon(Icons.schedule_rounded),
                    ),
                    items: _deliveryOptions.map((option) {
                      return DropdownMenuItem(
                        value: option,
                        child: Text(option),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedDelivery = value!;
                        _showCustomDelivery = (value == 'Custom');
                        if (!_showCustomDelivery) {
                          _customDeliveryController.clear();
                        }
                      });
                    },
                    validator: (v) {
                      if (v == 'Custom') {
                        final custom = _customDeliveryController.text.trim();
                        if (custom.isEmpty) {
                          return 'Please enter delivery time';
                        }
                      }
                      return null;
                    },
                  ),
                  if (_showCustomDelivery) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _customDeliveryController,
                      style: TextStyle(color: c.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Enter Custom Delivery Time',
                        hintText: 'e.g. 5 business days',
                        prefixIcon: Icon(Icons.edit_rounded),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _messageController,
                    maxLines: 3,
                    style: TextStyle(
                      color: c.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Message (Optional)',
                      hintText: 'Why are you the best fit?',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _isSubmitting ? null : _submitOffer,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Submit Offer',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
