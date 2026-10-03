import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:naroo/core/selected_month.dart';
import 'package:naroo/core/session/app_session.dart';
import 'package:naroo/core/transaction_changes.dart';
import 'package:naroo/data/models/category.dart';
import 'package:naroo/data/models/household_member.dart';
import 'package:naroo/data/models/profile.dart';
import 'package:naroo/data/models/transaction.dart';
import 'package:naroo/data/repository_providers.dart';
import 'package:naroo/features/home/home_controller.dart';
import 'package:naroo/features/home/home_screen.dart';
import 'package:naroo/features/home/home_summary.dart';
import 'package:naroo/features/settings/settings_screen.dart';
import 'package:naroo/features/transaction/transaction_editor_controller.dart';
import 'package:naroo/features/transaction/transaction_list_controller.dart';

import 'fake_household_member_repository.dart';
import 'fake_monthly_budget_repository.dart';
import 'fake_transaction_repository.dart';

const member = HouseholdMember(
  id: 'm',
  householdId: 'h',
  userId: 'u',
  displayName: '나루',
);

class Session extends AppSessionNotifier {
  @override
  Future<AppSession> build() async => const AppSession.ready(
    userId: 'u',
    email: 'u@example.com',
    profile: Profile(id: 'u', displayName: '나루'),
    member: member,
  );
  @override
  Future<void> signOut() async => throw StateError('private error');
}

class GatedTransactions extends FakeTransactionRepository {
  GatedTransactions(super.seed);
  Completer<void>? gate;

  @override
  Future<List<TransactionListItem>> listByMonth({
    required String householdId,
    required DateTime month,
    CategoryType? type,
  }) async {
    final pending = gate;
    if (pending != null) await pending.future;
    return super.listByMonth(
      householdId: householdId,
      month: month,
      type: type,
    );
  }
}

class Budget extends FakeMonthlyBudgetRepository {
  set amount(int value) =>
      budgets[DateTime(2026, 12)] = FakeMonthlyBudgetRepository.budget(value);
}

TransactionListItem item(
  int amount,
  CategoryType type,
  DateTime date, {
  String household = 'h',
}) => TransactionListItem(
  categoryName: '식비',
  memberName: '나루',
  transaction: Transaction(
    id: '$amount',
    householdId: household,
    memberId: 'm',
    type: type,
    amount: amount,
    categoryId: 'c',
    occurredOn: date,
  ),
);

Future<List<TransactionListItem>> listed(ProviderContainer container) async {
  await container.read(monthTransactionsProvider.future);
  return container.read(monthlyTransactionsProvider).requireValue;
}

void main() {
  test('월 목록은 변경 알림 후 기존 데이터와 선택 월/필터를 유지하며 갱신한다', () async {
    final repo = GatedTransactions([]);
    final container = ProviderContainer(
      overrides: [
        appSessionProvider.overrideWith(Session.new),
        transactionRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    container.read(selectedMonthProvider.notifier).goToPreviousMonth();
    container
        .read(transactionListFilterProvider.notifier)
        .setFilter(TransactionListFilter.expense);
    final selectedMonth = container.read(selectedMonthProvider);
    for (final type in CategoryType.values) {
      await repo.create(
        NewTransaction(
          householdId: 'h',
          memberId: 'm',
          type: type,
          amount: 100,
          categoryId: 'c',
          occurredOn: selectedMonth,
        ),
      );
    }
    final sub = container.listen(monthlyTransactionsProvider, (_, _) {});
    addTearDown(sub.close);
    expect((await listed(container)).length, 1);
    repo.gate = Completer<void>();
    container.read(transactionChangesProvider.notifier).changed();
    await container.pump();
    final refreshing = container.read(monthlyTransactionsProvider);
    expect(refreshing.isRefreshing, true);
    expect(refreshing.requireValue.single.transaction.amount, 100);
    expect(container.read(selectedMonthProvider), selectedMonth);
    expect(
      container.read(transactionListFilterProvider),
      TransactionListFilter.expense,
    );
    repo.gate!.complete();
    expect((await listed(container)).length, 1);
    expect(repo.listCalls, 2);
    container
        .read(transactionListFilterProvider.notifier)
        .setFilter(TransactionListFilter.all);
    expect((await listed(container)).length, 2);
    expect(repo.listCalls, 2, reason: '필터 변경은 다시 조회하지 않는다');
  });

  test('실패한 거래 저장은 홈/내역을 갱신하지 않고 성공한 재시도는 갱신한다', () async {
    final repo = FakeTransactionRepository()..writeError = StateError('failed');
    final container = ProviderContainer(
      overrides: [
        appSessionProvider.overrideWith(Session.new),
        transactionRepositoryProvider.overrideWithValue(repo),
        monthlyBudgetRepositoryProvider.overrideWithValue(Budget()),
        currentMonthProvider.overrideWith((ref) => DateTime(2026, 12)),
      ],
    );
    addTearDown(container.dispose);
    final homeSub = container.listen(homeSummaryProvider, (_, _) {});
    final listSub = container.listen(monthlyTransactionsProvider, (_, _) {});
    final editorSub = container.listen(
      transactionEditorProvider(null),
      (_, _) {},
    );
    addTearDown(homeSub.close);
    addTearDown(listSub.close);
    addTearDown(editorSub.close);
    await container.read(homeSummaryProvider.future);
    await listed(container);
    final calls = repo.listCalls;
    final editor = container.read(transactionEditorProvider(null).notifier);
    final input = NewTransaction(
      householdId: 'h',
      memberId: 'm',
      type: CategoryType.income,
      amount: 100,
      categoryId: 'c',
      occurredOn: DateTime(2026, 12, 1),
    );
    expect(await editor.save(input), false);
    await container.pump();
    expect(repo.listCalls, calls);
    expect(container.read(transactionChangesProvider), 0);
    repo.writeError = null;
    expect(await editor.save(input), true);
    expect((await container.read(homeSummaryProvider.future)).income, 100);
    await listed(container);
    expect(repo.listCalls, calls + 2);
  });

  test('홈은 선택 월/Household 전체 거래로 계산하며 내역과 같은 월을 쓴다', () async {
    final repo = FakeTransactionRepository([
      item(100, CategoryType.income, DateTime(2026, 12, 1)),
      item(250, CategoryType.expense, DateTime(2026, 12, 31)),
      item(999, CategoryType.expense, DateTime(2027, 1, 1)),
      item(
        888,
        CategoryType.income,
        DateTime(2026, 12, 10),
        household: 'other',
      ),
    ]);
    final budget = Budget()..amount = 200;
    var currentMonth = DateTime(2026, 12);
    final container = ProviderContainer(
      overrides: [
        appSessionProvider.overrideWith(Session.new),
        currentMonthProvider.overrideWith((ref) => currentMonth),
        transactionRepositoryProvider.overrideWithValue(repo),
        monthlyBudgetRepositoryProvider.overrideWithValue(budget),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(homeSummaryProvider, (_, _) {});
    addTearDown(sub.close);
    final summary = await container.read(homeSummaryProvider.future);
    expect(summary.income, 100);
    expect(summary.expense, 250);
    expect(summary.balance, -150);
    expect(summary.remaining, -50);
    await container
        .read(transactionEditorProvider(null).notifier)
        .save(
          NewTransaction(
            householdId: 'h',
            memberId: 'm',
            type: CategoryType.income,
            amount: 300,
            categoryId: 'c',
            occurredOn: DateTime(2026, 12, 15),
          ),
        );
    expect((await container.read(homeSummaryProvider.future)).balance, 150);
    final edit = container.read(transactionEditorProvider('250').notifier);
    final editSub = container.listen(
      transactionEditorProvider('250'),
      (_, _) {},
    );
    addTearDown(editSub.close);
    await edit.loadExisting();
    await edit.save(
      NewTransaction(
        householdId: 'h',
        memberId: 'm',
        type: CategoryType.expense,
        amount: 200,
        categoryId: 'c',
        occurredOn: DateTime(2026, 12, 31),
      ),
    );
    expect((await container.read(homeSummaryProvider.future)).remaining, 0);
    await edit.delete();
    expect((await container.read(homeSummaryProvider.future)).expense, 0);
    container.read(selectedMonthProvider.notifier).goToNextMonth();
    final january = await container.read(homeSummaryProvider.future);
    expect(january.month, DateTime(2027, 1));
    expect(january.expense, 999);
    expect(january.income, 0);
    final listSub = container.listen(monthlyTransactionsProvider, (_, _) {});
    addTearDown(listSub.close);
    expect((await listed(container)).single.transaction.amount, 999);

    container.read(selectedMonthProvider.notifier).goToPreviousMonth();
    container.read(selectedMonthProvider.notifier).goToPreviousMonth();
    expect(container.read(selectedMonthProvider), DateTime(2026, 11));
    currentMonth = DateTime(2027, 1);
    container.invalidate(currentMonthProvider);
    expect(
      container.read(selectedMonthProvider),
      DateTime(2027, 1),
      reason: '서울 월이 바뀌면 이번 달로 돌아간다',
    );
  });
  test('월 경계 대기는 웹 타이머 한계 안에서 다음 달까지 다시 건다', () {
    final octoberStart = DateTime.utc(
      2026,
      10,
      1,
    ).subtract(const Duration(hours: 9));
    expect(
      currentMonthTimerDelay(nowUtc: octoberStart, month: DateTime(2026, 10)),
      currentMonthMaxTimerDelay,
    );
    final decemberStart = DateTime.utc(
      2026,
      12,
      1,
    ).subtract(const Duration(hours: 9));
    expect(
      currentMonthTimerDelay(nowUtc: decemberStart, month: DateTime(2026, 12)),
      currentMonthMaxTimerDelay,
    );
    final nextMonth = DateTime.utc(
      2026,
      11,
      1,
    ).subtract(const Duration(hours: 9));
    expect(
      currentMonthTimerDelay(
        nowUtc: nextMonth.subtract(const Duration(hours: 2)),
        month: DateTime(2026, 10),
      ),
      const Duration(hours: 2),
    );
    expect(
      currentMonthTimerDelay(
        nowUtc: nextMonth.add(const Duration(minutes: 1)),
        month: DateTime(2026, 10),
      ),
      const Duration(seconds: 1),
    );
    expect(currentMonthMaxTimerDelay.inMilliseconds, lessThan(2147483647));
  });
  test('빈 월, 미설정, 0원과 날짜별 수입/지출 합계를 구분한다', () {
    final empty = HomeSummary(
      month: DateTime(2026, 1),
      budget: null,
      items: [],
    );
    expect(empty.balance, 0);
    expect(empty.remaining, null);
    expect(empty.dailyTotals, isEmpty);
    expect(empty.itemsOn(DateTime(2026, 1, 1)), isEmpty);
    expect(empty.spentIn('c'), 0);
    final zero = HomeSummary(
      month: DateTime(2026, 1),
      budget: FakeMonthlyBudgetRepository.budget(0),
      items: [
        for (var i = 0; i < 8; i++)
          item(1, CategoryType.expense, DateTime(2026, 1, 1)),
        item(500, CategoryType.income, DateTime(2026, 1, 1)),
        item(30, CategoryType.expense, DateTime(2026, 1, 31)),
      ],
    );
    expect(zero.remaining, -38);
    final first = zero.dailyTotals[DateTime(2026, 1, 1)]!;
    expect(first.income, 500);
    expect(first.expense, 8);
    expect(zero.dailyTotals[DateTime(2026, 1, 31)]!.expense, 30);
    expect(zero.dailyTotals[DateTime(2026, 1, 2)], isNull);
    expect(zero.itemsOn(DateTime(2026, 1, 1)), hasLength(9));
    expect(zero.spentIn('c'), 38, reason: '수입은 카테고리 지출에 포함하지 않는다');
    expect(zero.expensesIn('c'), hasLength(9));
  });
  test('예산 연속 저장 차단 및 실패 후 재시도', () async {
    final budget = Budget()..pending = Completer<void>();
    final container = ProviderContainer(
      overrides: [
        appSessionProvider.overrideWith(Session.new),
        monthlyBudgetRepositoryProvider.overrideWithValue(budget),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(budgetEditorProvider, (_, _) {});
    addTearDown(sub.close);
    final editor = container.read(budgetEditorProvider.notifier);
    Future<BudgetWriteResult> save(int amount, String? version) => editor.save(
      DateTime(2026, 12),
      amount: amount,
      allocations: const {},
      expectedVersion: version,
    );
    final first = save(0, null);
    expect(await save(100, null), BudgetWriteResult.failed);
    budget.pending!.complete();
    expect(await first, BudgetWriteResult.done);
    expect(budget.writes, 1);
    final saved = budget.budgets[DateTime(2026, 12)]!.version;
    budget.fail = true;
    expect(await save(100, saved), BudgetWriteResult.failed);
    budget.fail = false;
    expect(
      await save(100, null),
      BudgetWriteResult.conflict,
      reason: '빈 달로 알고 저장했지만 이미 저장된 경우',
    );
    expect(await save(100, saved), BudgetWriteResult.done);
    expect(budget.budgets[DateTime(2026, 12)]!.amount, 100);
    expect(
      await editor.reset(DateTime(2026, 12), expectedVersion: saved),
      BudgetWriteResult.conflict,
    );
    expect(budget.budgets[DateTime(2026, 12)], isNotNull);
  });
  testWidgets('홈 예산 입력 검증, 저장, 수정과 초과 표시', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final budget = Budget();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith(Session.new),
          currentMonthProvider.overrideWith((ref) => DateTime(2026, 12)),
          monthlyBudgetRepositoryProvider.overrideWithValue(budget),
          transactionRepositoryProvider.overrideWithValue(
            FakeTransactionRepository([
              item(100, CategoryType.expense, DateTime(2026, 12, 1)),
            ]),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('-100원'), findsWidgets);
    await tester.tap(find.text('예산 설정'));
    await tester.pumpAndSettle();
    for (final raw in ['', '-1', '+1', '1.5', '1,000', '2147483648']) {
      await tester.enterText(find.byType(TextField), raw);
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(budget.writes, 0);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        raw,
      );
      expect(find.text('0~2,147,483,647 사이의 정수를 입력해 주세요.'), findsOneWidget);
    }
    budget.fail = true;
    await tester.enterText(find.byType(TextField), ' 200 ');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      ' 200 ',
    );
    expect(find.text('예산을 저장하지 못했습니다. 다시 시도해 주세요.'), findsOneWidget);
    budget.fail = false;
    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('100원 초과'), findsOneWidget);
  });
  testWidgets('거래가 바뀌면 이전 홈 합계를 유지한 채 다시 불러온다', (tester) async {
    final transactions = GatedTransactions([
      item(100, CategoryType.expense, DateTime(2026, 12, 1)),
    ]);
    final container = ProviderContainer(
      overrides: [
        appSessionProvider.overrideWith(Session.new),
        currentMonthProvider.overrideWith((ref) => DateTime(2026, 12)),
        monthlyBudgetRepositoryProvider.overrideWithValue(Budget()),
        transactionRepositoryProvider.overrideWithValue(transactions),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('-100원'), findsWidgets);
    transactions.gate = Completer<void>();
    container.read(transactionChangesProvider.notifier).changed();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('-100원'), findsWidgets);
    transactions.gate!.complete();
    await tester.pumpAndSettle();
  });
  testWidgets('설정은 같은 Household 구성원과 로그아웃 실패를 표시한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith(Session.new),
          householdMemberRepositoryProvider.overrideWithValue(
            FakeHouseholdMemberRepository([member]),
          ),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('나루'), findsNWidgets(2));
    expect(find.text('나'), findsOneWidget);
    expect(find.text('u@example.com'), findsOneWidget);
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    expect(find.text('로그아웃하지 못했습니다. 다시 시도해 주세요.'), findsOneWidget);
    expect(find.textContaining('private error'), findsNothing);
  });
}
