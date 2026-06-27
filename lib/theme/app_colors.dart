import 'package:flutter/material.dart';

class AppColors {
  // 3D Glassmorphic Palette Base
  static const Color background = Color(0xFF06090F); // Dark Space Base
  static const Color surface = Color(0xFF0F1524); // Layered Slate Base
  static const Color surfaceMuted =
      Color(0xFF1E2640); // Metallic Border Highlight

  // Glowing Neon Accents
  static const Color primary = Color(0xFF6366F1); // Cyber Indigo
  static const Color primaryDark = Color(0xFF4338CA); // Deep Shaded Shadow
  static const Color primaryLight = Color(0xFF818CF8); // Highlight Edge
  static const Color accent = Color(0xFF10B981); // Emerald Flux (Budget Glow)

  // App Mechanics Fix Link
  static const Color glow = Color(0xFF6366F1); // Cyber Indigo Glow Link

  // FIXED: Added missing active states and soft tags to clear all chat errors!
  static const Color online = Color(0xFF10B981); // Emerald Green for live badge
  static const Color budgetTagSoft = Color(0x1410B981); // 8% Alpha Emerald Tint

  // Status Accents (Solid Colors)
  static const Color urgentHigh = Color(0xFFEF4444); // Neon Crimson
  static const Color urgentMedium = Color(0xFFF59E0B); // Neon Amber
  static const Color urgentLow = Color(0xFF3B82F6); // Cyber Blue

  static const Color urgentHighSoft =
      Color(0x14EF4444); // 8% Alpha Neon Crimson
  static const Color urgentMediumSoft =
      Color(0x14F59E0B); // 8% Alpha Neon Amber
  static const Color urgentLowSoft = Color(0x143B82F6); // 8% Alpha Cyber Blue

  // UI Support Colors
  static const Color textPrimary = Color(0xFFF8FAFC); // Crystal White
  static const Color textSecondary = Color(0xFF94A3B8); // Cool Grey Shading
  static const Color textTertiary = Color(0xFF64748B); // Dim Muted Tint
  static const Color border = Color(0xFF1E293B); // Chiseled Outer Edge
  static const Color divider = Color(0xFF334155); // Sharp Grid Line
  static const Color shadow = Color(0x7F000000); // Ambient Occlusion Shading
}
