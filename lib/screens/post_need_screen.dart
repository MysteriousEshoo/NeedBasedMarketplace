import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/need_model.dart';
import '../services/history_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../widgets/brand_logo.dart';
import '../widgets/primary_loading_button.dart';
import '../widgets/upload_progress_dialog.dart';
import 'premium_screen.dart';

enum _PostSuccessAction { ok, premium }

class PostNeedScreen extends StatefulWidget {
  const PostNeedScreen({super.key});

  @override
  State<PostNeedScreen> createState() => _PostNeedScreenState();
}

class _PostNeedScreenState extends State<PostNeedScreen> {
  static const int _totalSteps = 3;

  final _pageController = PageController();
  int _currentStep = 0;
  bool _isPublishing = false;
  DatabaseReference? _lastPostedNeedRef;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();
  final _companyController = TextEditingController();

  String? _selectedCategory;
  Urgency _selectedUrgency = Urgency.medium;

  String? _selectedCompany;
  bool _showCompanyField = false;

  ProductCondition? _selectedCondition;
  PaymentMethod? _selectedPaymentMethod;
  String? _selectedLocation;

  @override
  void dispose() {
    _pageController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  bool _validateStep1() {
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
      if (_selectedCompany == 'Others') {
        if (_companyController.text.trim().isEmpty) {
          _showError('Please enter the company name');
          return false;
        }
      }
    }
    return true;
  }

  bool _validateStep2() {
    if (_descriptionController.text.trim().isEmpty) {
      _showError('Please enter a description');
      return false;
    }
    final budgetText = _budgetController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (budgetText.isEmpty) {
      _showError('Please enter a budget amount');
      return false;
    }
    final budget = int.tryParse(budgetText) ?? 0;
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

  void _next() {
    bool canProceed = false;

    if (_currentStep == 0) {
      canProceed = _validateStep1();
    } else if (_currentStep == 1) {
      canProceed = _validateStep2();
    } else {
      canProceed = true;
    }

    if (!canProceed) return;

    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _publish();
    }
  }

  void _back() {
    if (_currentStep == 0) {
      Navigator.of(context).pop();
    } else {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _publish() async {
    if (_isPublishing) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isPublishing = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showError('Please login to post a need');
        setState(() => _isPublishing = false);
        return;
      }

      String userName = 'Anonymous';
      if (currentUser.displayName != null &&
          currentUser.displayName!.isNotEmpty) {
        userName = currentUser.displayName!;
      } else if (currentUser.email != null) {
        userName = currentUser.email!.split('@').first;
      }

      String? companyName;
      if (_selectedCategory == 'Mobile Phone') {
        if (_selectedCompany == 'Others') {
          companyName = _companyController.text.trim();
        } else {
          companyName = _selectedCompany;
        }
      }

      final Map<String, dynamic> needData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory ?? 'General',
        'budget': int.tryParse(
                _budgetController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
            0,
        'urgency': _selectedUrgency.toString().split('.').last,
        'authorId': currentUser.uid,
        'authorName': userName,
        'timestamp': ServerValue.timestamp,
        'offers': 0,
        'isPremium': false,
        'condition': _selectedCondition?.label ?? 'New',
        'paymentMethod': _selectedPaymentMethod?.label ?? 'Cash',
        'location': _selectedLocation ?? 'Not specified',
        'userId': currentUser.uid,
        'userName': userName,
      };

      if (_selectedCategory == 'Mobile Phone') {
        needData['company'] = companyName ?? '';
      }

      final DatabaseReference dbRef =
          FirebaseDatabase.instance.ref().child('needs');
      final DatabaseReference newNeedRef = _lastPostedNeedRef ??= dbRef.push();
      needData['id'] = newNeedRef.key;
      // 📶 0→100% loading bar tied to the actual network write — the bar
      // completes only when the server confirms, so speed depends on network.
      final publishTask =
          newNeedRef.set(needData).timeout(const Duration(seconds: 25));
      await UploadProgressDialog.run(context, task: publishTask);
      await HistoryService.log(
        type: HistoryService.typeNeedPosted,
        title: _titleController.text.trim(),
        subtitle: _selectedCategory ?? 'General',
        refId: newNeedRef.key,
      );

      if (!mounted) return;
      setState(() => _isPublishing = false);

      await _showSuccessPopup();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPublishing = false);
      if (e is TimeoutException && _lastPostedNeedRef != null) {
        unawaited(
          _lastPostedNeedRef!.remove().then<void>(
                (_) {},
                onError: (_) {},
              ),
        );
      }
      final shouldRetry = await _showFailurePopup(e);
      if (shouldRetry && mounted) {
        await _publish();
      }
    }
  }

  Future<void> _showSuccessPopup() async {
    final action = await showDialog<_PostSuccessAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final c = dialogContext.palette;
        return Dialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 72,
                    width: 72,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.accent,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Your Need Is Posted!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'It is live now and will update for buyers and sellers in real time.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.workspace_premium_rounded),
                      label: const Text('Upgrade to Premium'),
                      onPressed: () => Navigator.of(dialogContext).pop(
                        _PostSuccessAction.premium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text(
                        'OK',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(
                        _PostSuccessAction.ok,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    if (action == _PostSuccessAction.premium) {
      await _navigateToPremium();
    } else if (action == _PostSuccessAction.ok) {
      Navigator.of(context).pop(true);
    }
  }

  Future<bool> _showFailurePopup(Object error) async {
    final shouldRetry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final c = dialogContext.palette;
        return Dialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 68,
                    width: 68,
                    decoration: BoxDecoration(
                      color: AppColors.urgentHigh.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_off_rounded,
                      color: AppColors.urgentHigh,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Need Was Not Posted',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _friendlyPublishError(error),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Keep Editing'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text(
                        'Try Again',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    return shouldRetry ?? false;
  }

  String _friendlyPublishError(Object error) {
    if (error is FirebaseException) {
      switch (error.code.toLowerCase()) {
        case 'permission-denied':
          return 'Firebase did not allow this post. Please sign in again or check your database rules.';
        case 'network-request-failed':
        case 'network-error':
        case 'disconnected':
        case 'unavailable':
          return 'Please check your internet connection, then try again. Your entered details are still here.';
      }
    }

    final message = error.toString().toLowerCase();
    if (message.contains('network') ||
        message.contains('socket') ||
        message.contains('host lookup') ||
        message.contains('disconnected') ||
        message.contains('timeout')) {
      return 'Please check your internet connection, then try again. Your entered details are still here.';
    }
    return 'Firebase could not save this need. Please try again; your entered details have not been cleared.';
  }

  Future<void> _navigateToPremium() async {
    final result = await Navigator.of(context).push<PremiumPurchaseResult>(
      MaterialPageRoute(
        builder: (_) => PremiumScreen(
          needId: _lastPostedNeedRef?.key,
          needTitle: _titleController.text.trim(),
        ),
      ),
    );

    if (!mounted) return;

    if (result != null && _lastPostedNeedRef != null) {
      try {
        await _lastPostedNeedRef!.update(result.toNeedUpdate());
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Premium activated, but need update failed: $e'),
            backgroundColor: AppColors.urgentHigh,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _back,
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandLogo(size: 30, borderRadius: 7),
            SizedBox(width: 10),
            Flexible(child: Text('Post a Need')),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressIndicator(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentStep = i),
                children: [
                  _buildStepOne(),
                  _buildStepTwo(),
                  _buildStepThree(),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final c = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index < _totalSteps - 1 ? 8 : 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 6,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : c.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepOne() {
    return _StepScaffold(
      step: 'Step 1 of 3',
      title: 'What do you need?',
      subtitle: 'Choose a category and provide basic details.',
      children: [
        const _FieldLabel('Need title'),
        TextField(
          controller: _titleController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'e.g. Flutter developer for a delivery app',
          ),
        ),
        const SizedBox(height: 22),
        const _FieldLabel('Category'),
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
          const SizedBox(height: 22),
          const _FieldLabel('Company'),
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
              if (v != 'Others') {
                _companyController.clear();
              }
            }),
          ),
          if (_selectedCompany == 'Others') ...[
            const SizedBox(height: 16),
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
      ],
    );
  }

  Widget _buildStepTwo() {
    final c = context.palette;
    return _StepScaffold(
      step: 'Step 2 of 3',
      title: 'Add the details',
      subtitle: 'Describe your need and set expectations.',
      children: [
        const _FieldLabel('Description'),
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border, width: 1.4),
          ),
          child: Column(
            children: [
              _buildFakeToolbar(),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: TextField(
                  controller: _descriptionController,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Share scope, expectations, location, timeline…',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _FieldLabel('Estimated budget'),
        TextField(
          controller: _budgetController,
          keyboardType: TextInputType.number,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
          decoration: InputDecoration(
            hintText: '0',
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Container(
                alignment: Alignment.center,
                width: 44,
                child: const Text(
                  'PKR',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
          ),
        ),
        const SizedBox(height: 22),
        const _FieldLabel('Condition'),
        Row(
          children: [
            Expanded(
              child: _buildConditionCard(
                ProductCondition.new_,
                'New',
                Icons.check_circle_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildConditionCard(
                ProductCondition.used,
                'Used',
                Icons.history_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const _FieldLabel('Payment Method'),
        Row(
          children: [
            Expanded(
              child: _buildPaymentCard(
                PaymentMethod.cash,
                'Cash',
                Icons.money_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPaymentCard(
                PaymentMethod.onlineDeposit,
                'Online Deposit',
                Icons.account_balance_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const _FieldLabel('Location'),
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
              .map((loc) => DropdownMenuItem(value: loc, child: Text(loc)))
              .toList(),
          onChanged: (v) => setState(() => _selectedLocation = v),
        ),
      ],
    );
  }

  Widget _buildConditionCard(
      ProductCondition condition, String label, IconData icon) {
    final c = context.palette;
    final isSelected = _selectedCondition == condition;
    return GestureDetector(
      onTap: () => setState(() => _selectedCondition = condition),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : c.border,
            width: isSelected ? 2 : 1.4,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : c.textSecondary,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : c.textSecondary,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard(PaymentMethod method, String label, IconData icon) {
    final c = context.palette;
    final isSelected = _selectedPaymentMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : c.border,
            width: isSelected ? 2 : 1.4,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : c.textSecondary,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : c.textSecondary,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepThree() {
    return _StepScaffold(
      step: 'Step 3 of 3',
      title: 'How urgent is it?',
      subtitle: 'This helps providers prioritise the right requests.',
      children: [
        ...Urgency.values.map(
          (u) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _UrgencyCard(
              urgency: u,
              selected: _selectedUrgency == u,
              onTap: () => setState(() => _selectedUrgency = u),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFakeToolbar() {
    final c = context.palette;
    const icons = [
      Icons.format_bold_rounded,
      Icons.format_italic_rounded,
      Icons.format_list_bulleted_rounded,
      Icons.link_rounded,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: icons
            .map(
              (i) => Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Icon(i, size: 20, color: c.textSecondary),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildBottomBar() {
    final c = context.palette;
    final isLast = _currentStep == _totalSteps - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentStep > 0) ...[
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: _back,
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 3,
              child: PrimaryLoadingButton(
                label: isLast ? 'Publish Need' : 'Continue',
                icon: isLast ? Icons.rocket_launch_rounded : null,
                isLoading: _isPublishing,
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String step;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step,
            style: textTheme.labelLarge?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(title, style: textTheme.headlineMedium?.copyWith(fontSize: 26)),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: textTheme.bodyLarge?.copyWith(
              color: c.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          ...children,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: c.textPrimary,
        ),
      ),
    );
  }
}

class _UrgencyCard extends StatelessWidget {
  const _UrgencyCard({
    required this.urgency,
    required this.selected,
    required this.onTap,
  });

  final Urgency urgency;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? urgency.softColor : c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? urgency.color : c.border,
            width: selected ? 1.8 : 1.4,
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: urgency.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.local_fire_department_rounded,
                color: urgency.color,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    urgency.shortLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitleFor(urgency),
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedScale(
              scale: selected ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              child: Icon(Icons.check_circle_rounded, color: urgency.color),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitleFor(Urgency u) {
    switch (u) {
      case Urgency.low:
        return 'Flexible timeline, no rush';
      case Urgency.medium:
        return 'Needed within a few days';
      case Urgency.high:
        return 'Needed as soon as possible';
    }
  }
}
