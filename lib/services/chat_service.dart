import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/message_model.dart';
import '../models/offer_model.dart';

class ChatService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  String getChannelId(String userId1, String userId2, String needId) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}_$needId';
  }

  Future<void> sendMessage({
    required String receiverId,
    required String receiverName,
    required String needId,
    required String needTitle,
    required String content,
    String type = 'text',
    String? mediaUrl,
    String? offerId,
    String? offerStatus,
    bool? chatDisabled,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final senderId = user.uid;
    final senderName =
        user.displayName ?? user.email?.split('@').first ?? 'User';
    final channelId = getChannelId(senderId, receiverId, needId);
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    final lastMessage = type == 'text' ? content : 'Offer';

    final message = MessageModel(
      id: '',
      senderId: senderId,
      senderName: senderName,
      receiverId: receiverId,
      receiverName: receiverName,
      needId: needId,
      content: content,
      type: type,
      timestamp: DateTime.fromMillisecondsSinceEpoch(nowMillis),
      status: 'sent',
      mediaUrl: mediaUrl,
    );

    final msgRef = _db.child('chats').child(needId).child(channelId).push();
    await msgRef.set(message.toMap());

    final senderChatData = <String, Object?>{
      'channelId': channelId,
      'needId': needId,
      'needTitle': needTitle,
      'peerId': receiverId,
      'peerName': receiverName,
      'lastMessage': lastMessage,
      'lastTimestamp': nowMillis,
      'unreadCount': 0,
      'iAmSender': true,
      if (offerId != null) 'offerId': offerId,
      if (offerStatus != null) 'offerStatus': offerStatus,
      if (chatDisabled != null) 'chatDisabled': chatDisabled,
    };

    await _db
        .child('user_chats')
        .child(senderId)
        .child(channelId)
        .update(senderChatData);

    final receiverChatRef =
        _db.child('user_chats').child(receiverId).child(channelId);

    final snap = await receiverChatRef.child('unreadCount').get();
    final currentUnread = snap.exists ? (snap.value as int? ?? 0) : 0;

    final receiverChatData = <String, Object?>{
      'channelId': channelId,
      'needId': needId,
      'needTitle': needTitle,
      'peerId': senderId,
      'peerName': senderName,
      'lastMessage': lastMessage,
      'lastTimestamp': nowMillis,
      'unreadCount': currentUnread + 1,
      'iAmSender': false,
      if (offerId != null) 'offerId': offerId,
      if (offerStatus != null) 'offerStatus': offerStatus,
      if (chatDisabled != null) 'chatDisabled': chatDisabled,
    };

    await receiverChatRef.update(receiverChatData);
    await msgRef.child('status').set('delivered');
  }

  Future<void> sendSystemMessage({
    required String receiverId,
    required String needId,
    required String needTitle,
    required String content,
    String receiverName = 'User',
    String? offerId,
    String? offerStatus,
    bool? chatDisabled,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final senderId = user.uid;
    final currentUserName =
        user.displayName ?? user.email?.split('@').first ?? 'User';
    final channelId = getChannelId(senderId, receiverId, needId);
    final nowMillis = DateTime.now().millisecondsSinceEpoch;

    final message = MessageModel(
      id: '',
      senderId: senderId,
      senderName: 'System',
      receiverId: receiverId,
      receiverName: receiverName,
      needId: needId,
      content: content,
      type: 'system',
      timestamp: DateTime.fromMillisecondsSinceEpoch(nowMillis),
      status: 'sent',
      mediaUrl: null,
    );

    final msgRef = _db.child('chats').child(needId).child(channelId).push();
    await msgRef.set(message.toMap());

    final senderChatData = <String, Object?>{
      'channelId': channelId,
      'needId': needId,
      'needTitle': needTitle,
      'peerId': receiverId,
      'peerName': receiverName,
      'lastMessage': content,
      'lastTimestamp': nowMillis,
      'unreadCount': 0,
      'iAmSender': true,
      if (offerId != null) 'offerId': offerId,
      if (offerStatus != null) 'offerStatus': offerStatus,
      if (chatDisabled != null) 'chatDisabled': chatDisabled,
    };

    await _db
        .child('user_chats')
        .child(senderId)
        .child(channelId)
        .update(senderChatData);

    final receiverChatRef =
        _db.child('user_chats').child(receiverId).child(channelId);

    final snap = await receiverChatRef.child('unreadCount').get();
    final currentUnread = snap.exists ? (snap.value as int? ?? 0) : 0;

    final receiverChatData = <String, Object?>{
      'channelId': channelId,
      'needId': needId,
      'needTitle': needTitle,
      'peerId': senderId,
      'peerName': currentUserName,
      'lastMessage': content,
      'lastTimestamp': nowMillis,
      'unreadCount': currentUnread + 1,
      'iAmSender': false,
      if (offerId != null) 'offerId': offerId,
      if (offerStatus != null) 'offerStatus': offerStatus,
      if (chatDisabled != null) 'chatDisabled': chatDisabled,
    };

    await receiverChatRef.update(receiverChatData);
  }

  Stream<OfferModel?> watchOfferForChat({
    required String needId,
    required String otherUserId,
  }) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final sellerCandidates = {currentUserId, otherUserId};

    return _db.child('offers').child(needId).onValue.map((event) {
      final offers = <OfferModel>[];
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is! Map) return;
          final offerMap = Map<String, dynamic>.from(value);
          if (sellerCandidates.contains(offerMap['sellerId'])) {
            offers.add(OfferModel.fromMap(key.toString(), offerMap));
          }
        });
      }

      if (offers.isEmpty) return null;
      offers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return offers.first;
    });
  }

  Future<void> updateOfferDecision({
    required String needId,
    required String needTitle,
    required String offerId,
    required String buyerId,
    required String buyerName,
    required String sellerId,
    required String sellerName,
    required String status,
  }) async {
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    final channelId = getChannelId(buyerId, sellerId, needId);
    final chatDisabled = status != 'accepted';
    final statusMessage =
        status == 'accepted' ? 'Offer accepted' : 'Offer rejected';

    await _db.child('offers').child(needId).child(offerId).update({
      'status': status,
      'respondedAt': nowMillis,
    });

    await _db.child('user_chats').child(buyerId).child(channelId).update({
      'channelId': channelId,
      'needId': needId,
      'needTitle': needTitle,
      'peerId': sellerId,
      'peerName': sellerName,
      'offerId': offerId,
      'offerStatus': status,
      'chatDisabled': chatDisabled,
      'lastMessage': statusMessage,
      'lastTimestamp': nowMillis,
    });

    await _db.child('user_chats').child(sellerId).child(channelId).update({
      'channelId': channelId,
      'needId': needId,
      'needTitle': needTitle,
      'peerId': buyerId,
      'peerName': buyerName,
      'offerId': offerId,
      'offerStatus': status,
      'chatDisabled': chatDisabled,
      'lastMessage': statusMessage,
      'lastTimestamp': nowMillis,
    });
  }

  Stream<List<MessageModel>> getMessages({
    required String needId,
    required String otherUserId,
  }) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final channelId = getChannelId(currentUserId, otherUserId, needId);

    return _db
        .child('chats')
        .child(needId)
        .child(channelId)
        .orderByChild('timestamp')
        .onValue
        .map((event) {
      final List<MessageModel> messages = [];
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          messages.add(MessageModel.fromMap(
              key, Map<String, dynamic>.from(value as Map)));
        });
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      }
      return messages;
    });
  }

  Future<void> markMessagesAsSeen({
    required String needId,
    required String otherUserId,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final channelId = getChannelId(currentUserId, otherUserId, needId);

    final chatRef = _db.child('chats').child(needId).child(channelId);
    final snap = await chatRef.get();

    if (snap.exists) {
      final data = snap.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        final msg = Map<String, dynamic>.from(value as Map);
        if (msg['receiverId'] == currentUserId && msg['status'] != 'seen') {
          chatRef.child(key).child('status').set('seen');
        }
      });
    }

    await _db
        .child('user_chats')
        .child(currentUserId)
        .child(channelId)
        .child('unreadCount')
        .set(0);
  }

  Stream<List<Map<String, dynamic>>> getUserChats(
    String userId, {
    bool acceptedOnly = false,
  }) {
    return _db.child('user_chats').child(userId).onValue.map((event) {
      final List<Map<String, dynamic>> chats = [];
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((channelId, value) {
          final chat = Map<String, dynamic>.from(value as Map);
          if (acceptedOnly && chat['offerStatus'] != 'accepted') {
            return;
          }
          chat['channelId'] = channelId.toString();
          chats.add(chat);
        });
        chats.sort((a, b) => ((b['lastTimestamp'] ?? 0) as int)
            .compareTo((a['lastTimestamp'] ?? 0) as int));
      }
      return chats;
    });
  }

  Future<Map<String, dynamic>?> getNeedDetails(String needId) async {
    try {
      final snap = await _db.child('needs').child(needId).get();
      if (snap.exists) {
        return Map<String, dynamic>.from(snap.value as Map);
      }
    } catch (_) {}
    return null;
  }
}
