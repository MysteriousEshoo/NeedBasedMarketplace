import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../widgets/primary_loading_button.dart';

class PremiumPurchaseResult {
  final String orderId;
  final String planId;
  final String planName;
  final int expiresAtMillis;

  const PremiumPurchaseResult({
    required this.orderId,
    required this.planId,
    required this.planName,
    required this.expiresAtMillis,
  });

  Map<String, Object?> toNeedUpdate() {
    return {
      'isPremium': true,
      'premiumOrderId': orderId,
      'premiumPlanId': planId,
      'premiumPlanName': planName,
      'premiumExpiresAt': expiresAtMillis,
      'premiumActivatedAt': ServerValue.timestamp,
    };
  }
}

class PremiumScreen extends StatefulWidget {
  final String? needId;
  final String? needTitle;

  const PremiumScreen({
    super.key,
    this.needId,
    this.needTitle,
  });

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardHolderController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  final List<_PremiumPlan> _plans = const [
    _PremiumPlan(
      id: 'spotlight_7',
      name: 'Spotlight',
      price: 799,
      days: 7,
      accent: AppColors.accent,
      benefits: [
        'Featured badge on your need',
        'Higher placement for 7 days',
        'More seller attention',
      ],
    ),
    _PremiumPlan(
      id: 'boost_14',
      name: 'Pro Boost',
      price: 1499,
      days: 14,
      accent: AppColors.primary,
      recommended: true,
      benefits: [
        'Priority need placement',
        'Premium badge for 14 days',
        'Faster seller discovery',
      ],
    ),
    _PremiumPlan(
      id: 'elite_30',
      name: 'Elite',
      price: 2499,
      days: 30,
      accent: AppColors.urgentMedium,
      benefits: [
        'Top visibility for 30 days',
        'Premium badge and priority sorting',
        'Best for urgent hiring',
      ],
    ),
  ];

  int _selectedPlanIndex = 1;
  bool _saveCard = true;
  bool _acceptedTerms = false;
  bool _isProcessing = false;

  _PremiumPlan get _selectedPlan => _plans[_selectedPlanIndex];

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _emailController.text = user?.email ?? '';
    final displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      _cardHolderController.text = displayName;
    }
  }

  @override
  void dispose() {
    _cardHolderController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _activatePremium() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_acceptedTerms) {
      _showError('Please accept the premium payment terms');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('Please login to continue');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final plan = _selectedPlan;
      final cleanCard = _digitsOnly(_cardNumberController.text);
      final now = DateTime.now();
      final expiresAt = now.add(Duration(days: plan.days));
      final expiresAtMillis = expiresAt.millisecondsSinceEpoch;
      final cardBrand = _cardBrand(cleanCard);
      final last4 = cleanCard.substring(cleanCard.length - 4);

      final db = FirebaseDatabase.instance.ref();
      final orderRef = db.child('premium_orders').child(user.uid).push();
      final orderId = orderRef.key ?? now.millisecondsSinceEpoch.toString();

      final premiumData = <String, Object?>{
        'orderId': orderId,
        'userId': user.uid,
        'needId': widget.needId,
        'needTitle': widget.needTitle,
        'planId': plan.id,
        'planName': plan.name,
        'amount': plan.price,
        'currency': 'PKR',
        'durationDays': plan.days,
        'status': 'active',
        'createdAt': ServerValue.timestamp,
        'expiresAt': expiresAtMillis,
        'paymentMethod': {
          'type': 'card',
          'brand': cardBrand,
          'last4': last4,
          'cardHolder': _cardHolderController.text.trim(),
          'expiry': _expiryController.text.trim(),
        },
        'billingContact': {
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
        },
      };

      await orderRef.set(premiumData);

      await db.child('premium_users').child(user.uid).update({
        'isPremium': true,
        'activeOrderId': orderId,
        'planId': plan.id,
        'planName': plan.name,
        'premiumExpiresAt': expiresAtMillis,
        'updatedAt': ServerValue.timestamp,
      });

      await db.child('users').child(user.uid).child('premium').update({
        'isPremium': true,
        'activeOrderId': orderId,
        'planId': plan.id,
        'planName': plan.name,
        'expiresAt': expiresAtMillis,
        'updatedAt': ServerValue.timestamp,
      });

      if (_saveCard) {
        await db
            .child('payment_methods')
            .child(user.uid)
            .child('premium_card')
            .set({
          'type': 'card',
          'brand': cardBrand,
          'last4': last4,
          'cardHolder': _cardHolderController.text.trim(),
          'expiry': _expiryController.text.trim(),
          'updatedAt': ServerValue.timestamp,
        });
      }

      if (!mounted) return;
      Navigator.pop(
        context,
        PremiumPurchaseResult(
          orderId: orderId,
          planId: plan.id,
          planName: plan.name,
          expiresAtMillis: expiresAtMillis,
        ),
      );
    } catch (e) {
      _showError('Premium activation failed: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.urgentHigh,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NeedHub Premium'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            children: [
              _HeaderCard(needTitle: widget.needTitle),
              const SizedBox(height: 18),
              const _SectionTitle('Choose a plan'),
              const SizedBox(height: 10),
              ...List.generate(_plans.length, (index) {
                final plan = _plans[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PlanCard(
                    plan: plan,
                    selected: index == _selectedPlanIndex,
                    onTap: () => setState(() => _selectedPlanIndex = index),
                  ),
                );
              }),
              const SizedBox(height: 8),
              const _SectionTitle('Card details'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _cardHolderController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Card holder name',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
                validator: (value) {
                  if ((value ?? '').trim().length < 3) {
                    return 'Enter card holder name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _cardNumberController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(19),
                  _CardNumberFormatter(),
                ],
                decoration: const InputDecoration(
                  labelText: 'Card number',
                  prefixIcon: Icon(Icons.credit_card_rounded),
                ),
                validator: (value) {
                  final digits = _digitsOnly(value ?? '');
                  if (digits.length < 13 || digits.length > 19) {
                    return 'Enter a valid card number';
                  }
                  if (!_passesLuhn(digits)) {
                    return 'Card number is invalid';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _expiryController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                        _ExpiryFormatter(),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Expiry',
                        hintText: 'MM/YY',
                        prefixIcon: Icon(Icons.event_rounded),
                      ),
                      validator: _validateExpiry,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _cvvController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'CVV',
                        prefixIcon: Icon(Icons.lock_rounded),
                      ),
                      validator: (value) {
                        final digits = _digitsOnly(value ?? '');
                        if (digits.length < 3 || digits.length > 4) {
                          return 'Invalid CVV';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _SectionTitle('Billing contact'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_rounded),
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (!text.contains('@') || !text.contains('.')) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
                  LengthLimitingTextInputFormatter(18),
                ],
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  prefixIcon: Icon(Icons.phone_rounded),
                ),
                validator: (value) {
                  final digits = _digitsOnly(value ?? '');
                  if (digits.length < 10) return 'Enter phone number';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _ToggleTile(
                value: _saveCard,
                icon: Icons.account_balance_wallet_rounded,
                title: 'Save card for premium renewals',
                onChanged: (value) => setState(() => _saveCard = value),
              ),
              const SizedBox(height: 10),
              _ToggleTile(
                value: _acceptedTerms,
                icon: Icons.verified_user_rounded,
                title: 'I confirm this premium purchase',
                onChanged: (value) => setState(() => _acceptedTerms = value),
              ),
              const SizedBox(height: 20),
              _CheckoutSummary(plan: _selectedPlan),
              const SizedBox(height: 18),
              PrimaryLoadingButton(
                label: 'Activate Premium',
                icon: Icons.workspace_premium_rounded,
                isLoading: _isProcessing,
                onPressed: _activatePremium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumPlan {
  final String id;
  final String name;
  final int price;
  final int days;
  final Color accent;
  final bool recommended;
  final List<String> benefits;

  const _PremiumPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.days,
    required this.accent,
    required this.benefits,
    this.recommended = false,
  });

  String get formattedPrice {
    final raw = price.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) buffer.write(',');
      buffer.write(raw[i]);
    }
    return 'PKR $buffer';
  }
}

class _HeaderCard extends StatelessWidget {
  final String? needTitle;

  const _HeaderCard({this.needTitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: AppColors.primaryLight,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Boost your need',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  needTitle == null || needTitle!.trim().isEmpty
                      ? 'Make your request stand out to sellers.'
                      : needTitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final _PremiumPlan plan;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? plan.accent.withValues(alpha: 0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? plan.accent : AppColors.border,
            width: selected ? 2 : 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bolt_rounded, color: plan.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    plan.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (plan.recommended)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: plan.accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Recommended',
                      style: TextStyle(
                        color: plan.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${plan.formattedPrice} / ${plan.days} days',
              style: TextStyle(
                color: plan.accent,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            ...plan.benefits.map(
              (benefit) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: plan.accent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        benefit,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final bool value;
  final IconData icon;
  final String title;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.value,
    required this.icon,
    required this.title,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryLight, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Checkbox(
              value: value,
              activeColor: AppColors.accent,
              onChanged: (newValue) => onChanged(newValue ?? false),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutSummary extends StatelessWidget {
  final _PremiumPlan plan;

  const _CheckoutSummary({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_rounded, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${plan.days} days premium visibility',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            plan.formattedPrice,
            style: const TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final text = digits.length <= 2
        ? digits
        : '${digits.substring(0, 2)}/${digits.substring(2)}';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

String _digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

bool _passesLuhn(String digits) {
  var sum = 0;
  var alternate = false;
  for (var i = digits.length - 1; i >= 0; i--) {
    var number = int.parse(digits[i]);
    if (alternate) {
      number *= 2;
      if (number > 9) number -= 9;
    }
    sum += number;
    alternate = !alternate;
  }
  return sum % 10 == 0;
}

String _cardBrand(String digits) {
  if (digits.startsWith('4')) return 'Visa';
  if (digits.startsWith('5')) return 'Mastercard';
  if (digits.startsWith('34') || digits.startsWith('37')) return 'Amex';
  return 'Card';
}

String? _validateExpiry(String? value) {
  final digits = _digitsOnly(value ?? '');
  if (digits.length != 4) return 'Invalid expiry';

  final month = int.tryParse(digits.substring(0, 2)) ?? 0;
  final year = int.tryParse(digits.substring(2, 4)) ?? -1;
  if (month < 1 || month > 12) return 'Invalid month';

  final now = DateTime.now();
  final fullYear = 2000 + year;
  final expiryEnd = DateTime(fullYear, month + 1, 0, 23, 59);
  if (expiryEnd.isBefore(now)) return 'Card expired';

  return null;
}
