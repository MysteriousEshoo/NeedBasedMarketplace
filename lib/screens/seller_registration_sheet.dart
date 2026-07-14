import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../providers/seller_request_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';

/// Opens the seller registration form as a modal bottom sheet.
/// Returns `true` if a request was successfully submitted.
Future<bool?> showSellerRegistrationSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const SellerRegistrationSheet(),
  );
}

class SellerRegistrationSheet extends StatefulWidget {
  const SellerRegistrationSheet({super.key});

  @override
  State<SellerRegistrationSheet> createState() =>
      _SellerRegistrationSheetState();
}

class _SellerRegistrationSheetState extends State<SellerRegistrationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cnicController = TextEditingController();
  final _cityController = TextEditingController();
  final _descriptionController = TextEditingController();

  static const List<String> _categories = [
    'Electronics',
    'Fashion & Apparel',
    'Home & Furniture',
    'Food & Groceries',
    'Services',
    'Vehicles',
    'Health & Beauty',
    'Other',
  ];

  String? _selectedCategory;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      _fullNameController.text = user.displayName!;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _businessNameController.dispose();
    _phoneController.dispose();
    _cnicController.dispose();
    _cityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      _toast('Please select a business category.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await context.read<SellerRequestProvider>().submitRequest(
            fullName: _fullNameController.text.trim(),
            businessName: _businessNameController.text.trim(),
            phone: _phoneController.text.trim(),
            cnic: _cnicController.text.trim(),
            city: _cityController.text.trim(),
            category: _selectedCategory!,
            description: _descriptionController.text.trim(),
          );

      if (!mounted) return;
      Navigator.pop(context, true);
      _toast('✅ Request submitted! You\'ll be notified once it is reviewed.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _toast('⚠️ Could not submit request. Please try again.');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final Color surface = isDark ? AppColors.surface : Colors.white;
    final Color border = isDark ? AppColors.border : const Color(0xFFE2E8F0);
    final Color textPrimary =
        isDark ? AppColors.textPrimary : const Color(0xFF0F172A);
    final Color textSecondary =
        isDark ? AppColors.textSecondary : const Color(0xFF475569);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.storefront_rounded,
                          color: AppColors.primaryLight, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Become a Seller',
                              style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18)),
                          const SizedBox(height: 2),
                          Text(
                              'Submit your details for approval. Our team will review your request.',
                              style: TextStyle(
                                  color: textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _field(
                  controller: _fullNameController,
                  label: 'Full Name',
                  icon: Icons.person_rounded,
                  textPrimary: textPrimary,
                  border: border,
                ),
                _field(
                  controller: _businessNameController,
                  label: 'Business / Shop Name',
                  icon: Icons.storefront_rounded,
                  textPrimary: textPrimary,
                  border: border,
                ),
                _field(
                  controller: _phoneController,
                  label: 'Phone Number',
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                  textPrimary: textPrimary,
                  border: border,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Phone number is required';
                    }
                    if (v.trim().length < 10) {
                      return 'Enter a valid phone number';
                    }
                    return null;
                  },
                ),
                _field(
                  controller: _cnicController,
                  label: 'CNIC Number',
                  icon: Icons.badge_rounded,
                  keyboardType: TextInputType.number,
                  textPrimary: textPrimary,
                  border: border,
                ),
                _field(
                  controller: _cityController,
                  label: 'City',
                  icon: Icons.location_city_rounded,
                  textPrimary: textPrimary,
                  border: border,
                ),
                _buildCategoryDropdown(textPrimary, textSecondary, border),
                _field(
                  controller: _descriptionController,
                  label: 'What do you sell? (short description)',
                  icon: Icons.description_rounded,
                  maxLines: 3,
                  textPrimary: textPrimary,
                  border: border,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Submit for Approval',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color textPrimary,
    required Color border,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final c = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(color: textPrimary, fontSize: 14),
        validator: validator ??
            (v) => (v == null || v.trim().isEmpty)
                ? '$label is required'
                : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: c.textSecondary),
          prefixIcon: Icon(icon, color: AppColors.primaryLight, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown(
      Color textPrimary, Color textSecondary, Color border) {
    final c = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        value: _selectedCategory,
        isExpanded: true,
        style: TextStyle(color: textPrimary, fontSize: 14),
        dropdownColor:
            Provider.of<ThemeProvider>(context, listen: false).isDarkMode
                ? AppColors.surface
                : Colors.white,
        decoration: InputDecoration(
          labelText: 'Business Category',
          labelStyle: TextStyle(color: c.textSecondary),
          prefixIcon: const Icon(Icons.category_rounded,
              color: AppColors.primaryLight, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
        ),
        items: _categories
            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
            .toList(),
        onChanged: (v) => setState(() => _selectedCategory = v),
        validator: (v) => v == null ? 'Please select a category' : null,
      ),
    );
  }
}
