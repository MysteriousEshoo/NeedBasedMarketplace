import 'package:cloud_firestore/cloud_firestore.dart';

class OfferModel {
  final String id;
  final String needId;
  final String sellerId;
  final String sellerName;
  final double offeredPrice;
  final String message;
  final DateTime createdAt;
  final String status;
  final String needTitle;
  final String deliveryTime;
  final String extraNotes;

  OfferModel({
    required this.id,
    required this.needId,
    required this.sellerId,
    required this.sellerName,
    required this.offeredPrice,
    this.message = '',
    required this.createdAt,
    this.status = 'pending',
    required this.needTitle,
    this.deliveryTime = '3 days',
    this.extraNotes = '',
  });

  // ✅ toFirestore() METHOD - FIXED
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
      'needTitle': needTitle,
      'deliveryTime': deliveryTime,
      'extraNotes': extraNotes,
    };
  }

  // ✅ fromFirestore FACTORY METHOD
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
      needTitle: data['needTitle'] ?? 'Need',
      deliveryTime: data['deliveryTime'] ?? '3 days',
      extraNotes: data['extraNotes'] ?? '',
    );
  }

  // ✅ toMap() FOR REALTIME DATABASE
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
      'needTitle': needTitle,
      'deliveryTime': deliveryTime,
      'extraNotes': extraNotes,
    };
  }

  // ✅ fromMap FOR REALTIME DATABASE
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
      needTitle: map['needTitle'] ?? 'Need',
      deliveryTime: map['deliveryTime'] ?? '3 days',
      extraNotes: map['extraNotes'] ?? '',
    );
  }
}
