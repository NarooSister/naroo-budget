import 'package:flutter/material.dart';

/// Naroo color tokens.
///
/// Warm paper neutrals and a low-saturation sage green.
abstract final class NarooColors {
  static const Color background = Color(0xFFFEF8F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF6F0EC);
  static const Color surfaceSubtle = Color(0xFFEFE8E3);

  static const Color primary = Color(0xFF415744);
  static const Color primaryLight = Color(0xFFEBF0EC);
  static const Color onPrimary = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF1F2420);
  static const Color textSecondary = Color(0xFF6B726A);
  static const Color textTertiary = Color(0xFFA2A8A1);

  static const Color border = Color(0xFFEBE3DE);
  static const Color borderFocus = Color(0xFF415744);

  static const Color income = Color(0xFF2E6F40);
  static const Color expense = Color(0xFFB85642);
  static const Color error = Color(0xFFC24132);
  static const Color errorSurface = Color(0xFFFDF0EE);

  /// Modal dim. Black at 35% opacity.
  static const Color barrier = Color(0x59000000);

  /// Upward ambient shadow for the bottom bar and sheets. Black at 4% opacity.
  static const Color overlayShadow = Color(0x0A000000);
}
