import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_routes.dart';
import '../../app/theme/naroo_colors.dart';
import '../../app/theme/naroo_icons.dart';
import '../../app/theme/naroo_spacing.dart';
import '../../app/theme/naroo_text.dart';
import '../../app/theme/naroo_widgets.dart';
import '../../core/money_format.dart';
import '../../core/seoul_date.dart';
import '../../data/models/category.dart';
import 'transaction_list_controller.dart';

class TransactionListScreen extends ConsumerWidget {
  const TransactionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(transactionListMonthProvider);
    final filter = ref.watch(transactionListFilterProvider);
    final transactionsAsync = ref.watch(monthlyTransactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('내역')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                NarooSpacing.space8,
                NarooSpacing.space8,
                NarooSpacing.space8,
                0,
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '이전 달',
                    onPressed: () => ref
                        .read(transactionListMonthProvider.notifier)
                        .goToPreviousMonth(),
                    icon: const Icon(NarooIcons.back, size: NarooIcons.action),
                  ),
                  Expanded(
                    child: Text(
                      SeoulDate.monthLabel(month),
                      textAlign: TextAlign.center,
                      style: NarooText.section,
                    ),
                  ),
                  IconButton(
                    tooltip: '다음 달',
                    onPressed: () => ref
                        .read(transactionListMonthProvider.notifier)
                        .goToNextMonth(),
                    icon: const Icon(
                      NarooIcons.forward,
                      size: NarooIcons.action,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: NarooSpacing.space20,
                vertical: NarooSpacing.space8,
              ),
              child: SegmentedButton<TransactionListFilter>(
                segments: [
                  for (final value in TransactionListFilter.values)
                    ButtonSegment(value: value, label: Text(value.label)),
                ],
                selected: {filter},
                onSelectionChanged: (value) {
                  ref
                      .read(transactionListFilterProvider.notifier)
                      .setFilter(value.first);
                },
              ),
            ),
            Expanded(
              child: transactionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const Center(child: Text('내역을 불러오지 못했습니다.')),
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: NarooEmptyState(
                        message: '아직 기록이 없어요.',
                        actionLabel: '+ 첫 기록 남기기',
                        onAction: () => context.push(AppRoutes.transactionNew),
                      ),
                    );
                  }

                  final groups = groupTransactionsByDate(items);
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      NarooSpacing.space20,
                      NarooSpacing.space8,
                      NarooSpacing.space20,
                      NarooSpacing.space24,
                    ),
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(
                              top: index == 0 ? 0 : NarooSpacing.space16,
                              bottom: NarooSpacing.space8,
                            ),
                            child: Text(
                              group.label,
                              style: NarooText.caption.copyWith(
                                color: NarooColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          for (final item in group.items)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: NarooCategoryBadge(
                                name: item.categoryName,
                              ),
                              title: Text(item.categoryLabel),
                              subtitle: Text(
                                [
                                  ?item.memoText,
                                  item.attributionLabel,
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Text(
                                MoneyFormat.signed(
                                  item.transaction.type,
                                  item.transaction.amount,
                                ),
                                style: NarooText.money(
                                  NarooText.body,
                                  item.transaction.type == CategoryType.income
                                      ? NarooColors.income
                                      : NarooColors.expense,
                                ),
                              ),
                              onTap: () => context.push(
                                AppRoutes.transactionEdit(item.transaction.id),
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
