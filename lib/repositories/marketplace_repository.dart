import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/need_model.dart'; //  YOUR DATA MODEL FILE IMPORT NODE
import '../models/offer_model.dart';

class MarketplaceRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream current active needs sorted newest first
  Stream<List<NeedModel>> streamActiveNeeds() {
    return _firestore
        .collection('needs')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => NeedModel.fromFirestore(doc)).toList());
  }

  // Atomic creation pipeline
  Future<void> createNeedListing(NeedModel need) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User session unauthenticated.");
    await _firestore.collection('needs').doc(need.id).set(need.toFirestore());
  }

  // Atomic submit offer pipeline
  Future<void> submitSellerOffer(OfferModel offer) async {
    await _firestore
        .collection('offers')
        .doc(offer.id)
        .set(offer.toFirestore());

    // Inject custom internal push update mapping to target user
    final needSnapshot =
        await _firestore.collection('needs').doc(offer.needId).get();
    if (needSnapshot.exists) {
      final buyerId = needSnapshot.data()?['userId'];
      if (buyerId != null) {
        await _firestore
            .collection('users')
            .doc(buyerId)
            .collection('notifications')
            .add({
          'title': 'New Offer Received!',
          'body':
              '${offer.sellerName} offered split pricing of ${offer.offeredPrice}',
          'timestamp': FieldValue.serverTimestamp(),
          'seen': false,
        });
      }
    }
  }

  // Update seller mode globally inside state user document references
  Future<void> updateUserRole(String userId, bool isSeller) async {
    await _firestore.collection('users').doc(userId).update({
      'isSellerMode': isSeller,
    });
  }
}
