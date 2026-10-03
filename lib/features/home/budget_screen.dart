import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/naroo_colors.dart';
import '../../app/theme/naroo_icons.dart';
import '../../app/theme/naroo_spacing.dart';
import '../../app/theme/naroo_text.dart';
import '../../app/theme/naroo_widgets.dart';
import '../../core/money_format.dart';
import '../../core/selected_month.dart';
import '../../core/seoul_date.dart';
import '../../data/models/category.dart';
import 'budget_progress.dart';
import 'budget_sheet.dart';
import 'category_expenses_sheet.dart';
import 'home_controller.dart';
import 'home_summary.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final summaryAsync = ref.watch(homeSummaryProvider);
    final summary = summaryAsync.value;
    final ready = summary != null && summary.month == month;

    return Scaffold(
      appBar: AppBar(
        title: const Text('예산'),
        actions: [
          if (ready && summary.budget != null)
            IconButton(
              tooltip: '예산 수정',
              onPressed: () => showBudgetSheet(
                context,
                month: month,
                budget: summary.budget,
              ),
              icon: const Icon(NarooIcons.edit, size: NarooIcons.action),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            NarooSpacing.space20,
            NarooSpacing.space8,
            NarooSpacing.space20,
            NarooSpacing.space24,
          ),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: '이전 달',
                  onPressed: () => ref
                      .read(selectedMonthProvider.notifier)
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
                  onPressed: () =>
                      ref.read(selectedMonthProvider.notifier).goToNextMonth(),
                  icon: const Icon(NarooIcons.forward, size: NarooIcons.action),
                ),
              ],
            ),
            const SizedBox(height: NarooSpacing.space16),
            if (summaryAsync.hasError && !ready)
              Text('예산을 불러오지 못했습니다.', style: NarooText.bodySecondary)
            else if (!ready)
              const Padding(
                padding: EdgeInsets.all(NarooSpacing.space48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (summary.budget == null)
              NarooEmptyState(
                message: '이 달 예산이 없어요.',
                actionLabel: '예산 설정',
                onAction: () => showBudgetSheet(context, month: month),
              )
            else
              _content(context, ref, summary),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, HomeSummary summary) {
    final budget = summary.budget!;
    final categories = ref.watch(budgetCategoriesProvider).value ?? const [];
    final allocated = [
      for (final category in categories)
        if (budget.allocations[category.id] case final amount?)
          (category, amount),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '총예산 ${MoneyFormat.krw(budget.amount)}원',
          style: NarooText.section,
        ),
        const SizedBox(height: NarooSpacing.space12),
        BudgetProgress(spent: summary.expense, budget: budget.amount),
        const SizedBox(height: NarooSpacing.space32),
        Row(
          children: [
            Expanded(child: Text('카테고리별 예산', style: NarooText.section)),
            Text(
              '미배분 ${MoneyFormat.krw(budget.unallocated)}원',
              style: NarooText.money(
                NarooText.bodySecondary,
                NarooColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: NarooSpacing.space8),
        if (allocated.isEmpty)
          Text(
            '카테고리별 예산이 없어요. 수정에서 배분할 수 있어요.',
            style: NarooText.bodySecondary,
          ),
        for (final (category, amount) in allocated)
          _categoryRow(context, summary, category, amount),
      ],
    );
  }

  Widget _categoryRow(
    BuildContext context,
    HomeSummary summary,
    Category category,
    int amount,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(NarooRadius.input),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: NarooColors.surface,
        barrierColor: NarooColors.barrier,
        builder: (_) => CategoryExpensesSheet(category: category),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: NarooSpacing.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                NarooCategoryBadge(name: category.name),
                const SizedBox(width: NarooSpacing.space12),
                Expanded(child: Text(category.name, style: NarooText.body)),
                const Icon(NarooIcons.forward, size: NarooIcons.inline),
              ],
            ),
            const SizedBox(height: NarooSpacing.space8),
            BudgetProgress(spent: summary.spentIn(category.id), budget: amount),
          ],
        ),
      ),
    );
  }
}
