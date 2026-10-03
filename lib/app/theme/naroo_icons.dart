import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Lucide line icons used by Naroo.
///
/// Sizes follow the style guide: 24 for navigation and actions,
/// 22 for category chips, 20 inside list badges, 16 for inline marks.
abstract final class NarooIcons {
  static const double nav = 24;
  static const double action = 24;
  static const double category = 22;
  static const double list = 20;
  static const double inline = 16;

  static const IconData home = LucideIcons.home;
  static const IconData transactions = LucideIcons.receipt;
  static const IconData statistics = LucideIcons.pieChart;
  static const IconData settings = LucideIcons.settings;
  static const IconData add = LucideIcons.plus;
  static const IconData close = LucideIcons.x;
  static const IconData back = LucideIcons.chevronLeft;
  static const IconData forward = LucideIcons.chevronRight;
  static const IconData delete = LucideIcons.trash2;
  static const IconData calendar = LucideIcons.calendar;
  static const IconData edit = LucideIcons.pencil;
  static const IconData show = LucideIcons.eye;
  static const IconData hide = LucideIcons.eyeOff;
  static const IconData refresh = LucideIcons.refreshCw;

  static IconData categoryIcon(String name) {
    return switch (name) {
      '식비' => LucideIcons.utensils,
      '카페' || '카페/간식' => LucideIcons.coffee,
      '교통' => LucideIcons.train,
      '쇼핑' => LucideIcons.shoppingBag,
      '생활' => LucideIcons.home,
      '주거' => LucideIcons.building2,
      '통신' => LucideIcons.smartphone,
      '의료' => LucideIcons.plusSquare,
      '보험' => LucideIcons.shield,
      '문화' || '여가' => LucideIcons.clapperboard,
      '월급' => LucideIcons.wallet,
      '보너스' => LucideIcons.gift,
      '용돈' => LucideIcons.coins,
      '이자' => LucideIcons.percent,
      _ => LucideIcons.moreHorizontal,
    };
  }
}
