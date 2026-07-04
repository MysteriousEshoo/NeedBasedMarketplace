import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/message_model.dart';

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
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final senderId = user.uid;
    final senderName =
        user.displayName ?? user.email?.split('@').first ?? 'User';
    final channelId = getChannelId(senderId, receiverId, needId);
    final nowMillis = DateTime.now().millisecondsSinceEpoch;

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

    await _db.child('user_chats').child(senderId).child(channelId).set({
      'channelId': channelId,
      'needId': needId,
      'needTitle': needTitle,
      'peerId': receiverId,
      'peerName': receiverName,
      'lastMessage': type == 'text' ? content : '📎 Media',
      'lastTimestamp': nowMillis,
      'unreadCount': 0,
      'iAmSender': true,
    });

    final receiverChatRef =
        _db.child('user_chats').child(receiverId).child(channelId);

    final snap = await receiverChatRef.child('unreadCount').get();
    final currentUnread = snap.exists ? (snap.value as int? ?? 0) : 0;

    await receiverChatRef.set({
      'channelId': channelId,
      'needId': needId,
      'needTitle': needTitle,
      'peerId': senderId,
      'peerName': senderName,
      'lastMessage': type == 'text' ? content : '📎 Media',
      'lastTimestamp': nowMillis,
      'unreadCount': currentUnread + 1,
      'iAmSender': false,
    });

    await msgRef.child('status').set('delivered');
  }

  Future<void> sendSystemMessage({
    required String receiverId,
    required String needId,
    required String needTitle,
    required String content,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final senderId = user.uid;
    final senderName = 'System';
    final channelId = getChannelId(senderId, receiverId, needId);
    final nowMillis = DateTime.now().millisecondsSinceEpoch;

    final message = MessageModel(
      id: '',
      senderId: senderId,
      senderName: senderName,
      receiverId: receiverId,
      receiverName: 'User',
      needId: needId,
      content: content,
      type: 'system',
      timestamp: DateTime.fromMillisecondsSinceEpoch(nowMillis),
      status: 'sent',
      mediaUrl: null,
    );

    final msgRef = _db.child('chats').child(needId).child(channelId).push();
    await msgRef.set(message.toMap());

    await _db.child('user_chats').child(senderId).child(channelId).set({
      'channelId': channelId,
      'needId': needId,
      'needTitle': needTitle,
      'peerId': receiverId,
      'peerName': 'System',
      'lastMessage': content,
      'lastTimestamp': nowMillis,
      'unreadCount': 0,
      'iAmSender': true,
    });

    final receiverChatRef =
        _db.child('user_chats').child(receiverId).child(channelId);

    final snap = await receiverChatRef.child('unreadCount').get();
    final currentUnread = snap.exists ? (snap.value as int? ?? 0) : 0;

    await receiverChatRef.set({
      'channelId': channelId,
      'needId': needId,
      'needTitle': needTitle,
      'peerId': senderId,
      'peerName': 'System',
      'lastMessage': content,
      'lastTimestamp': nowMillis,
      'unreadCount': currentUnread + 1,
      'iAmSender': false,
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

    final snap = await _db
        .child('chats')
        .child(needId)
        .child(channelId)
        .orderByChild('receiverId')
        .equalTo(currentUserId)
        .get();

    if (snap.exists) {
      final data = snap.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        final msg = Map<String, dynamic>.from(value as Map);
        if (msg['status'] != 'seen') {
          _db
              .child('chats')
              .child(needId)
              .child(channelId)
              .child(key)
              .child('status')
              .set('seen');
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

  Stream<List<Map<String, dynamic>>> getUserChats(String userId) {
    return _db.child('user_chats').child(userId).onValue.map((event) {
      final List<Map<String, dynamic>> chats = [];
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((channelId, value) {
          final chat = Map<String, dynamic>.from(value as Map);
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
