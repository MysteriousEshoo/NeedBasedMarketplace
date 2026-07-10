import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Custom-Engineered Interactive 3D Card.
///
/// Tilts in real 3D toward the pointer as you drag across it, presses inward
/// when tapped, and springs back on release. Purely presentational — the
/// public API ([child], [onTap], [glowColor]) is unchanged so existing call
/// sites keep working.
class ThreeDGlassCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color glowColor;

  const ThreeDGlassCard({
    super.key,
    required this.child,
    required this.onTap,
    this.glowColor = AppColors.primary,
  });

  @override
  State<ThreeDGlassCard> createState() => _ThreeDGlassCardState();
}

class _ThreeDGlassCardState extends State<ThreeDGlassCard>
    with SingleTickerProviderStateMixin {
  // Tilt about the X and Y axes, driven by pointer position.
  double _rotateX = -0.02;
  double _rotateY = 0.03;
  // Press depth (0 = resting, 1 = fully pressed inward).
  double _press = 0;

  static const double _maxTilt = 0.16; // radians

  void _updateTilt(Offset localPosition, Size size) {
    if (size.width == 0 || size.height == 0) return;
    // Normalise pointer to -0.5..0.5 across the card.
    final dx = (localPosition.dx / size.width) - 0.5;
    final dy = (localPosition.dy / size.height) - 0.5;
    setState(() {
      // Moving right tilts the right edge back; moving down tilts top back.
      _rotateY = dx * _maxTilt * 2;
      _rotateX = -dy * _maxTilt * 2;
    });
  }

  void _reset() {
    setState(() {
      _rotateX = -0.02;
      _rotateY = 0.03;
      _press = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onTapDown: (_) => setState(() => _press = 1),
          onTapUp: (_) {
            _reset();
            widget.onTap();
          },
          onTapCancel: _reset,
          onPanStart: (d) => _updateTilt(d.localPosition, size),
          onPanUpdate: (d) => _updateTilt(d.localPosition, size),
          onPanEnd: (_) => _reset(),
          onPanCancel: _reset,
          child: TweenAnimationBuilder<double>(
            // Smoothly interpolate press for a springy feel.
            tween: Tween(begin: 0, end: _press),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            builder: (context, pressValue, child) {
              final scale = 1 - pressValue * 0.03;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0014) // perspective depth
                  ..rotateX(_rotateX)
                  ..rotateY(_rotateY)
                  ..scaleByDouble(scale, scale, scale, 1),
                transformAlignment: Alignment.center,
                child: child,
              );
            },
            child: _CardSurface(
              glowColor: widget.glowColor,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

class _CardSurface extends StatelessWidget {
  final Widget child;
  final Color glowColor;

  const _CardSurface({required this.child, required this.glowColor});

  @override
  Widget build(BuildContext context) {
    // React to the active theme so the card flips between dark and light
    // instantly when the user toggles the theme.
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color surfaceColor = isDark ? AppColors.surface : Colors.white;
    final Color borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFE2E8F0);
    final Color ambientShadow = isDark
        ? Colors.black.withValues(alpha: 0.6)
        : Colors.black.withValues(alpha: 0.10);
    final Color highlightTint = isDark
        ? Colors.white.withValues(alpha: 0.03)
        : Colors.white.withValues(alpha: 0.5);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        // Layered double borders mimicking deep metallic chiseled bevels.
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          // Base shading (ambient occlusion).
          BoxShadow(
            color: ambientShadow,
            blurRadius: 18,
            offset: const Offset(-8, 14),
          ),
          // Volumetric glow shading.
          BoxShadow(
            color: glowColor.withValues(alpha: isDark ? 0.12 : 0.10),
            blurRadius: 28,
            offset: const Offset(6, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          // Internal gradient providing specular highlights.
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                highlightTint,
                Colors.transparent,
                glowColor.withValues(alpha: 0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
  }
}
