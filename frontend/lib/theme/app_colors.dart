import 'package:flutter/material.dart';

/// Central place for colors. Every color has a light and a dark value, and
/// the getters return whichever matches [AppColors.dark].
///
/// [dark] is switched in main.dart when the "Dark mode" setting changes.
/// Because these are getters, they can't be used inside a `const` widget.
///
/// Visual language: a dark "botanical intelligence lab" — deep forest-black
/// surfaces, glass panels, electric lime highlights and mint data accents.
class AppColors {
  AppColors._();

  static bool dark = true;

  static bool get isDark => dark;

  static Color _pick(Color light, Color darkValue) => dark ? darkValue : light;

  // Backgrounds
  static Color get bg => _pick(const Color(0xFFF1F6EF), const Color(0xFF060B08));
  static Color get bgTop =>
      _pick(const Color(0xFFFBFDF8), const Color(0xFF0A140E));
  static Color get bgBottom =>
      _pick(const Color(0xFFE5EFE4), const Color(0xFF030604));
  static Color get surface =>
      _pick(const Color(0xFFFFFFFF), const Color(0xFF0C1711));
  static Color get surfaceAlt =>
      _pick(const Color(0xFFF4F9F2), const Color(0xFF102018));
  static Color get border =>
      _pick(const Color(0xFFD9E6D9), const Color(0xFF1D3527));

  // Glass (translucent panels used on top of the animated backdrop)
  static Color get glass =>
      _pick(const Color(0xCCFFFFFF), const Color(0xB30C1711));
  static Color get glassStrong =>
      _pick(const Color(0xE6FFFFFF), const Color(0xE60A130E));
  static Color get glassBorder =>
      _pick(const Color(0xFFE3EDE3), const Color(0x1FFFFFFF));
  static Color get glassHighlight =>
      _pick(const Color(0xFFFFFFFF), const Color(0x14FFFFFF));

  // Text
  static Color get textPrimary =>
      _pick(const Color(0xFF0C2015), const Color(0xFFEDF8F0));
  static Color get textSecondary =>
      _pick(const Color(0xFF4F6A5A), const Color(0xFF9DB9A8));
  static Color get textMuted =>
      _pick(const Color(0xFF7C9386), const Color(0xFF6D8B7A));
  static Color get textAccent =>
      _pick(const Color(0xFF0E7A3E), const Color(0xFFB7F94B));

  // Brand
  static Color get brand =>
      _pick(const Color(0xFF0F8A45), const Color(0xFFB7F94B));
  static Color get brandDark =>
      _pick(const Color(0xFF0A5C2E), const Color(0xFF0E3D24));
  static Color get brandLight =>
      _pick(const Color(0xFF3BBE6D), const Color(0xFFE9FFB8));
  static Color get onBrand =>
      _pick(const Color(0xFFFFFFFF), const Color(0xFF06130B));

  // Signature accents
  static Color get lime =>
      _pick(const Color(0xFF69C223), const Color(0xFFC6FF4D));
  static Color get emerald =>
      _pick(const Color(0xFF0FA968), const Color(0xFF2EE59D));
  static Color get cyan =>
      _pick(const Color(0xFF0E8FA8), const Color(0xFF5AD1FF));

  // Status / accent backgrounds
  static Color get bgAccent =>
      _pick(const Color(0xFFE9F6EC), const Color(0xFF13291C));
  static Color get bgSuccess =>
      _pick(const Color(0xFFE6F4EA), const Color(0xFF0F2C1B));
  static Color get textSuccess =>
      _pick(const Color(0xFF1E7A34), const Color(0xFF6BFFA8));
  static Color get bgWarning =>
      _pick(const Color(0xFFFDF1DC), const Color(0xFF2E2410));
  static Color get textWarning =>
      _pick(const Color(0xFFB6740A), const Color(0xFFFFCB66));
  static Color get danger =>
      _pick(const Color(0xFFC0392B), const Color(0xFFFF6B6B));

  // Shadow
  static Color get shadow =>
      _pick(const Color(0x1A1B3A26), const Color(0xB3000000));

  // Stat card accents
  static Color get accentBlue =>
      _pick(const Color(0xFF2F86B8), const Color(0xFF5AD1FF));
  static Color get accentAmber =>
      _pick(const Color(0xFFD9971B), const Color(0xFFFFC857));
  static Color get accentPurple =>
      _pick(const Color(0xFF8B5CC6), const Color(0xFFC09BFF));

  // Ready-made gradients
  static LinearGradient get brandGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? const [Color(0xFFD8FF7A), Color(0xFF9BF03C), Color(0xFF2EE59D)]
            : const [Color(0xFF37B96B), Color(0xFF0F8A45), Color(0xFF0A5C2E)],
      );

  static LinearGradient get glassGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? const [Color(0xE6122019), Color(0xCC0A130E)]
            : const [Color(0xFFFFFFFF), Color(0xFFF3F9F1)],
      );
}

const double kRadius = 10;
