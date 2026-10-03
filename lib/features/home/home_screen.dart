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
import 'budget_sheet.dart';
import 'home_controller.dart';

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
      ref.invalidate(homeMonthProvider);
      ref.invalidate(homeSummaryProvider);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(homeMonthProvider);
    ref.invalidate(homeSummaryProvider);
    try {
      await ref.read(homeSummaryProvider.future);
    } catch (_) {
      /* Render error below. */
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(homeSummaryProvider);
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
          child: summary.when(
            skipLoadingOnReload: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: NarooSpacing.pagePadding,
              children: [
                const SizedBox(height: NarooSpacing.space24),
                Text('이번 달 정보를 불러오지 못했습니다.', style: NarooText.bodySecondary),
                TextButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(NarooIcons.refresh, size: NarooIcons.inline),
                  label: const Text('다시 시도'),
                ),
              ],
            ),
            data: (data) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                NarooSpacing.space20,
                NarooSpacing.space16,
                NarooSpacing.space20,
                96,
              ),
              children: [
                Text(
                  SeoulDate.monthLabel(data.month),
                  style: NarooText.display,
                ),
                const SizedBox(height: NarooSpacing.space24),
                _amount(
                  '이번 달 수입',
                  '+${MoneyFormat.krw(data.income)}원',
                  color: NarooColors.income,
                ),
                _amount(
                  '이번 달 지출',
                  '-${MoneyFormat.krw(data.expense)}원',
                  color: NarooColors.expense,
                ),
                const SizedBox(height: NarooSpacing.space8),
                const Divider(),
                const SizedBox(height: NarooSpacing.space16),
                Text('이번 달 잔액', style: NarooText.bodySecondary),
                const SizedBox(height: NarooSpacing.space4),
                Text(_won(data.balance), style: NarooText.hero),
                const SizedBox(height: NarooSpacing.space24),
                Text('이번 달 예산', style: NarooText.section),
                const SizedBox(height: NarooSpacing.space12),
                if (data.budget == null)
                  Text('아직 예산이 없어요.', style: NarooText.bodySecondary)
                else ...[
                  Text(
                    '${MoneyFormat.krw(data.expense)} / ${MoneyFormat.krw(data.budget!)}원',
                    style: NarooText.money(
                      NarooText.body,
                      NarooColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: NarooSpacing.space8),
                  Text(
                    data.remaining! < 0
                        ? '${MoneyFormat.krw(data.remaining!)}원 초과'
                        : '${MoneyFormat.krw(data.remaining!)}원 남음',
                    style: NarooText.bodySecondary.copyWith(
                      color: data.remaining! < 0
                          ? NarooColors.expense
                          : NarooColors.textSecondary,
                    ),
                  ),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      backgroundColor: NarooColors.surface,
                      barrierColor: NarooColors.barrier,
                      builder: (_) =>
                          BudgetSheet(month: data.month, amount: data.budget),
                    ),
                    child: Text(data.budget == null ? '예산 설정' : '예산 수정'),
                  ),
                ),
                const SizedBox(height: NarooSpacing.space24),
                Text('최근 내역', style: NarooText.section),
                if (data.recent.isEmpty) ...[
                  const SizedBox(height: NarooSpacing.space16),
                  NarooEmptyState(
                    message: '아직 기록이 없어요.',
                    actionLabel: '+ 첫 기록 남기기',
                    onAction: () => context.push(AppRoutes.transactionNew),
                  ),
                ],
                for (final item in data.recent)
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
                        ?item.memoText,
                        SeoulDate.daySectionLabel(item.transaction.occurredOn),
                        item.attributionLabel,
                      ].join(' · '),
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
                    onTap: () => context.push(
                      AppRoutes.transactionEdit(item.transaction.id),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _amount(String label, String amount, {required Color color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: NarooSpacing.space8),
        child: Row(
          children: [
            Text(label, style: NarooText.bodySecondary),
            const SizedBox(width: NarooSpacing.space16),
            Expanded(
              child: Text(
                amount,
                textAlign: TextAlign.end,
                style: NarooText.money(NarooText.body, color),
              ),
            ),
          ],
        ),
      );
  String _won(int amount) =>
      '${amount < 0 ? '-' : ''}${MoneyFormat.krw(amount)}원';
}
