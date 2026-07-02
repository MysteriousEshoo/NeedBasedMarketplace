import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// ============================================================
// ENUMS
// ============================================================

enum Urgency { low, medium, high }

extension UrgencyX on Urgency {
  String get label {
    switch (this) {
      case Urgency.low:
        return 'Low';
      case Urgency.medium:
        return 'Medium';
      case Urgency.high:
        return 'Urgent';
    }
  }

  Color get color {
    switch (this) {
      case Urgency.low:
        return AppColors.urgentLow;
      case Urgency.medium:
        return AppColors.urgentMedium;
      case Urgency.high:
        return AppColors.urgentHigh;
    }
  }

  Color get softColor {
    switch (this) {
      case Urgency.low:
        return AppColors.urgentLowSoft;
      case Urgency.medium:
        return AppColors.urgentMediumSoft;
      case Urgency.high:
        return AppColors.urgentHighSoft;
    }
  }

  String get shortLabel {
    switch (this) {
      case Urgency.low:
        return 'Low';
      case Urgency.medium:
        return 'Medium';
      case Urgency.high:
        return 'High';
    }
  }
}

// ✅ Product Condition Enum
enum ProductCondition {
  new_('New'),
  used('Used');

  const ProductCondition(this.label);
  final String label;
}

// ✅ Payment Method Enum
enum PaymentMethod {
  cash('Cash'),
  onlineDeposit('Online Deposit');

  const PaymentMethod(this.label);
  final String label;
}

// ============================================================
// NEED MODEL (With Firestore Support)
// ============================================================

class Need {
  final String id;
  final String title;
  final String description;
  final String category;
  final num budget;
  final String timeElapsed;
  final Urgency urgency;
  final String authorName;
  final int offers;
  final String? userId;
  final String? userName;
  final String? company;
  final String? customCompanyName;
  final String? condition; // 'New' | 'Used'
  final String? paymentMethod; // 'Cash' | 'Online Deposit'
  final DateTime? createdAt;
  final Map<String, dynamic>? location;
  final bool isPremium;

  Need({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.budget,
    required this.timeElapsed,
    required this.urgency,
    required this.authorName,
    required this.offers,
    this.userId,
    this.userName,
    this.company,
    this.customCompanyName,
    this.condition,
    this.paymentMethod,
    this.createdAt,
    this.location,
    this.isPremium = false,
  });

  num get formattedBudget => budget;

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'budget': budget,
      'timeElapsed': timeElapsed,
      'urgency': urgency.toString().split('.').last,
      'authorName': authorName,
      'offers': offers,
      'userId': userId,
      'userName': userName,
      'company': company,
      'customCompanyName': customCompanyName,
      'condition': condition,
      'paymentMethod': paymentMethod,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'location': location,
      'isPremium': isPremium,
    };
  }

  factory Need.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Need(
      id: data['id'] ?? doc.id,
      title: data['title'] ?? 'Untitled',
      description: data['description'] ?? '',
      category: data['category'] ?? 'General',
      budget: data['budget'] ?? 0,
      timeElapsed: data['timeElapsed'] ?? 'N/A',
      urgency: (data['urgency'] as String?) == 'high'
          ? Urgency.high
          : (data['urgency'] as String?) == 'low'
              ? Urgency.low
              : Urgency.medium,
      authorName: data['authorName'] ?? 'Anonymous',
      offers: data['offers'] ?? 0,
      userId: data['userId'],
      userName: data['userName'],
      company: data['company'],
      customCompanyName: data['customCompanyName'],
      condition: data['condition'],
      paymentMethod: data['paymentMethod'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      location: data['location'],
      isPremium: data['isPremium'] ?? false,
    );
  }

  // ✅ Convert to NeedModel (for compatibility)
  NeedModel toNeedModel() {
    return NeedModel(
      id: id,
      userId: userId ?? '',
      userName: userName ?? authorName,
      category: category,
      company: company,
      customCompanyName: customCompanyName,
      condition: condition ?? 'New',
      paymentMethod: paymentMethod ?? 'Cash',
      budget: budget.toDouble(),
      description: description,
      createdAt: createdAt ?? DateTime.now(),
    );
  }
}

// ============================================================
// NEED MODEL (Simplified Version)
// ============================================================

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
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // ✅ Convert to Need (for compatibility)
  Need toNeed() {
    return Need(
      id: id,
      title: description.length > 30
          ? '${description.substring(0, 30)}...'
          : description,
      description: description,
      category: category,
      budget: budget,
      timeElapsed: _getTimeAgo(createdAt),
      urgency: Urgency.medium,
      authorName: userName,
      offers: 0,
      userId: userId,
      userName: userName,
      company: company,
      customCompanyName: customCompanyName,
      condition: condition,
      paymentMethod: paymentMethod,
      createdAt: createdAt,
    );
  }

  String _getTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 7) return '${date.day}/${date.month}/${date.year}';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

// ============================================================
// MOCK DATA
// ============================================================

class MockData {
  MockData._();

  static const List<String> categories = [
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

  static const List<String> mobileCompanies = [
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

  static const List<String> filterChips = [
    'Trending',
    'Tech',
    'Local Services',
    'Urgent',
    'Design',
    'Delivery',
  ];

  static const List<String> locations = [
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
}
