import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/naroo_colors.dart';
import '../../app/theme/naroo_spacing.dart';
import '../../app/theme/naroo_text.dart';
import '../../app/theme/naroo_widgets.dart';
import '../../core/money_format.dart';
import '../../core/seoul_date.dart';
import '../../data/models/category.dart';
import '../transaction/widgets/transaction_detail_sheet.dart';
import 'statistics_controller.dart';
import 'statistics_summary.dart';

/// Records of one chart item in the selected month. Follows
/// [statisticsProvider] so detail edits and deletes show up here.
class StatisticsItemsSheet extends ConsumerWidget {
  const StatisticsItemsSheet({
    super.key,
    required this.group,
    required this.type,
    required this.sliceKey,
    required this.title,
  });

  final StatisticsGroup group;
  final CategoryType type;
  final String sliceKey;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(statisticsProvider).value;
    final items = [
      for (final slice
          in summary?.slices(group, type) ?? const <StatisticsSlice>[])
        if (slice.key == sliceKey) ...slice.items,
    ];
    final color = type == CategoryType.income
        ? NarooColors.income
        : NarooColors.expense;

    return NarooBottomSheet(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: NarooSpacing.space16,
              ),
              child: Text(
                '이 달 ${type.label}이 없어요.',
                style: NarooText.bodySecondary,
              ),
            ),
          for (final item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: NarooCategoryBadge(name: item.categoryName),
              title: Text(
                item.categoryLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  SeoulDate.daySectionLabel(item.transaction.occurredOn),
                  ?item.memoText,
                  item.attributionLabel,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                '${MoneyFormat.signed(type, item.transaction.amount)}원',
                style: NarooText.money(NarooText.body, color),
              ),
              onTap: () => showTransactionDetailSheet(context, item),
            ),
        ],
      ),
    );
  }
}
