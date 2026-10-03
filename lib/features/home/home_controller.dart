import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/category_changes.dart';
import '../../core/household_member_changes.dart';
import '../../core/selected_month.dart';
import '../../core/seoul_date.dart';
import '../../core/session/app_session.dart';
import '../../core/transaction_changes.dart';
import '../../data/models/category.dart';
import '../../data/models/monthly_budget.dart';
import '../../data/repositories/monthly_budget_repository.dart';
import '../../data/repository_providers.dart';
import 'home_summary.dart';

final homeSummaryProvider = FutureProvider.autoDispose<HomeSummary>((
  ref,
) async {
  final month = ref.watch(selectedMonthProvider);
  // Writes refresh in place; only a month change shows the loading state.
  ref.listen(transactionChangesProvider, (_, _) => ref.invalidateSelf());
  ref.listen(householdMemberChangesProvider, (_, _) => ref.invalidateSelf());
  // Deleting a category removes its allocation on the server.
  ref.listen(categoryChangesProvider, (_, _) => ref.invalidateSelf());
  final householdId = await _householdId(ref);
  final items = await ref
      .read(transactionRepositoryProvider)
      .listByMonth(householdId: householdId, month: month);
  final budget = await ref
      .read(monthlyBudgetRepositoryProvider)
      .find(householdId, month);
  return HomeSummary(month: month, budget: budget, items: items);
});

/// Expense top-level categories that can receive an allocation.
final budgetCategoriesProvider = FutureProvider.autoDispose<List<Category>>((
  ref,
) async {
  ref.watch(categoryChangesProvider);
  final householdId = await _householdId(ref);
  final categories = await ref
      .read(categoryRepositoryProvider)
      .listByHousehold(householdId, type: CategoryType.expense);
  return [
    for (final category in categories)
      if (!category.isSubcategory && !category.isUncategorized) category,
  ];
});

Future<String> _householdId(Ref ref) async {
  final session = await ref.watch(appSessionProvider.future);
  final householdId = session.member?.householdId;
  if (householdId == null) throw StateError('Household 연결이 필요합니다.');
  return householdId;
}

enum BudgetWriteResult { done, conflict, failed }

final budgetEditorProvider = NotifierProvider.autoDispose<BudgetEditor, bool>(
  BudgetEditor.new,
);

class BudgetEditor extends Notifier<bool> {
  @override
  bool build() => false;

  /// Latest server budget, used for "지난달 예산 불러오기" and reloading after
  /// a conflict. Returns null when the month has no budget.
  Future<MonthlyBudget?> load(DateTime month) async {
    final session = await ref.read(appSessionProvider.future);
    final householdId = session.member?.householdId;
    if (householdId == null) throw StateError('Household 연결이 필요합니다.');
    return ref.read(monthlyBudgetRepositoryProvider).find(householdId, month);
  }

  Future<MonthlyBudget?> loadPrevious(DateTime month) =>
      load(SeoulDate.previousMonth(month));

  Future<BudgetWriteResult> save(
    DateTime month, {
    required int amount,
    required Map<String, int> allocations,
    required String? expectedVersion,
  }) => _write(
    (repository, householdId) => repository.save(
      householdId,
      month,
      amount: amount,
      allocations: allocations,
      expectedVersion: expectedVersion,
    ),
  );

  Future<BudgetWriteResult> reset(
    DateTime month, {
    required String? expectedVersion,
  }) => _write(
    (repository, householdId) =>
        repository.reset(householdId, month, expectedVersion: expectedVersion),
  );

  Future<BudgetWriteResult> _write(
    Future<void> Function(
      MonthlyBudgetRepository repository,
      String householdId,
    )
    write,
  ) async {
    if (state) return BudgetWriteResult.failed;
    final link = ref.keepAlive();
    state = true;
    try {
      final session = await ref.read(appSessionProvider.future);
      final householdId = session.member?.householdId;
      if (householdId == null) throw StateError('Household 연결이 필요합니다.');
      await write(ref.read(monthlyBudgetRepositoryProvider), householdId);
      if (ref.mounted) ref.invalidate(homeSummaryProvider);
      return BudgetWriteResult.done;
    } on BudgetConflictException {
      if (ref.mounted) ref.invalidate(homeSummaryProvider);
      return BudgetWriteResult.conflict;
    } catch (_) {
      return BudgetWriteResult.failed;
    } finally {
      if (ref.mounted) state = false;
      link.close();
    }
  }
}
