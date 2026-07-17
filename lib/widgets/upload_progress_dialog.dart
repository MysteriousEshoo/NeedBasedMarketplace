import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_palette.dart';

/// 📶 Network-driven 0→100% progress dialog.
///
/// While [task] (the real network write) is running, the bar creeps toward
/// 90% — faster on a fast connection feel, slower as time passes — and the
/// moment the write is confirmed by the server it snaps to 100% and closes.
/// So the duration you see genuinely depends on your network speed.
///
/// Usage:
///   await UploadProgressDialog.run(context, task: ref.set(data));
class UploadProgressDialog extends StatefulWidget {
  const UploadProgressDialog._({required this.task, required this.label});

  final Future<void> task;
  final String label;

  /// Shows the dialog, runs [task], completes when the task finishes.
  /// Rethrows the task's error after closing the dialog.
  static Future<void> run(
    BuildContext context, {
    required Future<void> task,
    String label = 'Publishing your need...',
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: UploadProgressDialog._(
          task: task,
          label: label,
        ),
      ),
    );
    await task;
  }

  @override
  State<UploadProgressDialog> createState() => _UploadProgressDialogState();
}

class _UploadProgressDialogState extends State<UploadProgressDialog> {
  double _progress = 0;
  Timer? _ticker;
  bool _done = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();

    // Creep toward 90% while the network round-trip is pending. Each tick
    // covers 6% of the remaining distance, so it starts quick and slows —
    // on a fast network you'll only ever see a flash to 100%.
    _ticker = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (_done) return;
      setState(() => _progress += (0.90 - _progress) * 0.06);
    });

    widget.task.then(
      (_) => _finish(succeeded: true),
      onError: (_) => _finish(succeeded: false),
    );
  }

  Future<void> _finish({required bool succeeded}) async {
    if (!mounted || _done) return;
    _done = true;
    _ticker?.cancel();
    setState(() {
      _failed = !succeeded;
      if (succeeded) _progress = 1.0;
    });
    await Future.delayed(const Duration(milliseconds: 350));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final pct = (_progress * 100).round();

    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _failed
                  ? Icons.cloud_off_rounded
                  : pct == 100
                      ? Icons.check_circle_rounded
                      : Icons.cloud_upload_rounded,
              color: _failed
                  ? AppColors.urgentHigh
                  : pct == 100
                      ? AppColors.accent
                      : AppColors.primary,
              size: 44,
            ),
            const SizedBox(height: 16),
            Text(
              _failed
                  ? 'Upload interrupted'
                  : pct == 100
                      ? 'Posted!'
                      : widget.label,
              style: TextStyle(
                color: c.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: _progress),
                duration: const Duration(milliseconds: 200),
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _failed
                        ? AppColors.urgentHigh
                        : pct == 100
                            ? AppColors.accent
                            : AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$pct%',
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
