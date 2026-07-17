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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          'assets/images/logo.jpeg',
          height: size,
          width: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => ColoredBox(
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
    return Semantics(
      image: true,
      label: 'Need Base Marketplace',
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRect(
          child: Image.asset(
            'assets/images/appBar.jpeg',
            width: width,
            height: height,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                BrandLogo(
                  size: height,
                  borderRadius: height * 0.22,
                ),
                const SizedBox(width: 10),
                const Flexible(
                  child: Text(
                    'Need Base',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
