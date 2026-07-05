import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/need_model.dart';
import '../models/offer_model.dart';

class MarketplaceRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================
  // ✅ GET CURRENT USER
  // ============================================================
  User? get currentUser => _auth.currentUser;

  // ============================================================
  // ✅ STREAM ACTIVE NEEDS
  // ============================================================
  Stream<List<NeedModel>> streamActiveNeeds() {
    return _firestore
        .collection('needs')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => NeedModel.fromFirestore(doc)).toList());
  }

  // ============================================================
  // ✅ CREATE NEED LISTING
  // ============================================================
  Future<void> createNeedListing(NeedModel need) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User session unauthenticated.');
    }
    await _firestore.collection('needs').doc(need.id).set(need.toFirestore());
  }

  // ============================================================
  // ✅ SUBMIT SELLER OFFER - FIXED
  // ============================================================
  Future<void> submitSellerOffer(OfferModel offer) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User session unauthenticated.');
    }

    // ✅ toFirestore() ab kaam karega
    await _firestore
        .collection('offers')
        .doc(offer.id)
        .set(offer.toFirestore());

    final needSnapshot =
        await _firestore.collection('needs').doc(offer.needId).get();

    if (needSnapshot.exists) {
      final needData = needSnapshot.data();
      final buyerId = needData?['userId'];

      if (buyerId != null && buyerId.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(buyerId)
            .collection('notifications')
            .add({
          'title': 'New Offer Received!',
          'body':
              '${offer.sellerName} offered PKR ${offer.offeredPrice.toStringAsFixed(0)} for your need',
          'needId': offer.needId,
          'offerId': offer.id,
          'timestamp': FieldValue.serverTimestamp(),
          'seen': false,
        });

        await _firestore.collection('needs').doc(offer.needId).update({
          'offers': FieldValue.increment(1),
        });
      }
    }
  }

  // ============================================================
  // ✅ GET OFFERS FOR A NEED
  // ============================================================
  Stream<List<OfferModel>> streamOffersForNeed(String needId) {
    return _firestore
        .collection('offers')
        .where('needId', isEqualTo: needId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => OfferModel.fromFirestore(doc)).toList());
  }

  // ============================================================
  // ✅ UPDATE OFFER STATUS
  // ============================================================
  Future<void> updateOfferStatus(String offerId, String status) async {
    await _firestore.collection('offers').doc(offerId).update({
      'status': status,
    });
  }

  // ============================================================
  // ✅ UPDATE USER ROLE
  // ============================================================
  Future<void> updateUserRole(String userId, bool isSeller) async {
    await _firestore.collection('users').doc(userId).update({
      'isSellerMode': isSeller,
    });
  }

  // ============================================================
  // ✅ GET USER ROLE
  // ============================================================
  Future<bool> getUserRole(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (doc.exists) {
      final data = doc.data();
      return data?['isSellerMode'] ?? false;
    }
    return false;
  }

  // ============================================================
  // ✅ DELETE NEED
  // ============================================================
  Future<void> deleteNeed(String needId) async {
    await _firestore.collection('needs').doc(needId).delete();
  }

  // ============================================================
  // ✅ GET NEED BY ID
  // ============================================================
  Future<NeedModel?> getNeedById(String needId) async {
    final doc = await _firestore.collection('needs').doc(needId).get();
    if (doc.exists) {
      return NeedModel.fromFirestore(doc);
    }
    return null;
  }

  // ============================================================
  // ✅ GET NOTIFICATIONS FOR USER
  // ============================================================
  Stream<List<Map<String, dynamic>>> streamNotifications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  // ============================================================
  // ✅ MARK NOTIFICATION AS SEEN
  // ============================================================
  Future<void> markNotificationSeen(
      String userId, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({
      'seen': true,
    });
  }
}
