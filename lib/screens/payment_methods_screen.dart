import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  // Pure world currencies matrix setup
  String _selectedCurrency = 'USD';
  final List<Map<String, String>> _globalCurrencies = [
    {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar'},
    {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
    {'code': 'GBP', 'symbol': '£', 'name': 'British Pound'},
    {'code': 'PKR', 'symbol': 'Rs.', 'name': 'Pakistani Rupee'},
    {'code': 'INR', 'symbol': '₹', 'name': 'Indian Rupee'},
    {'code': 'AED', 'symbol': 'AED', 'name': 'UAE Dirham'},
    {'code': 'SAR', 'symbol': 'SAR', 'name': 'Saudi Riyal'},
    {'code': 'CAD', 'symbol': 'C\$', 'name': 'Canadian Dollar'},
    {'code': 'AUD', 'symbol': 'A\$', 'name': 'Australian Dollar'},
    {'code': 'CNY', 'symbol': '¥', 'name': 'Chinese Yuan'},
    {'code': 'JPY', 'symbol': '¥', 'name': 'Japanese Yen'},
  ];

  // Global Bank Database Simulation Vectors
  final List<String> _localBanksList = [
    'HBL (Habib Bank Limited)',
    'UBL (United Bank Limited)',
    'Meezan Bank',
    'Bank Alfalah',
    'State Bank of India (SBI)',
    'HDFC Bank',
    'Chase Bank (US)',
    'Bank of America',
    'Barclays (UK)',
    'Deutsche Bank',
  ];

  final List<String> _foreignPlatformsList = [
    'PayPal Global Account',
    'Payoneer International Wallet',
    'Stripe Connect Gateway'
  ];

  // State Management For User Wallets
  double _rawWalletFunds = 250.00; // Base baseline in USD
  final List<Map<String, String>> _activeConnectedNodes = [];

  // Form Parameters Controls
  final _bankValidationKey = GlobalKey<FormState>();
  final _accountNumberInput = TextEditingController();
  final _accountHolderInput = TextEditingController();

  String? _chosenBankName;
  String? _chosenForeignPlatform;
  bool _isConnectingLocalBank = true; // Toggle matrix indicator

  @override
  void dispose() {
    _accountNumberInput.dispose();
    _accountHolderInput.dispose();
    super.dispose();
  }

  // 🚨 REAL WORLD SIMULATION VALIDATION ENGINE
  void _executeSecureFinancialAuthentication() {
    if (!(_bankValidationKey.currentState?.validate() ?? false)) return;

    final String accountId = _accountNumberInput.text.trim();
    final String holderName = _accountHolderInput.text.trim();
    final String chosenPlatform = _isConnectingLocalBank
        ? (_chosenBankName ?? '')
        : (_chosenForeignPlatform ?? '');

    if (chosenPlatform.isEmpty) {
      _triggerAlertToast(
          '⚠️ Please select your bank or payment platform first.',
          AppColors.urgentMedium);
      return;
    }

    // 🔐 AUTHENTICATION RULES MATRIX:
    // Simulated real-time API verification. If the digits look fake/short, it fails instantly!
    bool doesAccountExistInRealWorld = true;

    if (_isConnectingLocalBank) {
      // Real banks require minimum 9 to 16 structured digit accounts
      if (accountId.length < 9 || !RegExp(r'^[0-9]+$').hasMatch(accountId)) {
        doesAccountExistInRealWorld = false;
      }
    } else {
      // International platforms (PayPal/Payoneer) require strict valid registered email strings
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+').hasMatch(accountId)) {
        doesAccountExistInRealWorld = false;
      }
    }

    if (!doesAccountExistInRealWorld) {
      _triggerAlertToast(
          '❌ Verification Failed: This account does not exist or wrong details entered! Please check again.',
          AppColors.urgentHigh);
      return;
    }

    // If Authenticated Successfully:
    setState(() {
      _activeConnectedNodes.add({
        'platform': chosenPlatform,
        'account': accountId,
        'holder': holderName,
        'category':
            _isConnectingLocalBank ? 'Local Bank' : 'International Platform'
      });
    });

    _accountNumberInput.clear();
    _accountHolderInput.clear();
    Navigator.pop(context);

    _triggerAlertToast(
        '🎉 Account verified and linked successfully!', AppColors.primary);
  }

  void _triggerAlertToast(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: bg,
          behavior: SnackBarBehavior.floating),
    );
  }

  void _openAddDetailsSheet(bool isLocal) {
    setState(() {
      _isConnectingLocalBank = isLocal;
      _chosenBankName = null;
      _chosenForeignPlatform = null;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Form(
              key: _bankValidationKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      isLocal
                          ? 'ENTER YOUR BANK DETAILS'
                          : 'ENTER FOREIGN BANK PLATFORM DETAILS',
                      style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  // 🏦 Dropdown Matrix Selector
                  if (isLocal) ...[
                    DropdownButtonFormField<String>(
                      dropdownColor: AppColors.surface,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                          labelText: 'Select Your Bank Name'),
                      items: _localBanksList
                          .map((bank) =>
                              DropdownMenuItem(value: bank, child: Text(bank)))
                          .toList(),
                      onChanged: (v) =>
                          setModalState(() => _chosenBankName = v),
                    ),
                  ] else ...[
                    DropdownButtonFormField<String>(
                      dropdownColor: AppColors.surface,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                          labelText: 'Select Foreign Platform'),
                      items: _foreignPlatformsList
                          .map((plat) =>
                              DropdownMenuItem(value: plat, child: Text(plat)))
                          .toList(),
                      onChanged: (v) =>
                          setModalState(() => _chosenForeignPlatform = v),
                    ),
                  ],
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _accountHolderInput,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration:
                        const InputDecoration(labelText: 'Account Holder Name'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Please enter name' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _accountNumberInput,
                    style: const TextStyle(color: AppColors.textPrimary),
                    keyboardType: isLocal
                        ? TextInputType.number
                        : TextInputType.emailAddress,
                    decoration: InputDecoration(
                        labelText: isLocal
                            ? 'Account Number / IBAN'
                            : 'Registered Account Email Address',
                        hintText: isLocal
                            ? 'Enter actual digits'
                            : 'example@domain.com',
                        hintStyle: const TextStyle(
                            color: AppColors.textTertiary, fontSize: 12)),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Please fill this details field'
                        : null,
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      onPressed: _executeSecureFinancialAuthentication,
                      child: const Text('Verify & Add Account',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic currency conversion logic simulator rates
    double dynamicExchangeRate = 1.0;
    if (_selectedCurrency == 'EUR') dynamicExchangeRate = 0.93;
    if (_selectedCurrency == 'GBP') dynamicExchangeRate = 0.79;
    if (_selectedCurrency == 'PKR') dynamicExchangeRate = 278.0;
    if (_selectedCurrency == 'INR') dynamicExchangeRate = 83.5;
    if (_selectedCurrency == 'AED') dynamicExchangeRate = 3.67;
    if (_selectedCurrency == 'SAR') dynamicExchangeRate = 3.75;
    if (_selectedCurrency == 'CAD') dynamicExchangeRate = 1.37;
    if (_selectedCurrency == 'AUD') dynamicExchangeRate = 1.50;
    if (_selectedCurrency == 'CNY') dynamicExchangeRate = 7.25;
    if (_selectedCurrency == 'JPY') dynamicExchangeRate = 159.0;

    String currentSymbol = _globalCurrencies
            .firstWhere((e) => e['code'] == _selectedCurrency)['symbol'] ??
        '\$';
    double convertedBalance = _rawWalletFunds * dynamicExchangeRate;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          title: const Text('Payment Settings'),
          centerTitle: true,
          backgroundColor: AppColors.surface,
          elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // 💳 YOUR WALLET CONTAINER Card Look Layout
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('YOUR WALLET',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.5)),
                const SizedBox(height: 14),
                Text('$currentSymbol ${convertedBalance.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                const Text(
                    'If you have not added your bank details yet, your money will safely store in this virtual wallet.',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 11, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 🌍 SELECT YOUR CURRENCY Dropdown Component Row
          const Text('SELECT YOUR CURRENCY',
              style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCurrency,
                dropdownColor: AppColors.surface,
                isExpanded: true,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                items: _globalCurrencies.map((curr) {
                  return DropdownMenuItem(
                      value: curr['code'],
                      child: Text('${curr['name']} (${curr['code']})'));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCurrency = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 32),

          // 🏦 VERIFIED ACCOUNTS BANNER MANAGEMENT
          const Text('LINKED FINANCIAL ACCOUNTS',
              style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          if (_activeConnectedNodes.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border)),
              child: const Center(
                  child: Text('No active verified bank account linked yet.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12))),
            )
          ] else ...[
            ..._activeConnectedNodes.map((node) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.3))),
                  child: ListTile(
                    leading: Icon(
                        node['category'] == 'Local Bank'
                            ? Icons.account_balance_rounded
                            : Icons.public_rounded,
                        color: AppColors.primaryLight),
                    title: Text(node['platform'] ?? '',
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    subtitle: Text(
                        'Account ID: ${node['account']}\nHolder: ${node['holder']}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                    trailing: const Icon(Icons.verified_user_rounded,
                        color: Colors.green, size: 20),
                  ),
                )),
          ],
          const SizedBox(height: 32),

          // 🔘 INTERACTIVE ACTION SELECTION UTILITIES BUTTONS GRID
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _openAddDetailsSheet(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border)),
                    child: const Column(
                      children: [
                        Icon(Icons.account_balance_wallet_outlined,
                            color: AppColors.primaryLight),
                        SizedBox(height: 8),
                        Text('Link Local Bank',
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12))
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () => _openAddDetailsSheet(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border)),
                    child: const Column(
                      children: [
                        Icon(Icons.language_rounded,
                            color: AppColors.primaryLight),
                        SizedBox(height: 8),
                        Text('Link Foreign Bank',
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12))
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
