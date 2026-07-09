enum SellerRequestStatus { none, pending, approved, rejected }

class SellerRequest {
  final String uid;
  final String fullName;
  final String businessName;
  final String phone;
  final String cnic;
  final String city;
  final String category;
  final String description;
  final SellerRequestStatus status;
  final int submittedAt;
  final int? reviewedAt;
  final bool notified;

  SellerRequest({
    required this.uid,
    required this.fullName,
    required this.businessName,
    required this.phone,
    required this.cnic,
    required this.city,
    required this.category,
    required this.description,
    this.status = SellerRequestStatus.pending,
    required this.submittedAt,
    this.reviewedAt,
    this.notified = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'businessName': businessName,
      'phone': phone,
      'cnic': cnic,
      'city': city,
      'category': category,
      'description': description,
      'status': statusToString(status),
      'submittedAt': submittedAt,
      'reviewedAt': reviewedAt,
      'notified': notified,
    };
  }

  factory SellerRequest.fromMap(String uid, Map<String, dynamic> map) {
    return SellerRequest(
      uid: uid,
      fullName: map['fullName'] ?? '',
      businessName: map['businessName'] ?? '',
      phone: map['phone'] ?? '',
      cnic: map['cnic'] ?? '',
      city: map['city'] ?? '',
      category: map['category'] ?? '',
      description: map['description'] ?? '',
      status: statusFromString(map['status'] as String?),
      submittedAt: map['submittedAt'] ?? 0,
      reviewedAt: map['reviewedAt'],
      notified: map['notified'] ?? false,
    );
  }

  static SellerRequestStatus statusFromString(String? value) {
    switch (value) {
      case 'pending':
        return SellerRequestStatus.pending;
      case 'approved':
        return SellerRequestStatus.approved;
      case 'rejected':
        return SellerRequestStatus.rejected;
      default:
        return SellerRequestStatus.none;
    }
  }

  static String statusToString(SellerRequestStatus status) {
    switch (status) {
      case SellerRequestStatus.pending:
        return 'pending';
      case SellerRequestStatus.approved:
        return 'approved';
      case SellerRequestStatus.rejected:
        return 'rejected';
      case SellerRequestStatus.none:
        return 'none';
    }
  }
}
