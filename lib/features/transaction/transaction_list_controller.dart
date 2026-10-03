import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/seoul_date.dart';
import '../../core/household_member_changes.dart';
import '../../core/session/app_session.dart';
import '../../core/transaction_changes.dart';
import '../../data/models/category.dart';
import '../../data/models/transaction.dart';
import '../../data/repository_providers.dart';

enum TransactionListFilter {
  all,
  expense,
  income;

  String get label => switch (this) {
    TransactionListFilter.all => '전체',
    TransactionListFilter.expense => '지출',
    TransactionListFilter.income => '수입',
  };

  CategoryType? get categoryType => switch (this) {
    TransactionListFilter.all => null,
    TransactionListFilter.expense => CategoryType.expense,
    TransactionListFilter.income => CategoryType.income,
  };
}

class TransactionListMonth extends Notifier<DateTime> {
  @override
  DateTime build() => SeoulDate.monthStart();

  void goToPreviousMonth() {
    state = SeoulDate.previousMonth(state);
  }

  void goToNextMonth() {
    state = SeoulDate.nextMonth(state);
  }
}

final transactionListMonthProvider =
    NotifierProvider<TransactionListMonth, DateTime>(TransactionListMonth.new);

class TransactionListFilterNotifier extends Notifier<TransactionListFilter> {
  @override
  TransactionListFilter build() => TransactionListFilter.all;

  void setFilter(TransactionListFilter filter) {
    state = filter;
  }
}

final transactionListFilterProvider =
    NotifierProvider<TransactionListFilterNotifier, TransactionListFilter>(
      TransactionListFilterNotifier.new,
    );

final monthlyTransactionsProvider =
    FutureProvider.autoDispose<List<TransactionListItem>>((ref) async {
      // A successful write refreshes this query without discarding the previous
      // list or changing the independently selected month and filter.
      ref.listen(transactionChangesProvider, (_, _) => ref.invalidateSelf());
      ref.listen(
        householdMemberChangesProvider,
        (_, _) => ref.invalidateSelf(),
      );
      final session = await ref.watch(appSessionProvider.future);
      final householdId = session.member?.householdId;
      if (householdId == null) {
        return const [];
      }

      final month = ref.watch(transactionListMonthProvider);
      final filter = ref.watch(transactionListFilterProvider);

      return ref
          .read(transactionRepositoryProvider)
          .listByMonth(
            householdId: householdId,
            month: month,
            type: filter.categoryType,
          );
    });

List<TransactionDayGroup> groupTransactionsByDate(
  List<TransactionListItem> items, {
  DateTime? today,
}) {
  final groups = <DateTime, List<TransactionListItem>>{};
  for (final item in items) {
    final day = DateTime(
      item.transaction.occurredOn.year,
      item.transaction.occurredOn.month,
      item.transaction.occurredOn.day,
    );
    groups.putIfAbsent(day, () => []).add(item);
  }

  final sortedDays = groups.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final day in sortedDays)
      TransactionDayGroup(
        date: day,
        label: SeoulDate.daySectionLabel(day, today: today),
        items: groups[day]!,
      ),
  ];
}

class TransactionDayGroup {
  const TransactionDayGroup({
    required this.date,
    required this.label,
    required this.items,
  });

  final DateTime date;
  final String label;
  final List<TransactionListItem> items;
}
