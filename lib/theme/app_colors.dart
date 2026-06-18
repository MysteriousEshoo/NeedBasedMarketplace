import 'package:flutter/material.dart';

/// Centralized color tokens for the entire app.
///
/// Keeping every color in one place guarantees a consistent, premium
/// visual language and makes future theming (e.g. dark mode) trivial.
class AppColors {
  AppColors._();

  // ---- Brand ----
  /// Deep emerald / teal — conveys trust and a premium feel.
  static const Color primary = Color(0xFF0E7C66);
  static const Color primaryDark = Color(0xFF0A5F4E);
  static const Color primaryLight = Color(0xFF34A78D);

  /// Indigo / vibrant blue — used for interactive accents.
  static const Color accent = Color(0xFF4F46E5);
  static const Color accentLight = Color(0xFF6366F1);

  // ---- Surfaces ----
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F3F5);

  // ---- Text ----
  static const Color textPrimary = Color(0xFF11181C);
  static const Color textSecondary = Color(0xFF687076);
  static const Color textTertiary = Color(0xFF9BA1A6);

  // ---- Semantic / status ----
  static const Color urgentHigh = Color(0xFFEF5350);
  static const Color urgentHighSoft = Color(0xFFFDECEA);
  static const Color urgentMedium = Color(0xFFF59E0B);
  static const Color urgentMediumSoft = Color(0xFFFEF3E2);
  static const Color urgentLow = Color(0xFF10B981);
  static const Color urgentLowSoft = Color(0xFFE6F7F1);

  static const Color budgetTag = Color(0xFF0E7C66);
  static const Color budgetTagSoft = Color(0xFFE6F4F0);

  static const Color online = Color(0xFF22C55E);

  // ---- Lines & borders ----
  static const Color border = Color(0xFFE6E8EB);
  static const Color divider = Color(0xFFEDEFF1);

  // ---- Shadows ----
  static const Color shadow = Color(0x14000000);
  static const Color glow = Color(0x4D0E7C66);
}
