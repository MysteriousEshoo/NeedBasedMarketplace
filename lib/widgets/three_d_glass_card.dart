import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Custom-Engineered 3D Card with Beveled Perspective Edges and Neon Shading.
class ThreeDGlassCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Transform(
      // Isometric subtle perspective rotation along X and Y axes for 3D depth perception
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0012) // Shading perspective coefficient
        ..rotateX(-0.02)
        ..rotateY(0.03),
      alignment: Alignment.center,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          // Layered Double Borders mimicking deep metallic chiseled bevels
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1.5,
          ),
          boxShadow: [
            // Dark Base Shading (Ambient Occlusion)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 16,
              offset: const Offset(-8, 12),
            ),
            // Volumetric Glow Shading
            BoxShadow(
              color: glowColor.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(4, -4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            // Internal Gradient providing specular highlights
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.02),
                  Colors.transparent,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                splashColor: glowColor.withValues(alpha: 0.15),
                highlightColor: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
