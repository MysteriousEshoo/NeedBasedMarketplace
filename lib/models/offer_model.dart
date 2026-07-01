import 'package:cloud_firestore/cloud_firestore.dart';

class OfferModel {
  final String id;
  final String needId;
  final String sellerId;
  final String sellerName;
  final double offeredPrice;
  final String message;
  final DateTime createdAt;

  OfferModel({
    required this.id,
    required this.needId,
    required this.sellerId,
    required this.sellerName,
    required this.offeredPrice,
    required this.message,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'needId': needId,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'offeredPrice': offeredPrice,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
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
    );
  }
}
