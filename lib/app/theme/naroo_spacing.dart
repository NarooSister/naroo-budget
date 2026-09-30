import 'package:flutter/material.dart';

import 'naroo_colors.dart';

abstract final class NarooSpacing {
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space48 = 48;

  static const EdgeInsets pagePadding = EdgeInsets.symmetric(
    horizontal: space20,
  );
}

abstract final class NarooRadius {
  static const double button = 16;
  static const double input = 14;
  static const double chip = 16;
  static const double card = 20;
  static const double sheet = 24;
  static const double dialog = 20;
  static const double keypad = 14;
}

abstract final class NarooShadows {
  static const List<BoxShadow> overlay = [
    BoxShadow(
      color: NarooColors.overlayShadow,
      blurRadius: 16,
      offset: Offset(0, -4),
    ),
  ];
}
