import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import '../theme/app_colors.dart';

enum Urgency {
  low('Low Urgency', AppColors.urgentLow, AppColors.urgentLowSoft),
  medium('Medium Urgency', AppColors.urgentMedium, AppColors.urgentMediumSoft),
  high('High Urgency', AppColors.urgentHigh, AppColors.urgentHighSoft);

  const Urgency(this.label, this.color, this.softColor);

  final String label;
  final Color color;
  final Color softColor;

  String get shortLabel => label.split(' ').first;
}

enum ProductCondition {
  new_('New'),
  used('Used');

  const ProductCondition(this.label);
  final String label;
}

enum PaymentMethod {
  cash('Cash'),
  onlineDeposit('Online Deposit');

  const PaymentMethod(this.label);
  final String label;
}

class Need {
  final String id;
  final String title;
  final String description;
  final String category;
  final int budget;
  final String timeElapsed;
  final Urgency urgency;
  final String authorName;
  final int offers;
  final String? companyName;
  final ProductCondition? condition;
  final PaymentMethod? paymentMethod;
  final String? location;
  final String? authorId;
  final bool isPremium;
  final String? userId;
  final String? userName;

  const Need({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.budget,
    required this.timeElapsed,
    required this.urgency,
    required this.authorName,
    required this.offers,
    this.companyName,
    this.condition,
    this.paymentMethod,
    this.location,
    this.authorId,
    this.isPremium = false,
    this.userId,
    this.userName,
  });

  String get formattedBudget {
    final raw = budget.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) buffer.write(',');
      buffer.write(raw[i]);
    }
    return 'PKR $buffer';
  }
}

class NeedModel {
  final String id;
  final String userId;
  final String userName;
  final String category;
  final String? company;
  final String? customCompanyName;
  final String condition;
  final String paymentMethod;
  final double budget;
  final String description;
  final DateTime createdAt;

  NeedModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.category,
    this.company,
    this.customCompanyName,
    required this.condition,
    required this.paymentMethod,
    required this.budget,
    required this.description,
    required this.createdAt,
  });

  // ✅ toFirestore() METHOD - FOR FIRESTORE
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'category': category,
      'company': company,
      'customCompanyName': customCompanyName,
      'condition': condition,
      'paymentMethod': paymentMethod,
      'budget': budget,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // ✅ fromFirestore() FACTORY METHOD - FOR FIRESTORE
  factory NeedModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NeedModel(
      id: data['id'] ?? doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      category: data['category'] ?? 'General',
      company: data['company'],
      customCompanyName: data['customCompanyName'],
      condition: data['condition'] ?? 'New',
      paymentMethod: data['paymentMethod'] ?? 'Cash',
      budget: (data['budget'] ?? 0).toDouble(),
      description: data['description'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  factory NeedModel.fromMap(String id, Map<String, dynamic> map) {
    return NeedModel(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Anonymous',
      category: map['category'] ?? 'General',
      company: map['company'],
      customCompanyName: map['customCompanyName'],
      condition: map['condition'] ?? 'New',
      paymentMethod: map['paymentMethod'] ?? 'Cash',
      budget: (map['budget'] ?? 0).toDouble(),
      description: map['description'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
    );
  }
}

/// 🗂 App-wide reference data — categories, locations, etc.
///
/// These lists power every dropdown, filter chip and picker in the app.
/// By default they use the hardcoded defaults below, but the moment
/// [AppConfigService.fetch] resolves they are replaced with whatever the
/// admin has configured in Firebase RTDB at `app_config/`.
///
/// This way you can add/rename categories from the Firebase console without
/// pushing a new app version.
class MockData {
  MockData._();

  static List<String> categories = _defaultCategories;
  static List<String> mobileCompanies = _defaultMobileCompanies;
  static List<String> filterChips = _defaultFilterChips;
  static List<String> locations = _defaultLocations;
  static List<String> sellerCategories = _defaultSellerCategories;
  static List<String> deliveryOptions = _defaultDeliveryOptions;

  // ─── Default fallbacks (used until Firebase config loads) ───────────────

  static const List<String> _defaultCategories = [
    'Tech & Development',
    'Mobile Phone',
    'Local Services',
    'Design & Creative',
    'Delivery & Logistics',
    'Home & Repair',
    'Tutoring',
    'Electronics',
    'Vehicles',
  ];

  static const List<String> _defaultMobileCompanies = [
    'Apple (iPhone)',
    'Samsung',
    'Infinix',
    'Tecno',
    'Oppo',
    'Vivo',
    'Redmi',
    'Realme',
    'Others',
  ];

  static const List<String> _defaultFilterChips = [
    'Trending',
    'Tech',
    'Local Services',
    'Urgent',
    'Design',
    'Delivery',
  ];

  static const List<String> _defaultLocations = [
    'Karachi',
    'Lahore',
    'Islamabad',
    'Rawalpindi',
    'Faisalabad',
    'Multan',
    'Peshawar',
    'Quetta',
    'Hyderabad',
    'Other',
  ];

  static const List<String> _defaultSellerCategories = [
    'Electronics',
    'Fashion & Apparel',
    'Home & Furniture',
    'Food & Groceries',
    'Services',
    'Vehicles',
    'Health & Beauty',
    'Other',
  ];

  static const List<String> _defaultDeliveryOptions = [
    '24 hours',
    '3 days',
    '1 week',
    '2 weeks',
    '1 month',
    'Custom',
  ];
}

/// 📡 Fetches reference data from Firebase RTDB so the admin can customise
/// categories, locations etc. from the Firebase console without a new build.
///
/// **How to use:**
/// Call `await AppConfigService.fetch()` once at app start (right after
/// Firebase.initializeApp). After that, [MockData.categories] and friends
/// are populated with the live values or fall back to the built-in defaults
/// if the config nodes don't exist.
///
/// **Firebase RTDB structure to create:**
/// ```
/// app_config:
///   categories:
///     - "Tech & Development"
///     - "Mobile Phone"
///     …
///   mobile_companies:
///     - "Apple (iPhone)"
///     …
///   locations:
///     - "Karachi"
///     …
///   seller_categories:
///     - "Electronics"
///     …
///   delivery_options:
///     - "24 hours"
///     …
/// ```
class AppConfigService {
  AppConfigService._();

  /// Whether [fetch] has been called at least once.
  static bool _hasFetched = false;

  /// Call once after Firebase is initialised to load live config.
  static Future<void> fetch() async {
    if (_hasFetched) return;
    _hasFetched = true;

    try {
      final ref = FirebaseDatabase.instance.ref().child('app_config');
      final snapshot = await ref.get();

      if (!snapshot.exists || snapshot.value is! Map) return;

      final config = Map<String, dynamic>.from(snapshot.value as Map);

      // Helper to extract a list of strings from a config node.
      List<String> _extractList(dynamic node) {
        if (node is! List) return [];
        return node
            .map((e) => e.toString())
            .where((s) => s.trim().isNotEmpty)
            .toList();
      }

      final cats = _extractList(config['categories']);
      if (cats.isNotEmpty) MockData.categories = cats;

      final cos = _extractList(config['mobile_companies']);
      if (cos.isNotEmpty) MockData.mobileCompanies = cos;

      final chips = _extractList(config['filter_chips']);
      if (chips.isNotEmpty) MockData.filterChips = chips;

      final locs = _extractList(config['locations']);
      if (locs.isNotEmpty) MockData.locations = locs;

      final sellerCats = _extractList(config['seller_categories']);
      if (sellerCats.isNotEmpty) MockData.sellerCategories = sellerCats;

      final delivery = _extractList(config['delivery_options']);
      if (delivery.isNotEmpty) MockData.deliveryOptions = delivery;
    } catch (e) {
      debugPrint('AppConfigService: Could not load config — using defaults. ($e)');
    }
  }
}
