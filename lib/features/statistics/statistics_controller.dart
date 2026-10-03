import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/category_changes.dart';
import '../../core/household_member_changes.dart';
import '../../core/selected_month.dart';
import '../../core/session/app_session.dart';
import '../../core/transaction_changes.dart';
import '../../data/repository_providers.dart';
import 'statistics_summary.dart';

final statisticsProvider = FutureProvider.autoDispose<StatisticsSummary>((
  ref,
) async {
  final month = ref.watch(selectedMonthProvider);
  // Writes and renames refresh in place; only a month change shows loading.
  ref.listen(transactionChangesProvider, (_, _) => ref.invalidateSelf());
  ref.listen(householdMemberChangesProvider, (_, _) => ref.invalidateSelf());
  ref.listen(categoryChangesProvider, (_, _) => ref.invalidateSelf());
  final session = await ref.watch(appSessionProvider.future);
  final householdId = session.member?.householdId;
  if (householdId == null) throw StateError('Household 연결이 필요합니다.');
  final items = await ref
      .read(transactionRepositoryProvider)
      .listByMonth(householdId: householdId, month: month);
  return StatisticsSummary(month: month, items: items);
});
