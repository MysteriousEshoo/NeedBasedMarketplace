import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../providers/payment_provider.dart';
import '../providers/theme_provider.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  String _selectedCurrency = 'PKR';
  bool _isVerifying = false;

  String? _accountError;
  String? _holderError;

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
    'Stripe Connect Gateway',
  ];

  final _bankValidationKey = GlobalKey<FormState>();
  final _accountNumberInput = TextEditingController();
  final _accountHolderInput = TextEditingController();

  String? _chosenBankName;
  String? _chosenForeignPlatform;
  bool _isConnectingLocalBank = true;

  @override
  void dispose() {
    _accountNumberInput.dispose();
    _accountHolderInput.dispose();
    super.dispose();
  }

  void _showFieldError(String message) {
    setState(() {
      _accountError = message;
    });
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _accountError = null;
        });
      }
    });
  }

  void _showToast(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ✅ DELETE BANK ACCOUNT
  Future<void> _deleteBankAccount(BankAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bank Account'),
        content: Text(
          'Are you sure you want to delete "${account.bankName}" account?\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.urgentHigh),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final paymentProvider =
          Provider.of<PaymentProvider>(context, listen: false);
      final success = await paymentProvider.deleteBankAccount(account.id);

      if (success) {
        _showToast('✅ Bank account deleted successfully!', Colors.green);
      } else {
        _showToast('❌ Failed to delete account.', AppColors.urgentHigh);
      }
    }
  }

  // ✅ SET DEFAULT BANK
  Future<void> _setDefaultBank(BankAccount account) async {
    final paymentProvider =
        Provider.of<PaymentProvider>(context, listen: false);
    final success = await paymentProvider.setDefaultBank(account.id);

    if (success) {
      _showToast('✅ ${account.bankName} set as default!', Colors.green);
    } else {
      _showToast('❌ Failed to set default.', AppColors.urgentHigh);
    }
  }

  // ✅ OTP DIALOG
  void _showOTPDialog({
    required String bankName,
    required String accountNumber,
    required String holderName,
    required bool isLocal,
  }) {
    final TextEditingController otpController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('OTP Verification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please enter the 6-digit OTP sent to your registered mobile number.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Enter OTP',
                hintText: '6-digit code',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final otp = otpController.text.trim();
              if (otp.length != 6) {
                _showToast('Please enter 6-digit OTP', AppColors.urgentMedium);
                return;
              }

              final paymentProvider =
                  Provider.of<PaymentProvider>(context, listen: false);
              final verified = await paymentProvider.verifyOTP(otp);

              if (verified) {
                Navigator.pop(context);
                _showToast('🎉 Account verified and linked successfully!',
                    Colors.green);
                _accountNumberInput.clear();
                _accountHolderInput.clear();
              } else {
                _showToast(
                    '❌ Invalid OTP. Please try again.', AppColors.urgentHigh);
              }
            },
            child: const Text('Verify OTP'),
          ),
        ],
      ),
    );
  }

  // 🔍 VERIFY & LINK BANK
  Future<void> _verifyAndLinkBank() async {
    if (!(_bankValidationKey.currentState?.validate() ?? false)) return;

    final String accountId = _accountNumberInput.text.trim();
    final String holderName = _accountHolderInput.text.trim();
    final String chosenPlatform = _isConnectingLocalBank
        ? (_chosenBankName ?? '')
        : (_chosenForeignPlatform ?? '');

    if (chosenPlatform.isEmpty) {
      _showFieldError('Please select a bank or platform first.');
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final paymentProvider =
          Provider.of<PaymentProvider>(context, listen: false);

      final result = await paymentProvider.verifyBank(
        bankName: chosenPlatform,
        accountNumber: accountId,
        holderName: holderName,
        isLocal: _isConnectingLocalBank,
      );

      if (!mounted) return;
      setState(() => _isVerifying = false);

      if (result.isValid) {
        if (result.requiresOTP) {
          _showOTPDialog(
            bankName: chosenPlatform,
            accountNumber: accountId,
            holderName: holderName,
            isLocal: _isConnectingLocalBank,
          );
          return;
        }

        final saved = await paymentProvider.saveVerifiedBank(
          bankName: chosenPlatform,
          accountNumber: accountId,
          holderName: holderName,
          isLocal: _isConnectingLocalBank,
        );

        if (saved) {
          _showToast(
              '🎉 Account verified and linked successfully!', Colors.green);
          _accountNumberInput.clear();
          _accountHolderInput.clear();
          if (mounted) Navigator.pop(context);
        } else {
          _showFieldError('Failed to save account. Please try again.');
        }
      } else {
        _showFieldError(result.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifying = false);
        _showFieldError('Verification failed. Please try again.');
      }
    }
  }

  void _openAddDetailsSheet(bool isLocal) {
    setState(() {
      _isConnectingLocalBank = isLocal;
      _chosenBankName = null;
      _chosenForeignPlatform = null;
      _accountNumberInput.clear();
      _accountHolderInput.clear();
      _accountError = null;
      _holderError = null;
      _isVerifying = false;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final themeProvider = Provider.of<ThemeProvider>(context);
          final bool isDarkMode = themeProvider.isDarkMode;

          return Container(
            decoration: BoxDecoration(
              color: isDarkMode ? AppColors.surface : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(
                24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Form(
                key: _bankValidationKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        height: 5,
                        width: 44,
                        decoration: BoxDecoration(
                          color: context.palette.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isLocal
                          ? 'VERIFY YOUR BANK ACCOUNT'
                          : 'VERIFY FOREIGN PLATFORM',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isLocal) ...[
                      DropdownButtonFormField<String>(
                        dropdownColor:
                            isDarkMode ? AppColors.surface : Colors.white,
                        style: TextStyle(
                            color: isDarkMode
                                ? AppColors.textPrimary
                                : Colors.black87),
                        decoration: const InputDecoration(
                            labelText: 'Select Your Bank'),
                        items: _localBanksList
                            .map((bank) => DropdownMenuItem(
                                value: bank, child: Text(bank)))
                            .toList(),
                        onChanged: (v) =>
                            setModalState(() => _chosenBankName = v),
                        validator: (v) =>
                            v == null ? 'Please select a bank' : null,
                      ),
                    ] else ...[
                      DropdownButtonFormField<String>(
                        dropdownColor:
                            isDarkMode ? AppColors.surface : Colors.white,
                        style: TextStyle(
                            color: isDarkMode
                                ? AppColors.textPrimary
                                : Colors.black87),
                        decoration:
                            const InputDecoration(labelText: 'Select Platform'),
                        items: _foreignPlatformsList
                            .map((plat) => DropdownMenuItem(
                                value: plat, child: Text(plat)))
                            .toList(),
                        onChanged: (v) =>
                            setModalState(() => _chosenForeignPlatform = v),
                        validator: (v) =>
                            v == null ? 'Please select a platform' : null,
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _accountHolderInput,
                      style: TextStyle(
                          color: isDarkMode
                              ? AppColors.textPrimary
                              : Colors.black87),
                      decoration: InputDecoration(
                        labelText: 'Account Holder Name',
                        errorText: _holderError,
                        errorStyle: const TextStyle(
                          color: AppColors.urgentHigh,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: AppColors.urgentHigh, width: 2),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: AppColors.urgentHigh, width: 2),
                        ),
                      ),
                      onChanged: (v) {
                        if (_holderError != null) {
                          setState(() => _holderError = null);
                        }
                      },
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Please enter name' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _accountNumberInput,
                      style: TextStyle(
                          color: isDarkMode
                              ? AppColors.textPrimary
                              : Colors.black87),
                      keyboardType: isLocal
                          ? TextInputType.number
                          : TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: isLocal
                            ? 'Account Number / IBAN'
                            : 'Registered Email',
                        hintText: isLocal
                            ? 'Enter 9-16 digits'
                            : 'example@domain.com',
                        hintStyle: TextStyle(
                            color: context.palette.textTertiary, fontSize: 12),
                        errorText: _accountError,
                        errorStyle: const TextStyle(
                          color: AppColors.urgentHigh,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: AppColors.urgentHigh, width: 2),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: AppColors.urgentHigh, width: 2),
                        ),
                      ),
                      onChanged: (v) {
                        if (_accountError != null) {
                          setState(() => _accountError = null);
                        }
                      },
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return 'Please enter account details';
                        if (isLocal) {
                          if (!RegExp(r'^[0-9]+$').hasMatch(v)) {
                            return 'Only digits allowed';
                          }
                          if (v.length < 9 || v.length > 16) {
                            return 'Must be 9-16 digits';
                          }
                        } else {
                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(v)) {
                            return 'Enter a valid email';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isVerifying
                              ? context.palette.textTertiary
                              : AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _isVerifying ? null : _verifyAndLinkBank,
                        child: _isVerifying
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Verifying...',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              )
                            : const Text(
                                'Verify & Link Account',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_rounded,
                              color: AppColors.primary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isLocal
                                  ? 'Your bank account will be verified in real-time.'
                                  : 'Your platform account will be verified via email.',
                              style: TextStyle(
                                color: context.palette.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ✅ BUILD BANK ACCOUNT CARD WITH DELETE OPTION
  Widget _buildBankAccountCard(
      BuildContext context, BankAccount account, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: account.isDefault
              ? AppColors.primary
              : (isDarkMode ? AppColors.border : const Color(0xFFE2E8F0)),
          width: account.isDefault ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: account.isLocal
                    ? AppColors.primary.withOpacity(0.1)
                    : AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                account.isLocal
                    ? Icons.account_balance_rounded
                    : Icons.language_rounded,
                color: account.isLocal ? AppColors.primary : AppColors.accent,
                size: 24,
              ),
            ),
            title: Text(
              account.bankName,
              style: TextStyle(
                color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account: ${account.accountNumber}',
                  style: TextStyle(
                    color:
                        isDarkMode ? AppColors.textSecondary : Colors.black54,
                    fontSize: 12,
                  ),
                ),
                if (account.isDefault)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'DEFAULT',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!account.isDefault)
                  IconButton(
                    icon: Icon(
                      Icons.star_border_rounded,
                      color:
                          isDarkMode ? AppColors.textSecondary : Colors.black54,
                      size: 22,
                    ),
                    onPressed: () => _setDefaultBank(account),
                    tooltip: 'Set as default',
                  ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.urgentHigh,
                    size: 22,
                  ),
                  onPressed: () => _deleteBankAccount(account),
                  tooltip: 'Delete account',
                ),
              ],
            ),
          ),
          // Payment option buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showToast(
                          '💰 Payment from ${account.bankName} initiated!',
                          AppColors.primary);
                    },
                    icon: const Icon(Icons.payment_rounded, size: 16),
                    label: Text(
                      account.isLocal ? 'Pay Local' : 'Pay International',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: BorderSide(color: context.palette.border),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showToast('📤 Withdraw to ${account.bankName}',
                          AppColors.accent);
                    },
                    icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                    label: const Text(
                      'Withdraw',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: BorderSide(color: context.palette.border),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final paymentProvider = Provider.of<PaymentProvider>(context);
    final bool isDarkMode = themeProvider.isDarkMode;
    final double balance = paymentProvider.walletBalance;
    final List<BankAccount> banks = paymentProvider.bankAccounts;
    final List<BankAccount> localBanks = paymentProvider.localBanks;
    final List<BankAccount> foreignBanks = paymentProvider.foreignBanks;

    double exchangeRate = 1.0;
    if (_selectedCurrency == 'EUR')
      exchangeRate = 0.93;
    else if (_selectedCurrency == 'GBP')
      exchangeRate = 0.79;
    else if (_selectedCurrency == 'PKR')
      exchangeRate = 278.0;
    else if (_selectedCurrency == 'INR')
      exchangeRate = 83.5;
    else if (_selectedCurrency == 'AED')
      exchangeRate = 3.67;
    else if (_selectedCurrency == 'SAR')
      exchangeRate = 3.75;
    else if (_selectedCurrency == 'CAD')
      exchangeRate = 1.37;
    else if (_selectedCurrency == 'AUD')
      exchangeRate = 1.50;
    else if (_selectedCurrency == 'CNY')
      exchangeRate = 7.25;
    else if (_selectedCurrency == 'JPY') exchangeRate = 159.0;

    String currentSymbol = _globalCurrencies
            .firstWhere((e) => e['code'] == _selectedCurrency)['symbol'] ??
        '\$';
    double convertedBalance = balance * exchangeRate;

    return Scaffold(
      backgroundColor:
          isDarkMode ? AppColors.background : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Payment Settings'),
        centerTitle: true,
        backgroundColor: isDarkMode ? AppColors.surface : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(
            color: isDarkMode ? AppColors.textPrimary : Colors.black87),
        titleTextStyle: TextStyle(
          color: isDarkMode ? AppColors.textPrimary : Colors.black87,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      body: paymentProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // 💳 WALLET CARD
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'YOUR WALLET',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$currentSymbol ${convertedBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        banks.isEmpty
                            ? '⚠️ No bank account linked yet'
                            : '✅ ${banks.length} bank(s) linked',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 🌍 CURRENCY SELECTOR
                const Text(
                  'SELECT YOUR CURRENCY',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDarkMode ? AppColors.surface : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: isDarkMode
                            ? AppColors.border
                            : const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCurrency,
                      dropdownColor:
                          isDarkMode ? AppColors.surface : Colors.white,
                      isExpanded: true,
                      style: TextStyle(
                        color:
                            isDarkMode ? AppColors.textPrimary : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                      items: _globalCurrencies.map((curr) {
                        return DropdownMenuItem(
                          value: curr['code'],
                          child: Text('${curr['name']} (${curr['code']})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null)
                          setState(() => _selectedCurrency = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // 🏦 LOCAL BANKS SECTION
                if (localBanks.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '🏦 LOCAL BANKS',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '${localBanks.length} linked',
                        style: TextStyle(
                          color: context.palette.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...localBanks
                      .map((bank) =>
                          _buildBankAccountCard(context, bank, isDarkMode)),
                  const SizedBox(height: 20),
                ],

                // 🌍 FOREIGN BANKS SECTION
                if (foreignBanks.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '🌍 FOREIGN PLATFORMS',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '${foreignBanks.length} linked',
                        style: TextStyle(
                          color: context.palette.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...foreignBanks
                      .map((bank) =>
                          _buildBankAccountCard(context, bank, isDarkMode)),
                  const SizedBox(height: 20),
                ],

                // 🔘 ADD BANK BUTTONS
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _openAddDetailsSheet(true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color:
                                isDarkMode ? AppColors.surface : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: isDarkMode
                                    ? AppColors.border
                                    : const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.add_circle_outline_rounded,
                                color: AppColors.primaryLight,
                                size: 28,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add Local Bank',
                                style: TextStyle(
                                  color: context.palette.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
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
                            color:
                                isDarkMode ? AppColors.surface : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: isDarkMode
                                    ? AppColors.border
                                    : const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.add_circle_outline_rounded,
                                color: AppColors.accent,
                                size: 28,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add Foreign Bank',
                                style: TextStyle(
                                  color: context.palette.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Info Text
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_rounded,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You can add multiple bank accounts. '
                          'Set one as default for faster payments. '
                          'Local banks for PKR, Foreign for international transfers.',
                          style: TextStyle(
                            color: context.palette.textSecondary,
                            fontSize: 12,
                            height: 1.5,
                          ),
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
