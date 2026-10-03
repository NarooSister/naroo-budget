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
import '../../core/selected_month.dart';
import '../../core/seoul_date.dart';
import 'budget_progress.dart';
import 'budget_sheet.dart';
import 'day_transactions_sheet.dart';
import 'home_controller.dart';
import 'home_summary.dart';
import 'month_calendar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(currentMonthProvider);
      ref.invalidate(homeSummaryProvider);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(currentMonthProvider);
    ref.invalidate(homeSummaryProvider);
    try {
      await ref.read(homeSummaryProvider.future);
    } catch (_) {
      /* Render error below. */
    }
  }

  void _showSheet(Widget sheet) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: NarooColors.surface,
    barrierColor: NarooColors.barrier,
    builder: (_) => sheet,
  );

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(selectedMonthProvider);
    final summary = ref.watch(homeSummaryProvider);
    final data = summary.value;
    return Scaffold(
      appBar: AppBar(title: const NarooWordmark(style: NarooText.appBarTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.transactionNew),
        tooltip: '기록 추가',
        child: const Icon(NarooIcons.add, size: NarooIcons.action),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              NarooSpacing.space8,
              NarooSpacing.space8,
              NarooSpacing.space20,
              96,
            ),
            children: [
              _header(month, data),
              Padding(
                padding: const EdgeInsets.only(left: NarooSpacing.space12),
                child: summary.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(NarooSpacing.space48),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: NarooSpacing.space24),
                      Text(
                        '이 달 정보를 불러오지 못했습니다.',
                        style: NarooText.bodySecondary,
                      ),
                      TextButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(
                          NarooIcons.refresh,
                          size: NarooIcons.inline,
                        ),
                        label: const Text('다시 시도'),
                      ),
                    ],
                  ),
                  data: (data) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Divider(),
                      _budget(data),
                      const Divider(),
                      const SizedBox(height: NarooSpacing.space8),
                      MonthCalendar(
                        month: data.month,
                        totals: data.dailyTotals,
                        today: SeoulDate.today(),
                        onDayTap: (day) =>
                            _showSheet(DayTransactionsSheet(day: day)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(DateTime month, HomeSummary? data) {
    final ready = data != null && data.month == month;
    return Row(
      children: [
        IconButton(
          tooltip: '이전 달',
          onPressed: () =>
              ref.read(selectedMonthProvider.notifier).goToPreviousMonth(),
          icon: const Icon(NarooIcons.back, size: NarooIcons.action),
        ),
        Text(SeoulDate.monthLabel(month), style: NarooText.section),
        IconButton(
          tooltip: '다음 달',
          onPressed: () =>
              ref.read(selectedMonthProvider.notifier).goToNextMonth(),
          icon: const Icon(NarooIcons.forward, size: NarooIcons.action),
        ),
        const SizedBox(width: NarooSpacing.space8),
        Expanded(
          child: ready
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _total(
                        '지출',
                        '-${MoneyFormat.krw(data.expense)}원',
                        NarooColors.expense,
                      ),
                      _total(
                        '수입',
                        '+${MoneyFormat.krw(data.income)}원',
                        NarooColors.income,
                      ),
                      _total('잔액', _won(data.balance), NarooColors.textPrimary),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _total(String label, String amount, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: NarooText.caption.copyWith(color: NarooColors.textSecondary),
      ),
      const SizedBox(width: NarooSpacing.space8),
      Text(amount, style: NarooText.money(NarooText.body, color)),
    ],
  );

  Widget _budget(HomeSummary data) {
    final budget = data.budget;
    return InkWell(
      borderRadius: BorderRadius.circular(NarooRadius.input),
      onTap: () => budget == null
          ? showBudgetSheet(context, month: data.month)
          : context.push(AppRoutes.budget),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: NarooSpacing.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('예산', style: NarooText.section)),
                if (budget == null)
                  Text(
                    '예산 설정',
                    style: NarooText.body.copyWith(color: NarooColors.primary),
                  )
                else
                  const Icon(NarooIcons.forward, size: NarooIcons.inline),
              ],
            ),
            const SizedBox(height: NarooSpacing.space8),
            if (budget == null)
              Text('아직 예산이 없어요.', style: NarooText.bodySecondary)
            else
              BudgetProgress(spent: data.expense, budget: budget.amount),
          ],
        ),
      ),
    );
  }

  String _won(int amount) =>
      '${amount < 0 ? '-' : ''}${MoneyFormat.krw(amount)}원';
}
