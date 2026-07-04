class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String receiverId;
  final String receiverName;
  final String needId;
  final String content;
  final String type;
  final DateTime timestamp;
  final String status;
  final String? mediaUrl;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.receiverName,
    required this.needId,
    required this.content,
    this.type = 'text',
    required this.timestamp,
    this.status = 'sent',
    this.mediaUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'needId': needId,
      'content': content,
      'type': type,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'status': status,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
    };
  }

  factory MessageModel.fromMap(String id, Map<String, dynamic> map) {
    return MessageModel(
      id: id,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? 'User',
      receiverId: map['receiverId'] ?? '',
      receiverName: map['receiverName'] ?? 'User',
      needId: map['needId'] ?? '',
      content: map['content'] ?? '',
      type: map['type'] ?? 'text',
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'])
          : DateTime.now(),
      status: map['status'] ?? 'sent',
      mediaUrl: map['mediaUrl'],
    );
  }

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}
