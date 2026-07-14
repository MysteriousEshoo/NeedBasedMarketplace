import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Theme-aware color palette.
///
/// [AppColors] holds the raw *dark* design constants. Many screens used those
/// constants directly, which meant that in light mode surfaces/text stayed dark
/// ("kahin light kahin dark"). This palette resolves each semantic color to the
/// correct value for the current [Brightness], so a single access point does the
/// right thing in both themes.
///
/// Usage:
/// ```dart
/// final c = context.palette;
/// color: c.surface, // white in light, slate in dark
/// ```
///
/// Brand accents (primary / accent / urgency) intentionally stay identical in
/// both themes — they are designed to read on either background.
class AppPalette {
  final Brightness brightness;
  const AppPalette(this.brightness);

  bool get isDark => brightness == Brightness.dark;

  // ---- Surfaces & backgrounds ------------------------------------------------
  Color get background =>
      isDark ? AppColors.background : const Color(0xFFF1F5F9);
  Color get surface => isDark ? AppColors.surface : Colors.white;

  /// Slightly raised surface (chips, input fills, secondary cards).
  Color get surfaceMuted =>
      isDark ? AppColors.surfaceMuted : const Color(0xFFF1F5F9);

  /// Fill for text fields / pill inputs.
  Color get inputFill =>
      isDark ? AppColors.surfaceMuted : const Color(0xFFF1F5F9);

  // ---- Text ------------------------------------------------------------------
  Color get textPrimary =>
      isDark ? AppColors.textPrimary : const Color(0xFF0F172A);
  Color get textSecondary =>
      isDark ? AppColors.textSecondary : const Color(0xFF475569);
  Color get textTertiary =>
      isDark ? AppColors.textTertiary : const Color(0xFF94A3B8);

  // ---- Lines & shadows -------------------------------------------------------
  Color get border => isDark ? AppColors.border : const Color(0xFFE2E8F0);
  Color get divider => isDark ? AppColors.divider : const Color(0xFFE2E8F0);
  Color get shadow => isDark ? AppColors.shadow : Colors.black12;

  // ---- Brand accents (identical in both themes) ------------------------------
  Color get primary => AppColors.primary;
  Color get primaryLight => AppColors.primaryLight;
  Color get primaryDark => AppColors.primaryDark;
  Color get accent => AppColors.accent;
}

extension AppPaletteContext on BuildContext {
  /// Theme-aware palette resolved from the current [Brightness].
  ///
  /// Uses [Theme.of] so it tracks whatever theme `MaterialApp` is showing —
  /// no need to read `ThemeProvider` separately.
  AppPalette get palette => AppPalette(Theme.of(this).brightness);
}
