import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class CallService {
  static const String _appId =
      'YOUR_AGORA_APP_ID'; // ✅ Replace with your Agora App ID

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // ✅ Generate unique channel name
  String getChannelName(String userId1, String userId2, String needId) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}_$needId';
  }

  // ✅ Start a call
  Future<void> startCall({
    required String receiverId,
    required String needId,
    required String needTitle,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final channelName = getChannelName(user.uid, receiverId, needId);

    // ✅ Save call info to Firebase
    await _db.child('calls').child(needId).push().set({
      'callerId': user.uid,
      'callerName': user.displayName ?? 'User',
      'receiverId': receiverId,
      'channelName': channelName,
      'status': 'ringing',
      'timestamp': ServerValue.timestamp,
    });
  }

  // ✅ Get Agora token (for production use)
  // For now, using temp token - in production, implement token server
  Future<String> getToken(String channelName) async {
    // In production, call your token server
    // For demo, using a placeholder
    return 'temp_token_placeholder';
  }
}

// ✅ Call status enum
enum CallStatus {
  ringing,
  connected,
  ended,
  missed,
}
