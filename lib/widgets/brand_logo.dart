import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 40,
    this.borderRadius = 10,
  });

  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Need Base Marketplace logo',
      child: SizedBox.square(
        dimension: size,
        // Transparent PNG — only the badge artwork shows, no background box.
        child: Image.asset(
          'assets/images/logo.png',
          height: size,
          width: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: ColoredBox(
              color: AppColors.primary,
              child: SizedBox.square(
                dimension: size,
                child: Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                  size: size * 0.45,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppBarBrand extends StatelessWidget {
  const AppBarBrand({
    super.key,
    this.width = 188,
    this.height = 40,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    // Picks the right transparent banner for the active theme in realtime:
    // light -> navy wordmark, dark -> white wordmark. Rebuilds automatically
    // whenever the app theme changes because it reads Theme.of(context).
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String asset = isDark
        ? 'assets/images/appbar_dark.png'
        : 'assets/images/appbar_light.png';

    return Semantics(
      image: true,
      label: 'Need Base Marketplace',
      child: SizedBox(
        width: width,
        height: height,
        child: Image.asset(
          asset,
          width: width,
          height: height,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          errorBuilder: (_, __, ___) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandLogo(
                size: height,
                borderRadius: height * 0.22,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Need Base',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
