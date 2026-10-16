import 'package:flutter/material.dart';

/// Central place for colors. Every color has a light and a dark value, and
/// the getters return whichever matches [AppColors.dark].
///
/// [dark] is switched in main.dart when the "Dark mode" setting changes.
/// Because these are getters, they can't be used inside a `const` widget.
class AppColors {
  AppColors._();

  static bool dark = false;

  static Color _pick(Color light, Color darkValue) => dark ? darkValue : light;

  // Backgrounds
  static Color get bg => _pick(const Color(0xFFF6F7F5), const Color(0xFF121512));
  static Color get bgTop =>
      _pick(const Color(0xFFF9FBF8), const Color(0xFF161A17));
  static Color get bgBottom =>
      _pick(const Color(0xFFEEF4EF), const Color(0xFF0E110F));
  static Color get surface =>
      _pick(const Color(0xFFFFFFFF), const Color(0xFF1C201D));
  static Color get border =>
      _pick(const Color(0xFFE4E6E2), const Color(0xFF2C332E));

  // Text
  static Color get textPrimary =>
      _pick(const Color(0xFF1C1E1B), const Color(0xFFECEFEA));
  static Color get textSecondary =>
      _pick(const Color(0xFF6B7066), const Color(0xFFA3AB9F));
  static Color get textMuted =>
      _pick(const Color(0xFF9AA094), const Color(0xFF7A8277));
  static Color get textAccent =>
      _pick(const Color(0xFF2F7A4F), const Color(0xFF6FCB94));

  // Brand
  static Color get brand =>
      _pick(const Color(0xFF2F7A4F), const Color(0xFF3D9066));
  static Color get brandDark =>
      _pick(const Color(0xFF1F5C3A), const Color(0xFF1F5C3A));
  static Color get brandLight =>
      _pick(const Color(0xFF4FA574), const Color(0xFF5CB98A));
  static Color get onBrand => const Color(0xFFFFFFFF);

  // Status / accent backgrounds
  static Color get bgAccent =>
      _pick(const Color(0xFFEAF3EC), const Color(0xFF1F2E25));
  static Color get bgSuccess =>
      _pick(const Color(0xFFE6F4EA), const Color(0xFF1B3324));
  static Color get textSuccess =>
      _pick(const Color(0xFF1E7A34), const Color(0xFF7BD79A));
  static Color get bgWarning =>
      _pick(const Color(0xFFFDF1DC), const Color(0xFF3A2D14));
  static Color get textWarning =>
      _pick(const Color(0xFFB6740A), const Color(0xFFE7B35A));
  static Color get danger =>
      _pick(const Color(0xFFC0392B), const Color(0xFFFF7B72));

  // Shadow
  static Color get shadow =>
      _pick(const Color(0x142F7A4F), const Color(0x66000000));

  // Stat card accents
  static Color get accentBlue =>
      _pick(const Color(0xFF3B82C4), const Color(0xFF5AA0DC));
  static Color get accentAmber =>
      _pick(const Color(0xFFE0A030), const Color(0xFFE8B04A));
  static Color get accentPurple =>
      _pick(const Color(0xFF8B5CC6), const Color(0xFFA683DD));
}

const double kRadius = 10;