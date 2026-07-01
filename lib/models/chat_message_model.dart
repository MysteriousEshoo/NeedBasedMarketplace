class ChatMessageModel {
  final String id;
  final String senderId;
  final String timestamp;
  final String type; // 'text' | 'image' | 'video' | 'voice' | 'file'
  final String content; // text message or file download URL
  final bool seen;

  ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.timestamp,
    required this.type,
    required this.content,
    required this.seen,
  });

  Map<String, dynamic> toRTDB() {
    return {
      'id': id,
      'senderId': senderId,
      'timestamp': timestamp,
      'type': type,
      'content': content,
      'seen': seen,
    };
  }

  factory ChatMessageModel.fromRTDB(String key, Map<dynamic, dynamic> data) {
    return ChatMessageModel(
      id: key,
      senderId: data['senderId'] ?? '',
      timestamp:
          data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: data['type'] ?? 'text',
      content: data['content'] ?? '',
      seen: data['seen'] ?? false,
    );
  }
}
