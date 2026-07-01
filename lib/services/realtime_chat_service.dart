import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/chat_message_model.dart';

class RealtimeChatService {
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Resolve chat ID deterministic sequencing
  String getChatChannelId(String userA, String userB) {
    return userA.hashCode <= userB.hashCode
        ? '${userA}_$userB'
        : '${userB}_$userA';
  }

  // Stream real-time database nodes
  Stream<List<ChatMessageModel>> streamChatMessages(String channelId) {
    return _rtdb
        .ref()
        .child('chats')
        .child(channelId)
        .child('messages')
        .orderByChild('timestamp')
        .onValue
        .map((event) {
      final List<ChatMessageModel> logs = [];
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        data.forEach((key, val) {
          logs.add(
              ChatMessageModel.fromRTDB(key, val as Map<dynamic, dynamic>));
        });
        logs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      }
      return logs;
    });
  }

  // Upload dynamic asset to structural path targets
  Future<String> uploadChatAsset(
      String channelId, File file, String type) async {
    final String extension = file.path.split('.').last;
    final String path =
        'chats/$channelId/${type}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final ref = _storage.ref().child(path);
    final uploadTask = await ref.putFile(file);
    return await uploadTask.ref.getDownloadURL();
  }

  // Send message packet entry to Realtime DB nodes
  Future<void> pushMessagePacket(String channelId, ChatMessageModel msg) async {
    final ref =
        _rtdb.ref().child('chats').child(channelId).child('messages').push();
    await ref.set(msg.toRTDB());
  }

  // Set typing matrix nodes
  Future<void> updateTypingStatus(
      String channelId, String userId, bool isTyping) async {
    await _rtdb
        .ref()
        .child('chats')
        .child(channelId)
        .child('typing')
        .child(userId)
        .set(isTyping);
  }
}
