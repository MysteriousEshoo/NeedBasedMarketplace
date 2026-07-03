import 'package:cloud_firestore/cloud_firestore.dart';

class OfferModel {
  final String id;
  final String needId;
  final String sellerId;
  final String sellerName;
  final double offeredPrice;
  final String message;
  final DateTime createdAt;
  final String status; // 'pending', 'accepted', 'rejected'
  final String deliveryTime; // ✅ NEW: '24 hours', '3 days', '1 week', etc.
  final String extraNotes; // ✅ NEW: Additional notes from seller

  OfferModel({
    required this.id,
    required this.needId,
    required this.sellerId,
    required this.sellerName,
    required this.offeredPrice,
    this.message = '',
    required this.createdAt,
    this.status = 'pending',
    this.deliveryTime = '3 days', // ✅ DEFAULT
    this.extraNotes = '', // ✅ DEFAULT
  });

  // ✅ For Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'needId': needId,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'offeredPrice': offeredPrice,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      'deliveryTime': deliveryTime, // ✅ NEW
      'extraNotes': extraNotes, // ✅ NEW
    };
  }

  factory OfferModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OfferModel(
      id: data['id'] ?? doc.id,
      needId: data['needId'] ?? '',
      sellerId: data['sellerId'] ?? '',
      sellerName: data['sellerName'] ?? '',
      offeredPrice: (data['offeredPrice'] as num).toDouble(),
      message: data['message'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      status: data['status'] ?? 'pending',
      deliveryTime: data['deliveryTime'] ?? '3 days', // ✅ NEW
      extraNotes: data['extraNotes'] ?? '', // ✅ NEW
    );
  }

  // ✅ For Realtime Database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'needId': needId,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'offeredPrice': offeredPrice,
      'message': message,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'status': status,
      'deliveryTime': deliveryTime, // ✅ NEW
      'extraNotes': extraNotes, // ✅ NEW
    };
  }

  factory OfferModel.fromMap(String id, Map<String, dynamic> map) {
    return OfferModel(
      id: id,
      needId: map['needId'] ?? '',
      sellerId: map['sellerId'] ?? '',
      sellerName: map['sellerName'] ?? '',
      offeredPrice: (map['offeredPrice'] ?? 0).toDouble(),
      message: map['message'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
      status: map['status'] ?? 'pending',
      deliveryTime: map['deliveryTime'] ?? '3 days', // ✅ NEW
      extraNotes: map['extraNotes'] ?? '', // ✅ NEW
    );
  }

  // ✅ Copy with method for status updates
  OfferModel copyWith({
    String? id,
    String? needId,
    String? sellerId,
    String? sellerName,
    double? offeredPrice,
    String? message,
    DateTime? createdAt,
    String? status,
    String? deliveryTime,
    String? extraNotes,
  }) {
    return OfferModel(
      id: id ?? this.id,
      needId: needId ?? this.needId,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      offeredPrice: offeredPrice ?? this.offeredPrice,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      extraNotes: extraNotes ?? this.extraNotes,
    );
  }
}
