import 'package:flutter/painting.dart';

import '../../app/theme/naroo_colors.dart';
import '../../data/models/category.dart';
import '../../data/models/transaction.dart';

enum StatisticsGroup {
  category('카테고리별'),
  member('구성원별'),
  paymentMethod('결제 수단별');

  const StatisticsGroup(this.title);

  final String title;

  /// Payment methods exist only on expenses.
  static List<StatisticsGroup> forType(CategoryType type) =>
      type == CategoryType.expense
      ? values
      : const [StatisticsGroup.category, StatisticsGroup.member];
}

class StatisticsSlice {
  const StatisticsSlice({
    required this.key,
    required this.label,
    required this.amount,
    required this.color,
    required this.items,
  });

  final String key;
  final String label;
  final int amount;
  final Color color;
  final List<TransactionListItem> items;

  /// Whole percent of [total]; a non-zero share never shows as 0.
  String percentOf(int total) {
    if (total <= 0) return '0%';
    final percent = (amount * 100 / total).round();
    return percent == 0 ? '<1%' : '$percent%';
  }
}

class StatisticsSummary {
  StatisticsSummary({required this.month, required this.items});

  final DateTime month;
  final List<TransactionListItem> items;

  int total(CategoryType type) => items
      .where((i) => i.transaction.type == type)
      .fold(0, (total, i) => total + i.transaction.amount);

  /// Groups by ID so renamed or same-named entries are never merged.
  /// Ordered by amount, then label and key for a stable color assignment.
  List<StatisticsSlice> slices(StatisticsGroup group, CategoryType type) {
    final groups =
        <String, ({String label, List<TransactionListItem> items})>{};
    for (final item in items) {
      if (item.transaction.type != type) continue;
      final (key, label) = _keyOf(group, item);
      (groups[key] ??= (label: label, items: [])).items.add(item);
    }
    final entries =
        [
          for (final MapEntry(:key, :value) in groups.entries)
            (
              key: key,
              label: value.label,
              items: value.items,
              amount: value.items.fold(0, (t, i) => t + i.transaction.amount),
            ),
        ]..sort((a, b) {
          final byAmount = b.amount.compareTo(a.amount);
          if (byAmount != 0) return byAmount;
          final byLabel = a.label.compareTo(b.label);
          return byLabel != 0 ? byLabel : a.key.compareTo(b.key);
        });
    return [
      for (final (index, entry) in entries.indexed)
        StatisticsSlice(
          key: entry.key,
          label: entry.label,
          amount: entry.amount,
          color: NarooColors.chart[index % NarooColors.chart.length],
          items: entry.items,
        ),
    ];
  }

  static (String, String) _keyOf(
    StatisticsGroup group,
    TransactionListItem item,
  ) {
    final transaction = item.transaction;
    return switch (group) {
      StatisticsGroup.category => (transaction.categoryId, item.categoryName),
      StatisticsGroup.member =>
        transaction.attributionKind == AttributionKind.shared
            ? ('shared', '공용')
            : ('member:${transaction.memberId}', item.attributionLabel),
      StatisticsGroup.paymentMethod => (
        transaction.paymentMethod?.dbValue ?? 'none',
        transaction.paymentMethod?.label ?? '미지정',
      ),
    };
  }
}
