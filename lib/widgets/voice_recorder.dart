import 'dart:io';
import 'dart:async'; // ✅ ADD THIS - Timer ke liye
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';

class VoiceRecorder extends StatefulWidget {
  final void Function(File audioFile, int durationSeconds) onRecordComplete;
  final Color? accentColor;

  const VoiceRecorder({
    super.key,
    required this.onRecordComplete,
    this.accentColor,
  });

  @override
  State<VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  bool _isRecording = false;
  bool _isPlaying = false;
  bool _hasRecorded = false;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  Timer? _timer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // ✅ FIX: onPlayerComplete use karein
    _player.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    });
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    final micStatus = await Permission.microphone.request();
    if (micStatus.isDenied) {
      setState(() {
        _errorMessage =
            'Please grant microphone permission to record voice.';
      });
    }
  }

  void _startRecording() async {
    await _requestPermissions();

    try {
      if (await _recorder.hasPermission()) {
        final path =
            '${Directory.systemTemp.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _recorder.start(
          RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _recordingPath = path;
          _recordingDuration = Duration.zero;
        });

        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _recordingDuration =
                  _recordingDuration + const Duration(seconds: 1);
            });
          }
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to start recording: $e';
      });
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();

    try {
      final path = await _recorder.stop();
      if (mounted) {
        setState(() {
          _isRecording = false;
          _hasRecorded = true;
          _recordingPath = path;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to stop recording: $e';
        });
      }
    }
  }

  Future<void> _playRecording() async {
    if (_recordingPath == null) return;

    try {
      if (_isPlaying) {
        await _player.pause();
        if (mounted) setState(() => _isPlaying = false);
        return;
      }

      await _player.play(DeviceFileSource(_recordingPath!));
      if (mounted) setState(() => _isPlaying = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to play recording: $e';
        });
      }
    }
  }

  Future<void> _sendRecording() async {
    if (_recordingPath == null) return;

    final file = File(_recordingPath!);
    widget.onRecordComplete(file, _recordingDuration.inSeconds);
    if (mounted) Navigator.pop(context);
  }

  void _cancelRecording() {
    if (_isRecording) {
      _timer?.cancel();
      _recorder.stop();
    }
    if (mounted) Navigator.pop(context);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final accentColor = widget.accentColor ?? AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isRecording ? Icons.circle_rounded : Icons.mic_rounded,
                      color: _isRecording ? Colors.red : accentColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isRecording ? 'Recording...' : 'Voice Message',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                _formatDuration(_recordingDuration),
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: AppColors.urgentHigh,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isRecording)
                _BuildControlButton(
                  icon: Icons.stop_rounded,
                  label: 'Stop',
                  color: Colors.red,
                  onTap: _stopRecording,
                ),
              if (_hasRecorded && !_isRecording) ...[
                _BuildControlButton(
                  icon: _isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  label: _isPlaying ? 'Pause' : 'Play',
                  color: accentColor,
                  onTap: _playRecording,
                ),
                const SizedBox(width: 12),
                _BuildControlButton(
                  icon: Icons.send_rounded,
                  label: 'Send',
                  color: Colors.green,
                  onTap: _sendRecording,
                ),
              ],
              if (!_isRecording && !_hasRecorded)
                _BuildControlButton(
                  icon: Icons.mic_rounded,
                  label: 'Record',
                  color: accentColor,
                  onTap: _startRecording,
                ),
              const SizedBox(width: 12),
              _BuildControlButton(
                icon: Icons.close_rounded,
                label: 'Cancel',
                color: Colors.grey,
                onTap: _cancelRecording,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BuildControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _BuildControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
