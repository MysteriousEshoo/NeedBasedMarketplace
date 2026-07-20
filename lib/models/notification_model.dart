class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type; // 'offer', 'message', 'system'
  final String? data;

  /// Which side of the account this notification belongs to: 'buyer' or
  /// 'seller'. Null for general notifications that apply to both.
  final String? audience;
  final DateTime timestamp;
  final bool seen;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.data,
    this.audience,
    required this.timestamp,
    this.seen = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'type': type,
      'data': data,
      if (audience != null) 'audience': audience,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'seen': seen,
    };
  }

  factory NotificationModel.fromMap(String id, Map<String, dynamic> map) {
    return NotificationModel(
      id: id,
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? 'system',
      data: map['data'],
      audience: map['audience'],
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'])
          : DateTime.now(),
      seen: map['seen'] ?? false,
    );
  }

  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}
