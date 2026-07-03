import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/need_model.dart' as legacy;
import '../models/offer_model.dart';
import '../theme/app_colors.dart';

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
  final _extraNotesController = TextEditingController(); // ✅ NEW
  bool _isSubmitting = false;

  // ✅ NEW: Delivery Time Options
  final List<String> _deliveryOptions = [
    '24 hours',
    '3 days',
    '1 week',
    '2 weeks',
    '1 month',
    'Custom',
  ];
  String _selectedDelivery = '3 days'; // ✅ NEW
  bool _showCustomDelivery = false; // ✅ NEW
  final _customDeliveryController = TextEditingController(); // ✅ NEW

  @override
  void dispose() {
    _priceController.dispose();
    _messageController.dispose();
    _extraNotesController.dispose();
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

      // Get seller name
      String sellerName = 'Anonymous';
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        sellerName = user.displayName!;
      } else if (user.email != null) {
        sellerName = user.email!.split('@').first;
      }

      // ✅ Get delivery time
      String deliveryTime = _selectedDelivery;
      if (_selectedDelivery == 'Custom') {
        deliveryTime = _customDeliveryController.text.trim();
        if (deliveryTime.isEmpty) {
          _showError('Please enter custom delivery time');
          setState(() => _isSubmitting = false);
          return;
        }
      }

      // ✅ Create offer with new fields
      final offer = OfferModel(
        id: '',
        needId: widget.need.id,
        sellerId: user.uid,
        sellerName: sellerName,
        offeredPrice: double.parse(_priceController.text.trim()),
        message: _messageController.text.trim(),
        createdAt: DateTime.now(),
        status: 'pending',
        deliveryTime: deliveryTime, // ✅ NEW
        extraNotes: _extraNotesController.text.trim(), // ✅ NEW
      );

      // ✅ Save to Realtime Database
      final offerRef = FirebaseDatabase.instance
          .ref()
          .child('offers')
          .child(widget.need.id)
          .push();

      await offerRef.set(offer.toMap());

      // ✅ Update offer count on need
      final needRef = FirebaseDatabase.instance
          .ref()
          .child('needs')
          .child(widget.need.id)
          .child('offers');

      await needRef.set(widget.need.offers + 1);

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      _showSuccess('Offer submitted successfully! 🎉');
      Navigator.pop(context);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.surface : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                height: 5,
                width: 44,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            const Text(
              'Submit an Offer',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              'For: ${widget.need.title}',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Price
                  TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
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

                  // ✅ NEW: Delivery Time Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedDelivery,
                    dropdownColor: bgColor,
                    style: const TextStyle(color: AppColors.textPrimary),
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
                  ),

                  // ✅ NEW: Custom Delivery TextField
                  if (_showCustomDelivery) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _customDeliveryController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Enter Custom Delivery Time',
                        hintText: 'e.g. 5 business days',
                        prefixIcon: Icon(Icons.edit_rounded),
                      ),
                      validator: (v) {
                        if (_showCustomDelivery && (v == null || v.isEmpty)) {
                          return 'Please enter delivery time';
                        }
                        return null;
                      },
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Message
                  TextFormField(
                    controller: _messageController,
                    maxLines: 3,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Message (Optional)',
                      hintText: 'Why are you the best fit?',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ✅ NEW: Extra Notes
                  TextFormField(
                    controller: _extraNotesController,
                    maxLines: 2,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Extra Notes (Optional)',
                      hintText: 'Any additional details...',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
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
