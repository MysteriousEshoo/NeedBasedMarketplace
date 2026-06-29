import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class PaymentProvider extends ChangeNotifier {
  double _walletBalance = 0.0;
  bool _isLoading = true;
  String _selectedCurrency = 'PKR';

  // ✅ Multiple Banks List
  List<BankAccount> _bankAccounts = [];

  // OTP Verification State
  String? _pendingVerificationId;
  String? _pendingBankName;
  String? _pendingAccountNumber;
  String? _pendingHolderName;
  bool _isPendingLocal = true;

  PaymentProvider() {
    _loadWalletBalance();
    _loadBankAccounts();
  }

  double get walletBalance => _walletBalance;
  bool get isLoading => _isLoading;
  String get selectedCurrency => _selectedCurrency;
  List<BankAccount> get bankAccounts => _bankAccounts;
  bool get hasVerifiedBank => _bankAccounts.isNotEmpty;

  // ✅ Get local banks only
  List<BankAccount> get localBanks =>
      _bankAccounts.where((b) => b.isLocal).toList();

  // ✅ Get foreign banks only
  List<BankAccount> get foreignBanks =>
      _bankAccounts.where((b) => !b.isLocal).toList();

  // ============================================================
  // LOAD BANK ACCOUNTS FROM FIREBASE
  // ============================================================
  Future<void> _loadBankAccounts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snapshot = await FirebaseDatabase.instance
            .ref()
            .child('user_banks')
            .child(user.uid)
            .get();

        _bankAccounts.clear();

        if (snapshot.exists) {
          final data = snapshot.value as Map<dynamic, dynamic>;
          data.forEach((key, value) {
            final Map<String, dynamic> bankData =
                Map<String, dynamic>.from(value as Map);
            _bankAccounts.add(BankAccount(
              id: key,
              bankName: bankData['bankName'] ?? '',
              accountNumber: bankData['accountNumber'] ?? '',
              holderName: bankData['holderName'] ?? '',
              isLocal: bankData['isLocal'] ?? true,
              isVerified: bankData['isVerified'] ?? false,
              verifiedAt: bankData['verifiedAt'] != null
                  ? DateTime.fromMillisecondsSinceEpoch(
                      bankData['verifiedAt'] as int)
                  : null,
            ));
          });
        }
      }
    } catch (e) {
      _bankAccounts.clear();
    }

    _isLoading = false;
    notifyListeners();
  }

  // ============================================================
  // LOAD WALLET BALANCE
  // ============================================================
  Future<void> _loadWalletBalance() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snapshot = await FirebaseDatabase.instance
            .ref()
            .child('user_wallets')
            .child(user.uid)
            .child('balance')
            .get();

        if (snapshot.exists) {
          _walletBalance = (snapshot.value as num?)?.toDouble() ?? 0.0;
        } else {
          _walletBalance = 0.0;
          await FirebaseDatabase.instance
              .ref()
              .child('user_wallets')
              .child(user.uid)
              .child('balance')
              .set(0.0);
        }
      }
    } catch (e) {
      _walletBalance = 0.0;
    }
    notifyListeners();
  }

  // ============================================================
  // 🔥 VERIFY BANK (Step 1)
  // ============================================================
  Future<BankVerificationResult> verifyBank({
    required String bankName,
    required String accountNumber,
    required String holderName,
    required bool isLocal,
  }) async {
    await Future.delayed(const Duration(seconds: 1));

    if (isLocal) {
      final isNumeric = RegExp(r'^[0-9]+$').hasMatch(accountNumber);
      if (!isNumeric) {
        return BankVerificationResult(
          isValid: false,
          message: '❌ Account number must contain only digits.',
        );
      }

      if (accountNumber.length < 9 || accountNumber.length > 16) {
        return BankVerificationResult(
          isValid: false,
          message: '❌ Account number must be 9-16 digits long.',
        );
      }

      if (!_validLocalBanks.contains(bankName)) {
        return BankVerificationResult(
          isValid: false,
          message: '❌ Invalid bank selected. Please choose from the list.',
        );
      }

      final bankResponse = await _simulateBankAPICall(
        bankName: bankName,
        accountNumber: accountNumber,
        holderName: holderName,
      );

      if (!bankResponse.isSuccess) {
        return BankVerificationResult(
          isValid: false,
          message: bankResponse.message,
        );
      }

      _pendingVerificationId = _generateOTP();
      _pendingBankName = bankName;
      _pendingAccountNumber = accountNumber;
      _pendingHolderName = holderName;
      _isPendingLocal = isLocal;

      _sendOTPToUser(_pendingVerificationId!);

      return BankVerificationResult(
        isValid: true,
        message: '✅ Account found! OTP sent to your registered mobile number.',
        requiresOTP: true,
      );
    } else {
      final isEmail =
          RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(accountNumber);
      if (!isEmail) {
        return BankVerificationResult(
          isValid: false,
          message: '❌ Please enter a valid email address.',
        );
      }

      if (!_validForeignPlatforms.contains(bankName)) {
        return BankVerificationResult(
          isValid: false,
          message: '❌ Invalid platform selected.',
        );
      }

      final platformResponse = await _simulatePlatformAPICall(
        platformName: bankName,
        email: accountNumber,
        holderName: holderName,
      );

      if (!platformResponse.isSuccess) {
        return BankVerificationResult(
          isValid: false,
          message: platformResponse.message,
        );
      }

      _pendingVerificationId = _generateOTP();
      _pendingBankName = bankName;
      _pendingAccountNumber = accountNumber;
      _pendingHolderName = holderName;
      _isPendingLocal = isLocal;

      _sendOTPToUser(_pendingVerificationId!);

      return BankVerificationResult(
        isValid: true,
        message: '✅ Account found! OTP sent to your registered email.',
        requiresOTP: true,
      );
    }
  }

  // ============================================================
  // 🔥 VERIFY OTP (Step 2)
  // ============================================================
  Future<bool> verifyOTP(String otp) async {
    if (_pendingVerificationId == null) {
      return false;
    }

    await Future.delayed(const Duration(seconds: 1));

    if (otp == _pendingVerificationId) {
      final saved = await saveVerifiedBank(
        bankName: _pendingBankName!,
        accountNumber: _pendingAccountNumber!,
        holderName: _pendingHolderName!,
        isLocal: _isPendingLocal,
      );

      _pendingVerificationId = null;
      _pendingBankName = null;
      _pendingAccountNumber = null;
      _pendingHolderName = null;

      return saved;
    }

    return false;
  }

  // ============================================================
  // 🔥 SAVE VERIFIED BANK
  // ============================================================
  Future<bool> saveVerifiedBank({
    required String bankName,
    required String accountNumber,
    required String holderName,
    required bool isLocal,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final newRef = FirebaseDatabase.instance
          .ref()
          .child('user_banks')
          .child(user.uid)
          .push();

      await newRef.set({
        'bankName': bankName,
        'accountNumber': accountNumber,
        'holderName': holderName,
        'isLocal': isLocal,
        'isVerified': true,
        'verifiedAt': ServerValue.timestamp,
      });

      // Add to local list
      _bankAccounts.add(BankAccount(
        id: newRef.key!,
        bankName: bankName,
        accountNumber: accountNumber,
        holderName: holderName,
        isLocal: isLocal,
        isVerified: true,
        verifiedAt: DateTime.now(),
      ));

      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // 🔥 DELETE BANK ACCOUNT
  // ============================================================
  Future<bool> deleteBankAccount(String accountId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      await FirebaseDatabase.instance
          .ref()
          .child('user_banks')
          .child(user.uid)
          .child(accountId)
          .remove();

      _bankAccounts.removeWhere((b) => b.id == accountId);
      notifyListeners();

      return true;
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // 🔥 SET DEFAULT BANK
  // ============================================================
  Future<bool> setDefaultBank(String accountId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Remove default from all
      for (var bank in _bankAccounts) {
        if (bank.isDefault) {
          await FirebaseDatabase.instance
              .ref()
              .child('user_banks')
              .child(user.uid)
              .child(bank.id)
              .child('isDefault')
              .set(false);
        }
      }

      // Set new default
      await FirebaseDatabase.instance
          .ref()
          .child('user_banks')
          .child(user.uid)
          .child(accountId)
          .child('isDefault')
          .set(true);

      // Update local list
      for (var bank in _bankAccounts) {
        bank.isDefault = bank.id == accountId;
      }

      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // 🔥 ADD TO WALLET
  // ============================================================
  Future<void> addToWallet(double amount) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      _walletBalance += amount;
      notifyListeners();

      await FirebaseDatabase.instance
          .ref()
          .child('user_wallets')
          .child(user.uid)
          .child('balance')
          .set(_walletBalance);

      await FirebaseDatabase.instance
          .ref()
          .child('user_wallets')
          .child(user.uid)
          .child('transactions')
          .push()
          .set({
        'amount': amount,
        'type': 'credit',
        'timestamp': ServerValue.timestamp,
        'description': 'Payment received',
      });
    } catch (e) {
      _walletBalance -= amount;
      notifyListeners();
    }
  }

  // ============================================================
  // SIMULATION METHODS
  // ============================================================
  Future<APICallResult> _simulateBankAPICall({
    required String bankName,
    required String accountNumber,
    required String holderName,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final bool passesLuhn = _luhnCheck(accountNumber);

    if (!passesLuhn) {
      return APICallResult(
        isSuccess: false,
        message:
            '❌ Account number validation failed. Please check your account number.',
      );
    }

    if (bankName.contains('HBL')) {
      if (!accountNumber.startsWith('01') && !accountNumber.startsWith('02')) {
        return APICallResult(
          isSuccess: false,
          message: '❌ HBL account numbers start with 01 or 02.',
        );
      }
    } else if (bankName.contains('UBL')) {
      if (!accountNumber.startsWith('03') && !accountNumber.startsWith('04')) {
        return APICallResult(
          isSuccess: false,
          message: '❌ UBL account numbers start with 03 or 04.',
        );
      }
    } else if (bankName.contains('Meezan')) {
      if (!accountNumber.startsWith('07') && !accountNumber.startsWith('08')) {
        return APICallResult(
          isSuccess: false,
          message: '❌ Meezan account numbers start with 07 or 08.',
        );
      }
    }

    return APICallResult(
      isSuccess: true,
      message: '✅ Account verified successfully!',
    );
  }

  Future<APICallResult> _simulatePlatformAPICall({
    required String platformName,
    required String email,
    required String holderName,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final domain = email.split('@').last;

    if (!domain.contains('.') || domain.length < 4) {
      return APICallResult(
        isSuccess: false,
        message: '❌ Invalid email domain.',
      );
    }

    return APICallResult(
      isSuccess: true,
      message: '✅ Platform verified successfully!',
    );
  }

  bool _luhnCheck(String number) {
    if (number.isEmpty) return false;
    int sum = 0;
    bool alternate = false;
    for (int i = number.length - 1; i >= 0; i--) {
      int n = int.parse(number[i]);
      if (alternate) {
        n *= 2;
        if (n > 9) n = (n % 10) + 1;
      }
      sum += n;
      alternate = !alternate;
    }
    return (sum % 10 == 0);
  }

  String _generateOTP() {
    final random = DateTime.now().millisecondsSinceEpoch % 1000000;
    return random.toString().padLeft(6, '0');
  }

  void _sendOTPToUser(String otp) {
    print('📱 OTP SENT: $otp');
  }

  static const List<String> _validLocalBanks = [
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

  static const List<String> _validForeignPlatforms = [
    'PayPal Global Account',
    'Payoneer International Wallet',
    'Stripe Connect Gateway',
  ];
}

// ============================================================
// BANK ACCOUNT MODEL
// ============================================================

class BankAccount {
  final String id;
  final String bankName;
  final String accountNumber;
  final String holderName;
  final bool isLocal;
  final bool isVerified;
  final DateTime? verifiedAt;
  bool isDefault;

  BankAccount({
    required this.id,
    required this.bankName,
    required this.accountNumber,
    required this.holderName,
    required this.isLocal,
    required this.isVerified,
    this.verifiedAt,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'bankName': bankName,
        'accountNumber': accountNumber,
        'holderName': holderName,
        'isLocal': isLocal,
        'isVerified': isVerified,
        'verifiedAt': verifiedAt?.millisecondsSinceEpoch,
        'isDefault': isDefault,
      };
}

class BankVerificationResult {
  final bool isValid;
  final String message;
  final bool requiresOTP;

  BankVerificationResult({
    required this.isValid,
    required this.message,
    this.requiresOTP = false,
  });
}

class APICallResult {
  final bool isSuccess;
  final String message;

  APICallResult({
    required this.isSuccess,
    required this.message,
  });
}
