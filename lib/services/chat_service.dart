import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/message_model.dart';
import '../models/offer_model.dart';

class ChatService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String getChannelId(String userId1, String userId2, String needId) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}_$needId';
  }

  String _userName(User user) {
    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    return user.email?.split('@').first ?? 'User';
  }

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  String _safePathSegment(String value) {
    return value.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
  }

  String _fileExtension(String path) {
    final name = path.split(RegExp(r'[\\/]')).last;
    if (!name.contains('.')) return '';
    return name.split('.').last.toLowerCase();
  }

  String _contentTypeFor(String type, String path) {
    final ext = _fileExtension(path);
    if (type == 'voice') return 'audio/mp4';
    if (type == 'image') {
      return switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        _ => 'image/jpeg',
      };
    }
    if (type == 'video') return 'video/mp4';
    return switch (ext) {
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt' => 'application/vnd.ms-powerpoint',
      'txt' => 'text/plain',
      'zip' => 'application/zip',
      _ => 'application/octet-stream',
    };
  }

  Future<void> _waitForUploadableFile(File file) async {
    for (var attempt = 0; attempt < 8; attempt++) {
      if (await file.exists()) {
        final length = await file.length();
        if (length > 0) return;
      }
      await Future.delayed(const Duration(milliseconds: 150));
    }

    throw Exception('Selected media file is empty or not ready yet.');
  }

  Future<String> _downloadUrlWithRetry(Reference ref) async {
    Object? lastError;
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        return await ref.getDownloadURL();
      } catch (e) {
        lastError = e;
        await Future.delayed(Duration(milliseconds: 250 * (attempt + 1)));
      }
    }
    throw Exception('Could not get uploaded media URL: $lastError');
  }

  Future<String> _uploadChatMedia({
    required String needId,
    required String channelId,
    required File file,
    required String type,
    required String storageFileName,
  }) async {
    await _waitForUploadableFile(file);

    final ref = _storage
        .ref()
        .child('chats')
        .child(_safePathSegment(needId))
        .child(_safePathSegment(channelId))
        .child(storageFileName);
    final snapshot = await ref.putFile(
      file,
      SettableMetadata(contentType: _contentTypeFor(type, file.path)),
    );

    if (snapshot.bytesTransferred <= 0) {
      throw Exception('Firebase Storage upload did not transfer any bytes.');
    }

    return _downloadUrlWithRetry(snapshot.ref);
  }

  Future<void> _writeMessageAndChatPreviews({
    required MessageModel message,
    required String needTitle,
    required String lastMessage,
    required String currentUserPeerName,
    String? offerId,
    String? offerStatus,
    bool? chatDisabled,
    bool markDelivered = true,
  }) async {
    final channelId =
        getChannelId(message.senderId, message.receiverId, message.needId);
    final nowMillis = message.timestamp.millisecondsSinceEpoch;
    final msgRef =
        _db.child('chats').child(message.needId).child(channelId).push();

    await msgRef.set(message.toMap());

    final senderChatData = <String, Object?>{
      'channelId': channelId,
      'needId': message.needId,
      'needTitle': needTitle,
      'peerId': message.receiverId,
      'peerName': message.receiverName,
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
        .child(message.senderId)
        .child(channelId)
        .update(senderChatData);

    final receiverChatRef =
        _db.child('user_chats').child(message.receiverId).child(channelId);
    final unreadSnap = await receiverChatRef.child('unreadCount').get();
    final currentUnread = _asInt(unreadSnap.value);

    final receiverChatData = <String, Object?>{
      'channelId': channelId,
      'needId': message.needId,
      'needTitle': needTitle,
      'peerId': message.senderId,
      'peerName': currentUserPeerName,
      'lastMessage': lastMessage,
      'lastTimestamp': nowMillis,
      'unreadCount': currentUnread + 1,
      'iAmSender': false,
      if (offerId != null) 'offerId': offerId,
      if (offerStatus != null) 'offerStatus': offerStatus,
      if (chatDisabled != null) 'chatDisabled': chatDisabled,
    };

    await receiverChatRef.update(receiverChatData);

    if (markDelivered) {
      await msgRef.child('status').set('delivered');
    }
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

    final senderName = _userName(user);
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    final lastMessage = type == 'text' ? content : content.split('\n').first;

    final message = MessageModel(
      id: '',
      senderId: user.uid,
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

    await _writeMessageAndChatPreviews(
      message: message,
      needTitle: needTitle,
      lastMessage: lastMessage,
      currentUserPeerName: senderName,
      offerId: offerId,
      offerStatus: offerStatus,
      chatDisabled: chatDisabled,
    );
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

    final currentUserName = _userName(user);
    final nowMillis = DateTime.now().millisecondsSinceEpoch;

    final message = MessageModel(
      id: '',
      senderId: user.uid,
      senderName: 'System',
      receiverId: receiverId,
      receiverName: receiverName,
      needId: needId,
      content: content,
      type: 'system',
      timestamp: DateTime.fromMillisecondsSinceEpoch(nowMillis),
      status: 'sent',
    );

    await _writeMessageAndChatPreviews(
      message: message,
      needTitle: needTitle,
      lastMessage: content,
      currentUserPeerName: currentUserName,
      offerId: offerId,
      offerStatus: offerStatus,
      chatDisabled: chatDisabled,
      markDelivered: false,
    );
  }

  Future<String> uploadVoiceMessage({
    required String needId,
    required String channelId,
    required File audioFile,
  }) async {
    final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    return _uploadChatMedia(
      needId: needId,
      channelId: channelId,
      file: audioFile,
      type: 'voice',
      storageFileName: fileName,
    );
  }

  Future<void> sendVoiceMessage({
    required String receiverId,
    required String receiverName,
    required String needId,
    required String needTitle,
    required File audioFile,
    int durationSeconds = 0,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final senderName = _userName(user);
    final channelId = getChannelId(user.uid, receiverId, needId);
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    final downloadUrl = await uploadVoiceMessage(
      needId: needId,
      channelId: channelId,
      audioFile: audioFile,
    );

    final message = MessageModel(
      id: '',
      senderId: user.uid,
      senderName: senderName,
      receiverId: receiverId,
      receiverName: receiverName,
      needId: needId,
      content: 'Voice message',
      type: 'voice',
      timestamp: DateTime.fromMillisecondsSinceEpoch(nowMillis),
      status: 'sent',
      mediaUrl: downloadUrl,
      duration: durationSeconds > 0 ? durationSeconds : 1,
    );

    await _writeMessageAndChatPreviews(
      message: message,
      needTitle: needTitle,
      lastMessage: 'Voice message',
      currentUserPeerName: senderName,
    );
  }

  Future<String> uploadFile({
    required String needId,
    required String channelId,
    required File file,
    required String type,
  }) async {
    final parts = file.path.split(RegExp(r'[\\/]'));
    final originalName = parts.isEmpty ? 'file' : parts.last;
    final extension =
        originalName.contains('.') ? originalName.split('.').last : 'bin';
    final fileName =
        '${type}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    return _uploadChatMedia(
      needId: needId,
      channelId: channelId,
      file: file,
      type: type,
      storageFileName: fileName,
    );
  }

  Future<void> sendFileMessage({
    required String receiverId,
    required String receiverName,
    required String needId,
    required String needTitle,
    required File file,
    required String type,
    String? fileName,
    int? fileSize,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final senderName = _userName(user);
    final channelId = getChannelId(user.uid, receiverId, needId);
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    final downloadUrl = await uploadFile(
      needId: needId,
      channelId: channelId,
      file: file,
      type: type,
    );

    final label = switch (type) {
      'image' => 'Image',
      'video' => fileName ?? 'Video',
      'document' => fileName ?? 'Document',
      _ => fileName ?? 'File',
    };

    final message = MessageModel(
      id: '',
      senderId: user.uid,
      senderName: senderName,
      receiverId: receiverId,
      receiverName: receiverName,
      needId: needId,
      content: label,
      type: type,
      timestamp: DateTime.fromMillisecondsSinceEpoch(nowMillis),
      status: 'sent',
      mediaUrl: downloadUrl,
      fileName: fileName,
      fileSize: fileSize,
    );

    await _writeMessageAndChatPreviews(
      message: message,
      needTitle: needTitle,
      lastMessage: label,
      currentUserPeerName: senderName,
    );
  }

  Stream<OfferModel?> watchOfferForChat({
    required String needId,
    required String otherUserId,
  }) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final sellerCandidates = {currentUserId, otherUserId};

    return _db.child('offers').child(needId).onValue.map((event) {
      final offers = <OfferModel>[];
      if (event.snapshot.value is Map) {
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
      final messages = <MessageModel>[];
      if (event.snapshot.value is Map) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is! Map) return;
          messages.add(
            MessageModel.fromMap(
              key.toString(),
              Map<String, dynamic>.from(value),
            ),
          );
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
    if (currentUserId.isEmpty) return;

    final channelId = getChannelId(currentUserId, otherUserId, needId);
    final chatRef = _db.child('chats').child(needId).child(channelId);
    final snap = await chatRef.get();

    if (snap.value is Map) {
      final data = snap.value as Map<dynamic, dynamic>;
      for (final entry in data.entries) {
        if (entry.value is! Map) continue;
        final msg = Map<String, dynamic>.from(entry.value as Map);
        if (msg['receiverId'] == currentUserId && msg['status'] != 'seen') {
          await chatRef.child(entry.key.toString()).child('status').set('seen');
        }
      }
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
      final chats = <Map<String, dynamic>>[];
      if (event.snapshot.value is Map) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((channelId, value) {
          if (value is! Map) return;
          final chat = Map<String, dynamic>.from(value);
          if (acceptedOnly && chat['offerStatus'] != 'accepted') return;
          chat['channelId'] = channelId.toString();
          chats.add(chat);
        });
        chats.sort((a, b) {
          final bTime = _asInt(b['lastTimestamp']);
          final aTime = _asInt(a['lastTimestamp']);
          return bTime.compareTo(aTime);
        });
      }
      return chats;
    });
  }

  Future<Map<String, dynamic>?> getNeedDetails(String needId) async {
    try {
      final directSnap = await _db.child('needs').child(needId).get();
      if (directSnap.value is Map) {
        final need = Map<String, dynamic>.from(directSnap.value as Map);
        need['id'] = needId;
        return need;
      }

      final querySnap =
          await _db.child('needs').orderByChild('id').equalTo(needId).get();
      if (querySnap.value is Map) {
        final data = querySnap.value as Map<dynamic, dynamic>;
        for (final entry in data.entries) {
          if (entry.value is! Map) continue;
          final need = Map<String, dynamic>.from(entry.value as Map);
          need['id'] = entry.key.toString();
          return need;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> deleteChatForUser({
    required String needId,
    required String otherUserId,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUserId.isEmpty) return;

    final channelId = getChannelId(currentUserId, otherUserId, needId);
    await _db
        .child('user_chats')
        .child(currentUserId)
        .child(channelId)
        .remove();
  }

  Future<OfferModel?> getOfferForChat({
    required String needId,
    required String otherUserId,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final sellerCandidates = {currentUserId, otherUserId};
    final snap = await _db.child('offers').child(needId).get();
    if (snap.value is! Map) return null;

    final offers = <OfferModel>[];
    final data = snap.value as Map<dynamic, dynamic>;
    data.forEach((key, value) {
      if (value is! Map) return;
      final offerMap = Map<String, dynamic>.from(value);
      if (sellerCandidates.contains(offerMap['sellerId'])) {
        offers.add(OfferModel.fromMap(key.toString(), offerMap));
      }
    });

    if (offers.isEmpty) return null;
    offers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return offers.first;
  }
}
