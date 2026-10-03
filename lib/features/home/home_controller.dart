import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/household_member_changes.dart';
import '../../core/selected_month.dart';
import '../../core/session/app_session.dart';
import '../../core/transaction_changes.dart';
import '../../data/repository_providers.dart';
import 'home_summary.dart';

final homeSummaryProvider = FutureProvider.autoDispose<HomeSummary>((
  ref,
) async {
  final month = ref.watch(selectedMonthProvider);
  // Writes refresh in place; only a month change shows the loading state.
  ref.listen(transactionChangesProvider, (_, _) => ref.invalidateSelf());
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
