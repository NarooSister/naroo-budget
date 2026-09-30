import 'package:flutter/material.dart';

import 'naroo_colors.dart';

/// Pretendard type scale. Digits use tabular figures.
abstract final class NarooText {
  static const String fontFamily = 'Pretendard';

  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  static const TextStyle hero = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    height: 38 / 32,
    fontWeight: FontWeight.w700,
    color: NarooColors.textPrimary,
    fontFeatures: tabularFigures,
  );

  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w700,
    color: NarooColors.textPrimary,
    fontFeatures: tabularFigures,
  );

  static const TextStyle section = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    height: 24 / 17,
    fontWeight: FontWeight.w600,
    color: NarooColors.textPrimary,
    fontFeatures: tabularFigures,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w500,
    color: NarooColors.textPrimary,
    fontFeatures: tabularFigures,
  );

  static const TextStyle bodySecondary = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    color: NarooColors.textSecondary,
    fontFeatures: tabularFigures,
  );

  static const TextStyle errorCaption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    color: NarooColors.error,
    fontFeatures: tabularFigures,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    color: NarooColors.textSecondary,
    fontFeatures: tabularFigures,
  );

  static const TextStyle keypad = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    height: 30 / 24,
    fontWeight: FontWeight.w600,
    color: NarooColors.textPrimary,
    fontFeatures: tabularFigures,
  );

  static const TextStyle appBarTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w700,
    color: NarooColors.textPrimary,
    fontFeatures: tabularFigures,
  );

  static const TextStyle navSelected = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
    color: NarooColors.primary,
    fontFeatures: tabularFigures,
  );

  static const TextStyle navIdle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    color: NarooColors.textTertiary,
    fontFeatures: tabularFigures,
  );

  static TextStyle money(TextStyle style, Color color) {
    return style.copyWith(color: color, fontFeatures: tabularFigures);
  }
}
