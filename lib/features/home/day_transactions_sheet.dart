import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_routes.dart';
import '../../app/theme/naroo_colors.dart';
import '../../app/theme/naroo_spacing.dart';
import '../../app/theme/naroo_text.dart';
import '../../app/theme/naroo_widgets.dart';
import '../../core/money_format.dart';
import '../../data/models/category.dart';
import '../transaction/widgets/transaction_detail_sheet.dart';
import 'home_controller.dart';
import 'home_summary.dart';

/// Records of one calendar day. It follows [homeSummaryProvider] so edits and
/// deletes made from the detail sheet show up here immediately.
class DayTransactionsSheet extends ConsumerWidget {
  const DayTransactionsSheet({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(homeSummaryProvider).value;
    final items = summary?.itemsOn(day) ?? const [];
    final total = summary?.dailyTotals[day] ?? const DayTotal();

    return NarooBottomSheet(
      title: '${day.month}월 ${day.day}일',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: NarooSpacing.space16,
              ),
              child: Text('이 날 기록이 없어요.', style: NarooText.bodySecondary),
            )
          else ...[
            Row(
              children: [
                if (total.income > 0)
                  Text(
                    '수입 +${MoneyFormat.krw(total.income)}원',
                    style: NarooText.money(
                      NarooText.bodySecondary,
                      NarooColors.income,
                    ),
                  ),
                if (total.income > 0 && total.expense > 0)
                  const SizedBox(width: NarooSpacing.space16),
                if (total.expense > 0)
                  Text(
                    '지출 -${MoneyFormat.krw(total.expense)}원',
                    style: NarooText.money(
                      NarooText.bodySecondary,
                      NarooColors.expense,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: NarooSpacing.space8),
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
                  [?item.memoText, item.attributionLabel].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  '${MoneyFormat.signed(item.transaction.type, item.transaction.amount)}원',
                  style: NarooText.money(
                    NarooText.body,
                    item.transaction.type == CategoryType.income
                        ? NarooColors.income
                        : NarooColors.expense,
                  ),
                ),
                onTap: () => showTransactionDetailSheet(context, item),
              ),
          ],
          const SizedBox(height: NarooSpacing.space16),
          OutlinedButton(
            onPressed: () {
              final router = GoRouter.of(context);
              Navigator.of(context).pop();
              router.push(AppRoutes.transactionNewOn(day));
            },
            child: const Text('이 날짜에 기록 추가'),
          ),
        ],
      ),
    );
  }
}
