import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/seller_request_model.dart';
import '../services/notification_service.dart';

/// Watches the current user's seller-registration request in Realtime DB at
/// `seller_requests/{uid}` and keeps the app in sync with its approval status.
///
/// When the owner/developer changes the status to `approved` or `rejected`
/// (e.g. from the Firebase console), this provider automatically pushes an
/// in-app notification to the user and marks the request as notified so it is
/// only sent once. Seller Mode stays locked until the status is `approved`.
class SellerRequestProvider extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();

  StreamSubscription<DatabaseEvent>? _requestSub;
  StreamSubscription<User?>? _authSub;

  String? _uid;
  SellerRequest? _request;
  bool _isLoading = true;

  SellerRequestProvider() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_bindToUser);
    _bindToUser(FirebaseAuth.instance.currentUser);
  }

  SellerRequest? get request => _request;
  bool get isLoading => _isLoading;

  SellerRequestStatus get status =>
      _request?.status ?? SellerRequestStatus.none;

  bool get isApproved => status == SellerRequestStatus.approved;
  bool get isPending => status == SellerRequestStatus.pending;
  bool get isRejected => status == SellerRequestStatus.rejected;
  bool get canSellerBeEnabled => isApproved;

  DatabaseReference get _ref =>
      FirebaseDatabase.instance.ref().child('seller_requests').child(_uid!);

  void _bindToUser(User? user) {
    if (user?.uid == _uid) return;

    _requestSub?.cancel();
    _requestSub = null;
    _uid = user?.uid;
    _request = null;

    if (_uid == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    _requestSub = _ref.onValue.listen((event) {
      if (event.snapshot.value == null) {
        _request = null;
      } else {
        final data =
            Map<String, dynamic>.from(event.snapshot.value as Map);
        _request = SellerRequest.fromMap(_uid!, data);
        _maybeNotifyOnReview(_request!);
      }
      _isLoading = false;
      notifyListeners();
    }, onError: (_) {
      _isLoading = false;
      notifyListeners();
    });
  }

  /// Submits a new seller registration request for approval.
  Future<void> submitRequest({
    required String fullName,
    required String businessName,
    required String phone,
    required String cnic,
    required String city,
    required String category,
    required String description,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final request = SellerRequest(
      uid: user.uid,
      fullName: fullName,
      businessName: businessName,
      phone: phone,
      cnic: cnic,
      city: city,
      category: category,
      description: description,
      status: SellerRequestStatus.pending,
      submittedAt: DateTime.now().millisecondsSinceEpoch,
      notified: false,
    );

    await FirebaseDatabase.instance
        .ref()
        .child('seller_requests')
        .child(user.uid)
        .set(request.toMap());
  }

  /// When the owner approves/rejects the request, notify the user exactly once.
  Future<void> _maybeNotifyOnReview(SellerRequest request) async {
    final isReviewed = request.status == SellerRequestStatus.approved ||
        request.status == SellerRequestStatus.rejected;
    if (!isReviewed || request.notified) return;

    // Mark as notified first so a rebuild/second device doesn't double-send.
    await _ref.child('notified').set(true);

    if (request.status == SellerRequestStatus.approved) {
      await _notificationService.sendNotification(
        userId: request.uid,
        title: '✅ Seller request approved',
        body:
            'Congratulations! Your seller account has been approved. You can now switch to Seller Mode from Settings.',
        type: 'seller',
      );
    } else {
      await _notificationService.sendNotification(
        userId: request.uid,
        title: '❌ Seller request rejected',
        body:
            'Your seller registration request was not approved. You can review your details and re-apply from Settings.',
        type: 'seller',
      );
    }
  }

  @override
  void dispose() {
    _requestSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}
