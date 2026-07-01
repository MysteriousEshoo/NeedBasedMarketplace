import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum Urgency { low, medium, high }

extension UrgencyX on Urgency {
  String get label {
    switch (this) {
      case Urgency.low:
        return 'Relaxed';
      case Urgency.medium:
        return 'Standard';
      case Urgency.high:
        return 'Urgent';
    }
  }

  Color get color {
    switch (this) {
      case Urgency.low:
        return Colors.blue;
      case Urgency.medium:
        return Colors.orange;
      case Urgency.high:
        return Colors.red;
    }
  }

  Color get softColor {
    switch (this) {
      case Urgency.low:
        return Colors.blue.withOpacity(0.1);
      case Urgency.medium:
        return Colors.orange.withOpacity(0.1);
      case Urgency.high:
        return Colors.red.withOpacity(0.1);
    }
  }
}

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
  num get formattedBudget => budget;

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
  });

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
    );
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
}
