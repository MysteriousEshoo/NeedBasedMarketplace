import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';

import '../models/need_model.dart';
import '../theme/app_colors.dart';
import '../providers/theme_provider.dart';
import '../widgets/primary_loading_button.dart';

/// Full-screen editor for a need the current user owns.
///
/// Prefills every field from the live `needs/{id}` node in Realtime Database
/// (not just the possibly-partial [Need] passed in), then writes changes back
/// with `update()` so untouched fields — offers, timestamp, isPremium — are
/// preserved. On success it returns the updated [Need] to the caller.
class EditNeedScreen extends StatefulWidget {
  const EditNeedScreen({super.key, required this.need});

  final Need need;

  @override
  State<EditNeedScreen> createState() => _EditNeedScreenState();
}

class _EditNeedScreenState extends State<EditNeedScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();
  final _companyController = TextEditingController();

  String? _selectedCategory;
  String? _selectedCompany;
  bool _showCompanyField = false;
  Urgency _selectedUrgency = Urgency.medium;
  ProductCondition? _selectedCondition;
  PaymentMethod? _selectedPaymentMethod;
  String? _selectedLocation;

  // Preserved (non-editable) fields carried through to the returned Need.
  int _offers = 0;
  String _authorName = '';
  String? _authorId;
  bool _isPremium = false;
  String? _userId;
  String? _userName;

  bool _loading = true;
  bool _saving = false;

  DatabaseReference get _needRef =>
      FirebaseDatabase.instance.ref().child('needs').child(widget.need.id);

  @override
  void initState() {
    super.initState();
    _loadNeed();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  Future<void> _loadNeed() async {
    try {
      final snapshot = await _needRef.get();
      final Map<String, dynamic> data = snapshot.exists && snapshot.value is Map
          ? Map<String, dynamic>.from(snapshot.value as Map)
          : <String, dynamic>{};

      // Fall back to the passed-in Need when the live node is missing a field.
      _titleController.text = (data['title'] ?? widget.need.title).toString();
      _descriptionController.text =
          (data['description'] ?? widget.need.description).toString();
      _budgetController.text =
          (data['budget'] ?? widget.need.budget).toString();

      _selectedCategory = (data['category'] ?? widget.need.category).toString();
      if (!MockData.categories.contains(_selectedCategory)) {
        _selectedCategory = null;
      }

      _selectedUrgency = _parseUrgency(data['urgency']);
      _selectedCondition = _parseCondition(
          (data['condition'] ?? widget.need.condition?.label)?.toString());
      _selectedPaymentMethod = _parsePayment(
          (data['paymentMethod'] ?? widget.need.paymentMethod?.label)
              ?.toString());

      final loc = (data['location'] ?? widget.need.location)?.toString();
      if (loc != null && loc.isNotEmpty && loc != 'Not specified') {
        _selectedLocation =
            MockData.locations.contains(loc) ? loc : 'Other';
      }

      // Company only applies to the Mobile Phone category.
      _showCompanyField = _selectedCategory == 'Mobile Phone';
      final company =
          (data['company'] ?? widget.need.companyName)?.toString() ?? '';
      if (_showCompanyField && company.isNotEmpty) {
        if (MockData.mobileCompanies.contains(company)) {
          _selectedCompany = company;
        } else {
          _selectedCompany = 'Others';
          _companyController.text = company;
        }
      }

      // Preserve untouched fields.
      _offers = (data['offers'] ?? widget.need.offers) as int? ?? 0;
      _authorName = (data['authorName'] ?? widget.need.authorName).toString();
      _authorId = (data['authorId'] ?? widget.need.authorId)?.toString();
      _isPremium = (data['isPremium'] ?? widget.need.isPremium) == true;
      _userId = (data['userId'] ?? widget.need.userId)?.toString();
      _userName = (data['userName'] ?? widget.need.userName)?.toString();
    } catch (_) {
      // Prefill from the passed-in Need if the read fails.
      _titleController.text = widget.need.title;
      _descriptionController.text = widget.need.description;
      _budgetController.text = widget.need.budget.toString();
      _selectedCategory = MockData.categories.contains(widget.need.category)
          ? widget.need.category
          : null;
      _selectedUrgency = widget.need.urgency;
      _selectedCondition = widget.need.condition;
      _selectedPaymentMethod = widget.need.paymentMethod;
      _offers = widget.need.offers;
      _authorName = widget.need.authorName;
      _authorId = widget.need.authorId;
      _isPremium = widget.need.isPremium;
      _userId = widget.need.userId;
      _userName = widget.need.userName;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Urgency _parseUrgency(dynamic value) {
    switch (value?.toString()) {
      case 'high':
        return Urgency.high;
      case 'low':
        return Urgency.low;
      case 'medium':
        return Urgency.medium;
      default:
        return widget.need.urgency;
    }
  }

  ProductCondition? _parseCondition(String? label) {
    if (label == 'Used') return ProductCondition.used;
    if (label == 'New') return ProductCondition.new_;
    return null;
  }

  PaymentMethod? _parsePayment(String? label) {
    if (label == 'Online Deposit') return PaymentMethod.onlineDeposit;
    if (label == 'Cash') return PaymentMethod.cash;
    return null;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.urgentHigh,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _validate() {
    if (_titleController.text.trim().isEmpty) {
      _showError('Please enter a need title');
      return false;
    }
    if (_selectedCategory == null) {
      _showError('Please select a category');
      return false;
    }
    if (_selectedCategory == 'Mobile Phone') {
      if (_selectedCompany == null) {
        _showError('Please select a company');
        return false;
      }
      if (_selectedCompany == 'Others' &&
          _companyController.text.trim().isEmpty) {
        _showError('Please enter the company name');
        return false;
      }
    }
    if (_descriptionController.text.trim().isEmpty) {
      _showError('Please enter a description');
      return false;
    }
    final budget =
        int.tryParse(_budgetController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
            0;
    if (budget <= 0) {
      _showError('Budget must be greater than 0');
      return false;
    }
    if (_selectedCondition == null) {
      _showError('Please select condition (New/Used)');
      return false;
    }
    if (_selectedPaymentMethod == null) {
      _showError('Please select a payment method');
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    // Guard: only the owner can edit.
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (_authorId != null &&
        currentUserId != null &&
        _authorId != currentUserId) {
      _showError('You can only edit your own needs.');
      return;
    }

    if (!_validate()) return;

    setState(() => _saving = true);

    final budget =
        int.tryParse(_budgetController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
            0;
    final isMobile = _selectedCategory == 'Mobile Phone';
    String? company;
    if (isMobile) {
      company = _selectedCompany == 'Others'
          ? _companyController.text.trim()
          : _selectedCompany;
    }

    final Map<String, dynamic> updates = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'category': _selectedCategory,
      'budget': budget,
      'urgency': _selectedUrgency.name,
      'condition': _selectedCondition!.label,
      'paymentMethod': _selectedPaymentMethod!.label,
      'location': _selectedLocation ?? 'Not specified',
      // Remove the company field when the category is no longer Mobile Phone.
      'company': isMobile ? (company ?? '') : null,
      'lastEditedAt': ServerValue.timestamp,
    };

    try {
      await _needRef.update(updates);

      if (!mounted) return;
      final updatedNeed = Need(
        id: widget.need.id,
        title: updates['title'] as String,
        description: updates['description'] as String,
        category: _selectedCategory ?? 'General',
        budget: budget,
        timeElapsed: widget.need.timeElapsed,
        urgency: _selectedUrgency,
        authorName: _authorName,
        offers: _offers,
        companyName: isMobile ? company : null,
        condition: _selectedCondition,
        paymentMethod: _selectedPaymentMethod,
        location: _selectedLocation,
        authorId: _authorId,
        isPremium: _isPremium,
        userId: _userId,
        userName: _userName,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Need updated successfully'),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(updatedNeed);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError('Failed to update: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final Color bg = isDark ? AppColors.background : const Color(0xFFF1F5F9);
    final Color surface = isDark ? AppColors.surface : Colors.white;
    final Color border = isDark ? AppColors.border : const Color(0xFFE2E8F0);
    final Color textPrimary =
        isDark ? AppColors.textPrimary : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        iconTheme: IconThemeData(color: textPrimary),
        title: Text('Edit Need',
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700)),
      ),
      bottomNavigationBar: _loading
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              decoration: BoxDecoration(
                color: surface,
                border: Border(top: BorderSide(color: border)),
              ),
              child: SafeArea(
                top: false,
                child: PrimaryLoadingButton(
                  label: 'Save Changes',
                  icon: Icons.check_rounded,
                  isLoading: _saving,
                  onPressed: _save,
                ),
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                _label('Need title', textPrimary),
                TextField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Flutter developer for a delivery app',
                  ),
                ),
                const SizedBox(height: 20),
                _label('Category', textPrimary),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  hint: const Text('Choose a category'),
                  borderRadius: BorderRadius.circular(16),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: MockData.categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _selectedCategory = v;
                    if (v != 'Mobile Phone') {
                      _selectedCompany = null;
                      _showCompanyField = false;
                      _companyController.clear();
                    } else {
                      _showCompanyField = true;
                    }
                  }),
                ),
                if (_showCompanyField) ...[
                  const SizedBox(height: 20),
                  _label('Company', textPrimary),
                  DropdownButtonFormField<String>(
                    value: _selectedCompany,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    hint: const Text('Select a company'),
                    borderRadius: BorderRadius.circular(16),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.business_rounded),
                    ),
                    items: MockData.mobileCompanies
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _selectedCompany = v;
                      if (v != 'Others') _companyController.clear();
                    }),
                  ),
                  if (_selectedCompany == 'Others') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _companyController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Enter company name',
                        prefixIcon: Icon(Icons.edit_rounded),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 20),
                _label('Description', textPrimary),
                TextField(
                  controller: _descriptionController,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Share scope, expectations, location, timeline…',
                  ),
                ),
                const SizedBox(height: 20),
                _label('Estimated budget (PKR)', textPrimary),
                TextField(
                  controller: _budgetController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 18),
                  decoration: const InputDecoration(
                    hintText: '0',
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(left: 16, right: 8),
                      child: Text('PKR',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15)),
                    ),
                    prefixIconConstraints:
                        BoxConstraints(minWidth: 0, minHeight: 0),
                  ),
                ),
                const SizedBox(height: 20),
                _label('Condition', textPrimary),
                DropdownButtonFormField<ProductCondition>(
                  value: _selectedCondition,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  hint: const Text('Select condition'),
                  borderRadius: BorderRadius.circular(16),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.verified_rounded),
                  ),
                  items: ProductCondition.values
                      .map((c) =>
                          DropdownMenuItem(value: c, child: Text(c.label)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCondition = v),
                ),
                const SizedBox(height: 20),
                _label('Payment method', textPrimary),
                DropdownButtonFormField<PaymentMethod>(
                  value: _selectedPaymentMethod,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  hint: const Text('Select payment method'),
                  borderRadius: BorderRadius.circular(16),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.payments_rounded),
                  ),
                  items: PaymentMethod.values
                      .map((p) =>
                          DropdownMenuItem(value: p, child: Text(p.label)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedPaymentMethod = v),
                ),
                const SizedBox(height: 20),
                _label('Location', textPrimary),
                DropdownButtonFormField<String>(
                  value: _selectedLocation,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  hint: const Text('Select a location'),
                  borderRadius: BorderRadius.circular(16),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.location_on_rounded),
                  ),
                  items: MockData.locations
                      .map((loc) =>
                          DropdownMenuItem(value: loc, child: Text(loc)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedLocation = v),
                ),
                const SizedBox(height: 20),
                _label('Urgency', textPrimary),
                DropdownButtonFormField<Urgency>(
                  value: _selectedUrgency,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  borderRadius: BorderRadius.circular(16),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.local_fire_department_rounded),
                  ),
                  items: Urgency.values
                      .map((u) =>
                          DropdownMenuItem(value: u, child: Text(u.label)))
                      .toList(),
                  onChanged: (v) => setState(
                      () => _selectedUrgency = v ?? _selectedUrgency),
                ),
              ],
            ),
    );
  }

  Widget _label(String text, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 2),
        child: Text(text,
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14, color: color)),
      );
}
