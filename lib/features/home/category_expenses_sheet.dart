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
import 'home_controller.dart';

/// Expenses of one top-level category in the selected month, including its
/// subcategories. Follows [homeSummaryProvider] so detail edits show up here.
class CategoryExpensesSheet extends ConsumerWidget {
  const CategoryExpensesSheet({super.key, required this.category});

  final Category category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(homeSummaryProvider).value;
    final items = summary?.expensesIn(category.id) ?? const [];

    return NarooBottomSheet(
      title: category.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: NarooSpacing.space16,
              ),
              child: Text('이 달 지출이 없어요.', style: NarooText.bodySecondary),
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
                '${MoneyFormat.signed(CategoryType.expense, item.transaction.amount)}원',
                style: NarooText.money(NarooText.body, NarooColors.expense),
              ),
              onTap: () => showTransactionDetailSheet(context, item),
            ),
        ],
      ),
    );
  }
}
