import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
