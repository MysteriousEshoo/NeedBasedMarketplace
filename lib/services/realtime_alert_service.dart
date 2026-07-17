import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/seller_request_model.dart';
import 'local_notification_service.dart';

/// 📡 Real-time alert engine (WhatsApp style).
///
/// While the user is signed in this service keeps two live listeners on the
/// Realtime Database:
///
/// 1. `notifications/{uid}` — every NEW in-app notification that lands in the
///    database instantly pops a heads-up banner on top of the phone (exactly
///    like WhatsApp) in addition to appearing on the in-app notification bar.
///
/// 2. `needs` — when the user is in SELLER MODE with an approved registered
///    business, every new need posted by a buyer whose category relates to
///    the seller's business category creates a notification for the seller.
///    Unrelated needs are ignored, so sellers only hear about relevant leads.
class RealtimeAlertService {
  RealtimeAlertService._();
  static final RealtimeAlertService instance = RealtimeAlertService._();

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  String? _uid;
  int _startMs = 0;

  bool _notificationsEnabled = true;
  bool _isSellerMode = false;
  String _sellerCategory = '';
  bool _sellerApproved = false;

  StreamSubscription<DatabaseEvent>? _notifSub;
  StreamSubscription<DatabaseEvent>? _needsSub;
  StreamSubscription<DatabaseEvent>? _settingsSub;
  StreamSubscription<DatabaseEvent>? _sellerReqSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;
  StreamSubscription<User?>? _authSub;

  /// Binds the service to the auth state: listeners start on login and are
  /// torn down on logout. Call once from main().
  void bindToAuth() {
    _authSub ??= FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        stop();
      } else {
        start();
      }
    });
  }

  /// Maps a registered business category to the need categories it covers.
  /// A seller only gets notified for needs inside their own line of business.
  static const Map<String, List<String>> _categoryMap = {
    'electronics': ['electronics', 'mobile phone', 'tech & development'],
    'fashion & apparel': ['fashion & apparel', 'design & creative'],
    'home & furniture': ['home & furniture', 'home & repair'],
    'food & groceries': ['food & groceries', 'delivery & logistics'],
    'services': [
      'services',
      'local services',
      'delivery & logistics',
      'tutoring',
      'design & creative',
      'home & repair',
      'tech & development',
    ],
    'vehicles': ['vehicles'],
    'health & beauty': ['health & beauty'],
  };

  /// Call once the user is authenticated (MainShell). Safe to call twice.
  Future<void> start() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_uid == user.uid) return; // already running for this user

    stop();
    _uid = user.uid;
    _startMs = DateTime.now().millisecondsSinceEpoch;

    await LocalNotificationService.instance.init();

    _listenToSettings();
    _listenToSellerProfile();
    _listenToIncomingNotifications();
    _listenToNewNeeds();
  }

  void stop() {
    _notifSub?.cancel();
    _needsSub?.cancel();
    _settingsSub?.cancel();
    _sellerReqSub?.cancel();
    _userDocSub?.cancel();
    _notifSub = null;
    _needsSub = null;
    _settingsSub = null;
    _sellerReqSub = null;
    _userDocSub = null;
    _uid = null;
  }

  // ---------------------------------------------------------------------
  // 1) Heads-up popup for every new in-app notification (WhatsApp style)
  // ---------------------------------------------------------------------

  void _listenToIncomingNotifications() {
    _notifSub = _db
        .child('notifications')
        .child(_uid!)
        .orderByChild('timestamp')
        .startAt(_startMs.toDouble())
        .onChildAdded
        .listen((event) {
      if (!_notificationsEnabled) return;
      final value = event.snapshot.value;
      if (value is! Map) return;

      final data = Map<dynamic, dynamic>.from(value);
      final title = (data['title'] ?? '').toString();
      final body = (data['body'] ?? '').toString();
      if (title.isEmpty && body.isEmpty) return;

      LocalNotificationService.instance.show(title: title, body: body);
    });
  }

  // ---------------------------------------------------------------------
  // 2) Seller-mode: alert on new buyer needs matching the business category
  // ---------------------------------------------------------------------

  void _listenToNewNeeds() {
    _needsSub = _db
        .child('needs')
        .orderByChild('timestamp')
        .startAt(_startMs.toDouble())
        .onChildAdded
        .listen((event) async {
      if (!_isSellerMode || !_sellerApproved) return;
      if (!_notificationsEnabled) return;

      final value = event.snapshot.value;
      if (value is! Map) return;
      final data = Map<dynamic, dynamic>.from(value);

      final authorId = (data['authorId'] ?? data['userId'] ?? '').toString();
      if (authorId == _uid) return; // never alert on own posts

      final needCategory = (data['category'] ?? '').toString();
      if (!_matchesSellerCategory(needCategory)) return;

      final title = (data['title'] ?? 'New need posted').toString();
      final budget = (data['budget'] ?? 0).toString();
      final authorName = (data['authorName'] ?? 'A buyer').toString();
      final needId = event.snapshot.key ?? '';

      // Idempotent write (deterministic key): if two of the seller's devices
      // race, the second write just overwrites the same node — no duplicates.
      await _db
          .child('notifications')
          .child(_uid!)
          .child('need_match_$needId')
          .set({
        'title': '🎯 New "$needCategory" need for your business',
        'body': '$authorName posted "$title" — budget Rs. $budget. '
            'Open Seller Dashboard to send an offer.',
        'type': 'need_match',
        'data': needId,
        'timestamp': ServerValue.timestamp,
        'seen': false,
      });
      // The notifications listener above fires the heads-up popup for this
      // entry automatically, and the in-app bell badge updates in real time.
    });
  }

  bool _matchesSellerCategory(String needCategory) {
    if (needCategory.isEmpty) return false;
    final seller = _sellerCategory.trim().toLowerCase();
    final need = needCategory.trim().toLowerCase();
    if (seller.isEmpty) return false;

    // "Other" businesses have no defined line — match every need.
    if (seller == 'other') return true;
    // Direct match always counts.
    if (seller == need) return true;
    return _categoryMap[seller]?.contains(need) ?? false;
  }

  // ---------------------------------------------------------------------
  // Live profile/settings state
  // ---------------------------------------------------------------------

  void _listenToSettings() {
    _settingsSub = _db
        .child('user_settings')
        .child(_uid!)
        .child('notifications')
        .onValue
        .listen((event) {
      _notificationsEnabled = event.snapshot.value as bool? ?? true;
    });
  }

  void _listenToSellerProfile() {
    final uid = _uid!;

    _userDocSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
      _isSellerMode = snapshot.data()?['isSellerMode'] ?? false;
    });

    _sellerReqSub =
        _db.child('seller_requests').child(uid).onValue.listen((event) {
      if (event.snapshot.value is Map) {
        final data =
            Map<String, dynamic>.from(event.snapshot.value as Map);
        final request = SellerRequest.fromMap(uid, data);
        _sellerApproved = request.status == SellerRequestStatus.approved;
        _sellerCategory = request.category;
      } else {
        _sellerApproved = false;
        _sellerCategory = '';
      }
    });
  }
}
