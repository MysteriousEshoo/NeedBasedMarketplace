import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../theme/app_colors.dart';

class VoiceMessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;
  final Color bubbleBg;

  const VoiceMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.bubbleBg,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;

  @override
  void initState() {
    super.initState();
    _total = Duration(seconds: widget.message.duration ?? 0);
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
    _player.onDurationChanged.listen((d) {
      if (mounted && d.inSeconds > 0) {
        setState(() => _total = d);
      }
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    final url = widget.message.mediaUrl;
    if (url == null || url.isEmpty) return;

    try {
      if (_isPlaying) {
        await _player.pause();
        if (mounted) setState(() => _isPlaying = false);
        return;
      }

      await _player.play(UrlSource(url));
      if (mounted) setState(() => _isPlaying = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not play voice message')),
        );
      }
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.isMe;
    final bubbleBg = widget.bubbleBg;
    final totalSeconds = _total.inSeconds > 0
        ? _total.inSeconds
        : (widget.message.duration ?? 0);
    final progress = totalSeconds > 0
        ? (_position.inMilliseconds / (totalSeconds * 1000)).clamp(0.0, 1.0)
        : 0.0;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: _togglePlayback,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.74,
            minWidth: 180,
          ),
          decoration: BoxDecoration(
            color: isMe ? AppColors.primary : bubbleBg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: isMe ? Colors.white : AppColors.primary,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor: isMe
                            ? Colors.white24
                            : AppColors.border,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isMe ? Colors.white : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(
                            _isPlaying || _position.inSeconds > 0
                                ? _position
                                : Duration(seconds: totalSeconds),
                          ),
                          style: TextStyle(
                            color: isMe ? Colors.white70 : AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          widget.message.formattedTime,
                          style: TextStyle(
                            color: isMe ? Colors.white60 : AppColors.textTertiary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
