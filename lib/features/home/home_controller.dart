import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/seoul_date.dart';
import '../../core/household_member_changes.dart';
import '../../core/session/app_session.dart';
import '../../core/transaction_changes.dart';
import '../../data/repository_providers.dart';
import 'home_summary.dart';

/// Web `setTimeout` stores the delay as a signed 32-bit millisecond count.
/// A wait longer than about 24.8 days overflows and runs immediately, so each
/// timer stays within one day and the provider recomputes until the month changes.
const homeMonthMaxTimerDelay = Duration(hours: 24);

Duration homeMonthTimerDelay({
  required DateTime nowUtc,
  required DateTime month,
}) {
  final nextMonthStartUtc = DateTime.utc(
    month.year,
    month.month + 1,
  ).subtract(const Duration(hours: 9));
  final remaining = nextMonthStartUtc.difference(nowUtc);
  if (remaining > homeMonthMaxTimerDelay) return homeMonthMaxTimerDelay;
  if (remaining < const Duration(milliseconds: 1)) {
    return const Duration(seconds: 1);
  }
  return remaining;
}

final homeMonthProvider = Provider.autoDispose<DateTime>((ref) {
  final now = DateTime.now().toUtc();
  final month = SeoulDate.monthStart();
  final timer = Timer(
    homeMonthTimerDelay(nowUtc: now, month: month),
    ref.invalidateSelf,
  );
  ref.onDispose(timer.cancel);
  return month;
});

final homeSummaryProvider = FutureProvider.autoDispose<HomeSummary>((
  ref,
) async {
  final month = ref.watch(homeMonthProvider);
  ref.watch(transactionChangesProvider);
  ref.listen(householdMemberChangesProvider, (_, _) => ref.invalidateSelf());
  final session = await ref.watch(appSessionProvider.future);
  final householdId = session.member?.householdId;
  if (householdId == null) throw StateError('Household 연결이 필요합니다.');
  final items = await ref
      .read(transactionRepositoryProvider)
      .listByMonth(householdId: householdId, month: month);
  final budget = await ref
      .read(monthlyBudgetRepositoryProvider)
      .find(householdId, month);
  return HomeSummary(month: month, budget: budget, items: items);
});

final budgetEditorProvider = NotifierProvider.autoDispose<BudgetEditor, bool>(
  BudgetEditor.new,
);

class BudgetEditor extends Notifier<bool> {
  @override
  bool build() => false;

  Future<bool> save(DateTime month, int amount) async {
    if (state) return false;
    final link = ref.keepAlive();
    state = true;
    try {
      final session = await ref.read(appSessionProvider.future);
      final householdId = session.member?.householdId;
      if (householdId == null) throw StateError('Household 연결이 필요합니다.');
      await ref
          .read(monthlyBudgetRepositoryProvider)
          .save(householdId, month, amount);
      if (ref.mounted) ref.invalidate(homeSummaryProvider);
      return true;
    } catch (_) {
      return false;
    } finally {
      if (ref.mounted) state = false;
      link.close();
    }
  }
}
