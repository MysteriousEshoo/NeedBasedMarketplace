import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';

/// Simple tooltip-based user guide that shows small boxes on the actual UI
/// pointing at specific elements (like the + button and profile tab).
/// Only shows on first login. Uses SharedPreferences to track state.
class SimpleGuideTooltip {
  static const String _prefsKey = 'simple_guide_seen_v1';

  static Future<bool> alreadySeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? false;
  }

  static Future<void> markAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
  }

  /// Show a tooltip box at a specific position with Skip & OK buttons.
  /// Returns `true` if the user tapped OK, `false` if they tapped Skip.
  /// Waits for the user to dismiss before returning.
  static Future<bool> show({
    required BuildContext context,
    required String text,
    required Offset targetPosition,
    required Size targetSize,
    bool showArrowUp = true,
  }) async {
    if (!context.mounted) return false;

    final completer = Completer<bool>();
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _TooltipOverlay(
        text: text,
        targetPosition: targetPosition,
        targetSize: targetSize,
        showArrowUp: showArrowUp,
        onDismiss: (okPressed) {
          entry.remove();
          if (!completer.isCompleted) completer.complete(okPressed);
        },
      ),
    );

    overlay.insert(entry);
    return completer.future;
  }
}

class _TooltipOverlay extends StatefulWidget {
  final String text;
  final Offset targetPosition;
  final Size targetSize;
  final bool showArrowUp;
  final void Function(bool okPressed) onDismiss;

  const _TooltipOverlay({
    required this.text,
    required this.targetPosition,
    required this.targetSize,
    required this.showArrowUp,
    required this.onDismiss,
  });

  @override
  State<_TooltipOverlay> createState() => _TooltipOverlayState();
}

class _TooltipOverlayState extends State<_TooltipOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final tooltipWidth = screenWidth * 0.72;
    final tooltipMaxHeight = 170.0;

    // Position tooltip above or below the target
    final targetCenterX = widget.targetPosition.dx + widget.targetSize.width / 2;
    final double tooltipLeft = (targetCenterX - tooltipWidth / 2)
        .clamp(16.0, screenWidth - tooltipWidth - 16.0);

    final double tooltipTop;
    if (widget.showArrowUp) {
      // Show above the target
      tooltipTop = widget.targetPosition.dy - tooltipMaxHeight - 12;
    } else {
      // Show below the target
      tooltipTop = widget.targetPosition.dy + widget.targetSize.height + 12;
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Stack(
        children: [
          // Semi-transparent overlay background — tapping it = skip
          Positioned.fill(
            child: GestureDetector(
              onTap: () => widget.onDismiss(false),
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: Colors.black.withOpacity(0.3),
              ),
            ),
          ),
          // Highlight cutout around the target
          Positioned(
            left: widget.targetPosition.dx - 4,
            top: widget.targetPosition.dy - 4,
            width: widget.targetSize.width + 8,
            height: widget.targetSize.height + 8,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.8),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          // Arrow
          if (widget.showArrowUp)
            Positioned(
              left: targetCenterX - 10,
              top: tooltipTop + tooltipMaxHeight - 2,
              child: CustomPaint(
                size: const Size(20, 12),
                painter: _ArrowPainter(
                  color: AppColors.primary,
                  pointDown: true,
                ),
              ),
            )
          else
            Positioned(
              left: targetCenterX - 10,
              top: tooltipTop - 10,
              child: CustomPaint(
                size: const Size(20, 12),
                painter: _ArrowPainter(
                  color: AppColors.primary,
                  pointDown: false,
                ),
              ),
            ),
          // Tooltip box
          Positioned(
            left: tooltipLeft,
            top: tooltipTop.clamp(80.0, double.infinity),
            width: tooltipWidth,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Skip & OK buttons side by side
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Skip button
                        GestureDetector(
                          onTap: () => widget.onDismiss(false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 22, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: const Text(
                              'Skip',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // OK button
                        GestureDetector(
                          onTap: () => widget.onDismiss(true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                            child: const Text(
                              'OK',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  final Color color;
  final bool pointDown;

  _ArrowPainter({required this.color, this.pointDown = true});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    if (pointDown) {
      path.moveTo(0, 0);
      path.lineTo(size.width / 2, size.height);
      path.lineTo(size.width, 0);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
