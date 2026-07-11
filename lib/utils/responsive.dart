import 'package:flutter/material.dart';

/// Lightweight responsive helpers.
///
/// The whole app scales globally through the `textScaler` set in
/// `main.dart`, so most widgets do NOT need to change. This extension exists
/// for the few spots where we need width-aware sizing (e.g. capping a bottom
/// sheet's height, or scaling a fixed box on very small / very large phones).
///
/// Design baseline is a 390px-wide phone (iPhone 13 / most modern Androids).
/// Values scale proportionally but are clamped so they never get absurdly tiny
/// on small Androids or oversized on tablets.
extension ResponsiveContext on BuildContext {
  /// Full screen size.
  Size get screenSize => MediaQuery.sizeOf(this);

  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;

  /// Keyboard inset (0 when the keyboard is closed). Handy for bottom sheets.
  double get keyboardInset => MediaQuery.viewInsetsOf(this).bottom;

  /// True for narrow / small phones (e.g. older/compact Androids).
  bool get isSmallPhone => screenWidth < 360;

  /// True for large phones and tablets.
  bool get isLargeScreen => screenWidth >= 600;

  /// Scale factor derived from screen width against the 390px baseline,
  /// clamped so layouts stay sane on both tiny and huge devices.
  double get _widthScale => (screenWidth / 390).clamp(0.85, 1.15);

  /// Scale a size proportionally to screen width (for widths / boxes / icons).
  double w(double size) => size * _widthScale;

  /// Alias for [w] — reads nicely for heights that should track width scaling.
  double h(double size) => size * _widthScale;

  /// Scale a spacing/radius value. Same curve as [w]; separate name for intent.
  double sp(double size) => size * _widthScale;
}
