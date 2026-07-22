import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class CallService {
  /// 🔴 IMPORTANT: Replace with your Agora App ID
  /// 1. Go to https://console.agora.io
  /// 2. Create a project → copy the App ID
  /// 3. Paste it below
  static const String _appId = 'YOUR_AGORA_APP_ID';

  /// 🔴 IMPORTANT: Agora Token Server URL
  /// For production, you need a token server.
  /// Deploy the token server from: https://github.com/AgoraIO-Community/agora-token-service
  /// Then paste its URL below (e.g. 'https://your-token-server.com')
  static const String _tokenServerUrl = 'YOUR_TOKEN_SERVER_URL';

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

  /// 🎤 Get an Agora token from the token server for a given channel.
  /// Falls back to a temp token so the app doesn't crash during development.
  Future<String> getToken(String channelName) async {
    try {
      // 🔁 Try fetching a real token from the token server first.
      if (_tokenServerUrl.startsWith('http')) {
        final uri = Uri.parse('$_tokenServerUrl/rtc/$channelName/uid/0');
        // In production, use http package to fetch: http.get(uri)
        // For now, fall through to the temp placeholder.
      }
    } catch (_) {
      // Token server unreachable — return temp token for testing.
    }

    // ⚠️ TEMP: This placeholder token only works in Agora test mode.
    // 🔴 YOU NEED TO:
    // 1. Replace _appId with your real Agora App ID
    // 2. Deploy a token server (see instructions above)
    // 3. Replace _tokenServerUrl with your deployed server URL
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
