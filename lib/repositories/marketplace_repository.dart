import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/need_model.dart';
import '../models/offer_model.dart';

class MarketplaceRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  User? get currentUser => _auth.currentUser;

  // ============================================================
  // ✅ STREAM ACTIVE NEEDS - REALTIME DATABASE
  // ============================================================
  Stream<List<NeedModel>> streamActiveNeeds() {
    return _database.child('needs').onValue.map((event) {
      final List<NeedModel> needs = [];

      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> allMap =
            event.snapshot.value as Map<dynamic, dynamic>;

        allMap.forEach((key, value) {
          final data = Map<String, dynamic>.from(value as Map);

          final need = NeedModel(
            id: key,
            userId: data['userId'] ?? data['authorId'] ?? '',
            userName: data['userName'] ?? data['authorName'] ?? 'Anonymous',
            category: data['category'] ?? 'General',
            company: data['company'],
            customCompanyName: data['customCompanyName'],
            condition: data['condition'] ?? 'New',
            paymentMethod: data['paymentMethod'] ?? 'Cash',
            budget: (data['budget'] ?? 0).toDouble(),
            description: data['description'] ?? '',
            createdAt: data['timestamp'] != null
                ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'])
                : DateTime.now(),
          );

          needs.add(need);
        });
      }

      // Sort by createdAt descending (newest first)
      needs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return needs;
    });
  }

  // ============================================================
  // ✅ CREATE NEED LISTING
  // ============================================================
  Future<void> createNeedListing(NeedModel need) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User session unauthenticated.');
    }

    final Map<String, dynamic> needData = {
      'id': need.id,
      'userId': need.userId,
      'userName': need.userName,
      'category': need.category,
      'company': need.company,
      'customCompanyName': need.customCompanyName,
      'condition': need.condition,
      'paymentMethod': need.paymentMethod,
      'budget': need.budget,
      'description': need.description,
      'timestamp': ServerValue.timestamp,
      'offers': 0,
      'isPremium': false,
    };

    await _database.child('needs').push().set(needData);
  }

  // ============================================================
  // ✅ SUBMIT SELLER OFFER
  // ============================================================
  Future<void> submitSellerOffer(OfferModel offer) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User session unauthenticated.');
    }

    final Map<String, dynamic> offerData = {
      'id': offer.id,
      'needId': offer.needId,
      'sellerId': offer.sellerId,
      'sellerName': offer.sellerName,
      'offeredPrice': offer.offeredPrice,
      'message': offer.message,
      'createdAt': ServerValue.timestamp,
      'status': offer.status,
      'deliveryTime': offer.deliveryTime,
      'extraNotes': offer.extraNotes,
    };

    // Save offer under needId
    await _database.child('offers').child(offer.needId).push().set(offerData);

    // Update offer count on need
    final needRef = _database.child('needs').child(offer.needId);
    final snapshot = await needRef.child('offers').get();

    int currentOffers = 0;
    if (snapshot.exists) {
      currentOffers = snapshot.value as int? ?? 0;
    }

    await needRef.child('offers').set(currentOffers + 1);
  }

  // ============================================================
  // ✅ GET OFFERS FOR A NEED
  // ============================================================
  Stream<List<OfferModel>> streamOffersForNeed(String needId) {
    return _database.child('offers').child(needId).onValue.map((event) {
      final List<OfferModel> offers = [];

      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> allMap =
            event.snapshot.value as Map<dynamic, dynamic>;

        allMap.forEach((key, value) {
          final data = Map<String, dynamic>.from(value as Map);

          final offer = OfferModel(
            id: key,
            needId: data['needId'] ?? needId,
            sellerId: data['sellerId'] ?? '',
            sellerName: data['sellerName'] ?? 'Anonymous',
            offeredPrice: (data['offeredPrice'] ?? 0).toDouble(),
            message: data['message'] ?? '',
            createdAt: data['createdAt'] != null
                ? DateTime.fromMillisecondsSinceEpoch(data['createdAt'])
                : DateTime.now(),
            status: data['status'] ?? 'pending',
            deliveryTime: data['deliveryTime'] ?? '3 days',
            extraNotes: data['extraNotes'] ?? '',
          );

          offers.add(offer);
        });
      }

      offers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return offers;
    });
  }

  // ============================================================
  // ✅ UPDATE OFFER STATUS
  // ============================================================
  Future<void> updateOfferStatus(
      String needId, String offerId, String status) async {
    await _database
        .child('offers')
        .child(needId)
        .child(offerId)
        .child('status')
        .set(status);
  }

  // ============================================================
  // ✅ GET NEED BY ID
  // ============================================================
  Future<NeedModel?> getNeedById(String needId) async {
    final snapshot = await _database.child('needs').child(needId).get();

    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.value as Map<dynamic, dynamic>;
    return NeedModel(
      id: needId,
      userId: data['userId'] ?? data['authorId'] ?? '',
      userName: data['userName'] ?? data['authorName'] ?? 'Anonymous',
      category: data['category'] ?? 'General',
      company: data['company'],
      customCompanyName: data['customCompanyName'],
      condition: data['condition'] ?? 'New',
      paymentMethod: data['paymentMethod'] ?? 'Cash',
      budget: (data['budget'] ?? 0).toDouble(),
      description: data['description'] ?? '',
      createdAt: data['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'])
          : DateTime.now(),
    );
  }

  // ============================================================
  // ✅ DELETE NEED
  // ============================================================
  Future<void> deleteNeed(String needId) async {
    await _database.child('needs').child(needId).remove();
    await _database.child('offers').child(needId).remove();
  }

  // ============================================================
  // ✅ DELETE OFFER
  // ============================================================
  Future<void> deleteOffer(String needId, String offerId) async {
    await _database.child('offers').child(needId).child(offerId).remove();
  }
}
