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
import 'donut_chart.dart';
import 'statistics_controller.dart';
import 'statistics_items_sheet.dart';
import 'statistics_summary.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  CategoryType _type = CategoryType.expense;

  /// Slice highlighted while its record sheet is open.
  (StatisticsGroup, String)? _open;

  Future<void> _refresh() async {
    ref.invalidate(currentMonthProvider);
    ref.invalidate(statisticsProvider);
    try {
      await ref.read(statisticsProvider.future);
    } catch (_) {
      /* Render error below. */
    }
  }

  Future<void> _openSlice(StatisticsGroup group, StatisticsSlice slice) async {
    setState(() => _open = (group, slice.key));
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: NarooColors.surface,
      barrierColor: NarooColors.barrier,
      builder: (_) => StatisticsItemsSheet(
        group: group,
        type: _type,
        sliceKey: slice.key,
        title: slice.label,
      ),
    );
    if (mounted) setState(() => _open = null);
  }

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(selectedMonthProvider);
    final summaryAsync = ref.watch(statisticsProvider);
    final summary = summaryAsync.value;
    final ready = summary != null && summary.month == month;

    return Scaffold(
      appBar: AppBar(title: const Text('통계')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              NarooSpacing.space20,
              NarooSpacing.space8,
              NarooSpacing.space20,
              NarooSpacing.space32,
            ),
            children: [
              _monthSwitcher(month),
              const SizedBox(height: NarooSpacing.space8),
              SegmentedButton<CategoryType>(
                segments: const [
                  ButtonSegment(value: CategoryType.expense, label: Text('지출')),
                  ButtonSegment(value: CategoryType.income, label: Text('수입')),
                ],
                selected: {_type},
                showSelectedIcon: false,
                onSelectionChanged: (value) =>
                    setState(() => _type = value.first),
              ),
              const SizedBox(height: NarooSpacing.space24),
              if (summaryAsync.hasError && !ready)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('이 달 통계를 불러오지 못했습니다.', style: NarooText.bodySecondary),
                    TextButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(
                        NarooIcons.refresh,
                        size: NarooIcons.inline,
                      ),
                      label: const Text('다시 시도'),
                    ),
                  ],
                )
              else if (!ready)
                const Padding(
                  padding: EdgeInsets.all(NarooSpacing.space48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (summary.total(_type) == 0)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: NarooSpacing.space48,
                  ),
                  child: NarooEmptyState(message: '이 달 ${_type.label}이 없어요.'),
                )
              else
                for (final group in StatisticsGroup.forType(_type))
                  _section(summary, group),
            ],
          ),
        ),
      ),
    );
  }

  Widget _monthSwitcher(DateTime month) => Row(
    children: [
      IconButton(
        tooltip: '이전 달',
        onPressed: () =>
            ref.read(selectedMonthProvider.notifier).goToPreviousMonth(),
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
  );

  Widget _section(StatisticsSummary summary, StatisticsGroup group) {
    final slices = summary.slices(group, _type);
    final total = summary.total(_type);
    final open = _open;
    final selected = open != null && open.$1 == group
        ? slices.indexWhere((slice) => slice.key == open.$2)
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: NarooSpacing.space32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${_type.label} ${group.title}', style: NarooText.section),
          const SizedBox(height: NarooSpacing.space16),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: DonutChart(
                key: ValueKey((summary.month, _type, group)),
                values: [for (final slice in slices) slice.amount],
                colors: [for (final slice in slices) slice.color],
                selected: selected,
                semanticsLabel: [
                  '${_type.label} ${group.title} 원그래프',
                  for (final slice in slices)
                    '${slice.label} ${MoneyFormat.krw(slice.amount)}원 '
                        '${slice.percentOf(total)}',
                ].join(', '),
                onSliceTap: (index) => _openSlice(group, slices[index]),
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_type.label, style: NarooText.caption),
                    Text(
                      '${MoneyFormat.krw(total)}원',
                      style: NarooText.money(
                        NarooText.section,
                        NarooColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: NarooSpacing.space16),
          for (final slice in slices) _legendRow(group, slice, total),
        ],
      ),
    );
  }

  Widget _legendRow(StatisticsGroup group, StatisticsSlice slice, int total) {
    return InkWell(
      borderRadius: BorderRadius.circular(NarooRadius.input),
      onTap: () => _openSlice(group, slice),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: NarooSpacing.space12,
          horizontal: NarooSpacing.space4,
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: slice.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: NarooSpacing.space12),
            Expanded(
              child: Text(
                slice.label,
                style: NarooText.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: NarooSpacing.space8),
            Text(slice.percentOf(total), style: NarooText.caption),
            const SizedBox(width: NarooSpacing.space12),
            Text(
              '${MoneyFormat.krw(slice.amount)}원',
              style: NarooText.money(NarooText.body, NarooColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
