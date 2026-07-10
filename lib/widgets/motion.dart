import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Fades, slides up, and gently rotates a child into view.
///
/// Give list items an increasing [delay] (e.g. `index * 60ms`) for a
/// staggered "cards flying in" effect. Purely presentational.
class EntranceMotion extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  const EntranceMotion({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 520),
  });

  @override
  State<EntranceMotion> createState() => _EntranceMotionState();
}

class _EntranceMotionState extends State<EntranceMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        final t = curved.value;
        return Opacity(
          opacity: t,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..translateByDouble(0.0, (1 - t) * 40, 0.0, 1.0)
              ..rotateX((1 - t) * -0.35),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// A slow, always-on backdrop of drifting glow orbs that gives screens a
/// sense of living depth. Drop it as the bottom layer of a [Stack].
class FloatingOrbsBackground extends StatefulWidget {
  final List<Color>? colors;

  const FloatingOrbsBackground({super.key, this.colors});

  @override
  State<FloatingOrbsBackground> createState() => _FloatingOrbsBackgroundState();
}

class _FloatingOrbsBackgroundState extends State<FloatingOrbsBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors ??
        [
          AppColors.primary,
          AppColors.accent,
          AppColors.primaryLight,
        ];
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _OrbPainter(_controller.value, colors),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double t;
  final List<Color> colors;

  _OrbPainter(this.t, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < colors.length; i++) {
      final phase = t * 2 * math.pi + i * (2 * math.pi / colors.length);
      final cx = size.width * (0.5 + 0.35 * math.cos(phase + i));
      final cy = size.height * (0.35 + 0.4 * math.sin(phase * 0.8 + i));
      final radius = size.width * (0.32 + 0.05 * math.sin(phase));
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            colors[i].withValues(alpha: 0.16),
            colors[i].withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        );
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_OrbPainter oldDelegate) => oldDelegate.t != t;
}
