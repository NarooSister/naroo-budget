import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:naroo/app/app.dart';
import 'package:naroo/core/selected_month.dart';
import 'package:naroo/core/seoul_date.dart';
import 'package:naroo/core/session/app_session.dart';
import 'package:naroo/data/models/category.dart';
import 'package:naroo/data/models/household_member.dart';
import 'package:naroo/data/models/profile.dart';
import 'package:naroo/data/models/transaction.dart';
import 'package:naroo/data/repository_providers.dart';

import 'fake_category_repository.dart';
import 'fake_household_member_repository.dart';
import 'fake_monthly_budget_repository.dart';
import 'fake_transaction_repository.dart';

const _member = HouseholdMember(
  id: 'member-1',
  householdId: 'household-1',
  userId: 'user-1',
  displayName: '나루',
);

class _Session extends AppSessionNotifier {
  @override
  Future<AppSession> build() async => const AppSession.ready(
    userId: 'user-1',
    profile: Profile(id: 'user-1', displayName: '나루'),
    member: _member,
  );
}

TransactionListItem _item(
  String id,
  int amount,
  CategoryType type,
  DateTime date, {
  String? memo,
}) => TransactionListItem(
  transaction: Transaction(
    id: id,
    householdId: 'household-1',
    memberId: 'member-1',
    type: type,
    amount: amount,
    categoryId: type == CategoryType.income ? 'salary' : 'food',
    occurredOn: date,
    memo: memo,
  ),
  categoryName: type == CategoryType.income ? '월급' : '식비',
  memberName: '나루',
);

Future<FakeTransactionRepository> _pumpApp(
  WidgetTester tester,
  List<TransactionListItem> seed, {
  Map<DateTime, int>? budgets,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final transactions = FakeTransactionRepository(seed);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appSessionProvider.overrideWith(_Session.new),
        currentMonthProvider.overrideWith((ref) => DateTime(2026, 8)),
        monthlyBudgetRepositoryProvider.overrideWithValue(
          FakeMonthlyBudgetRepository({
            for (final entry in (budgets ?? <DateTime, int>{}).entries)
              entry.key: FakeMonthlyBudgetRepository.budget(entry.value),
          }),
        ),
        categoryRepositoryProvider.overrideWithValue(
          FakeCategoryRepository(const [
            Category(
              id: 'food',
              householdId: 'household-1',
              type: CategoryType.expense,
              name: '식비',
            ),
            Category(
              id: 'salary',
              householdId: 'household-1',
              type: CategoryType.income,
              name: '월급',
            ),
          ]),
        ),
        householdMemberRepositoryProvider.overrideWithValue(
          FakeHouseholdMemberRepository([_member]),
        ),
        transactionRepositoryProvider.overrideWithValue(transactions),
      ],
      child: const NarooApp(),
    ),
  );
  await tester.pumpAndSettle();
  return transactions;
}

void main() {
  test('yyyy-MM-dd만 날짜로 해석한다', () {
    expect(SeoulDate.tryParse('2026-08-15'), DateTime(2026, 8, 15));
    expect(SeoulDate.tryParse('2028-02-29'), DateTime(2028, 2, 29));
    for (final raw in [null, '', '2026-8-15', '2026-02-30', '2026-13-01']) {
      expect(SeoulDate.tryParse(raw), isNull, reason: '$raw');
    }
  });

  testWidgets('홈은 월 합계·잔액·예산과 날짜별 수입/지출 달력을 표시한다', (tester) async {
    await _pumpApp(
      tester,
      [
        _item('a', 12000, CategoryType.expense, DateTime(2026, 8, 3)),
        _item('b', 3000, CategoryType.expense, DateTime(2026, 8, 3)),
        _item('c', 2500000, CategoryType.income, DateTime(2026, 8, 25)),
        _item('d', 7000, CategoryType.expense, DateTime(2026, 7, 31)),
      ],
      budgets: {DateTime(2026, 8): 20000},
    );

    expect(find.text('2026년 8월'), findsOneWidget);
    expect(find.text('-15,000원'), findsOneWidget);
    expect(find.text('+2,500,000원'), findsOneWidget);
    expect(find.text('2,485,000원'), findsOneWidget);
    expect(find.text('5,000원 남음'), findsOneWidget);
    expect(find.text('-15,000'), findsOneWidget);
    expect(find.text('+2,500,000'), findsOneWidget);
    expect(find.text('-7,000'), findsNothing);
    // August 2026 starts on Saturday and needs six weeks.
    expect(find.text('31'), findsOneWidget);
    expect(find.bySemanticsLabel('8월 3일, 지출 15,000원'), findsOneWidget);
    expect(find.bySemanticsLabel('8월 25일, 수입 2,500,000원'), findsOneWidget);

    await tester.tap(find.byTooltip('이전 달'));
    await tester.pumpAndSettle();
    expect(find.text('2026년 7월'), findsOneWidget);
    expect(find.text('-7,000'), findsOneWidget);
    expect(find.text('아직 예산이 없어요.'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, '내역'));
    await tester.pumpAndSettle();
    expect(find.text('2026년 7월'), findsOneWidget, reason: '홈과 같은 월');
    await tester.tap(find.text('수입'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('다음 달'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, '홈'));
    await tester.pumpAndSettle();
    expect(find.text('2026년 8월'), findsOneWidget);
    expect(find.text('-15,000원'), findsOneWidget, reason: '필터는 홈에 영향 없음');
  });

  testWidgets('날짜를 누르면 그날 내역 시트에서 상세 삭제와 날짜 지정 추가를 한다', (tester) async {
    final transactions = await _pumpApp(tester, [
      _item('a', 12000, CategoryType.expense, DateTime(2026, 8, 3), memo: '점심'),
      _item('b', 3000, CategoryType.expense, DateTime(2026, 8, 3)),
      _item('c', 2500000, CategoryType.income, DateTime(2026, 8, 25)),
    ]);

    await tester.tap(find.bySemanticsLabel('8월 3일, 지출 15,000원'));
    await tester.pumpAndSettle();
    expect(find.text('8월 3일'), findsOneWidget);
    expect(find.text('지출 -15,000원'), findsOneWidget);
    expect(find.text('점심 · 나루'), findsOneWidget);
    expect(find.text('-3,000원'), findsOneWidget);

    await tester.tap(find.text('점심 · 나루'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, '삭제'),
      ),
    );
    await tester.pumpAndSettle();
    expect(transactions.deletedIds, ['a']);
    expect(find.text('8월 3일'), findsOneWidget, reason: '일별 시트로 돌아온다');
    expect(find.text('점심 · 나루'), findsNothing);
    expect(find.text('지출 -3,000원'), findsOneWidget);

    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    expect(find.text('-3,000'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('8월 10일'));
    await tester.pumpAndSettle();
    expect(find.text('이 날 기록이 없어요.'), findsOneWidget);
    await tester.tap(find.text('이 날짜에 기록 추가'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '기록 추가'), findsOneWidget);
    expect(find.text('2026년 8월 10일'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '5000');
    await tester.tap(find.text('식비'));
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();
    expect(transactions.created.single.occurredOn, DateTime(2026, 8, 10));
    expect(find.text('-5,000'), findsOneWidget);
  });

  testWidgets('빠른 추가는 오늘 날짜로 연다', (tester) async {
    await _pumpApp(tester, []);
    await tester.tap(find.byTooltip('기록 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('날짜 · 구성원 · 메모'));
    await tester.pumpAndSettle();
    expect(find.text(SeoulDate.display(SeoulDate.today())), findsOneWidget);
  });

  testWidgets('360px에서 큰 금액과 6주 달력이 넘치지 않는다', (tester) async {
    await _pumpApp(
      tester,
      [
        _item('a', 2147483647, CategoryType.expense, DateTime(2026, 8, 1)),
        _item('b', 2147483647, CategoryType.income, DateTime(2026, 8, 1)),
        _item('c', 2147483647, CategoryType.expense, DateTime(2026, 8, 31)),
      ],
      budgets: {DateTime(2026, 8): 2147483647},
      size: const Size(360, 740),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('-2,147,483,647'), findsNWidgets(2));
    await tester.scrollUntilVisible(find.text('31'), 200);
    expect(tester.takeException(), isNull);
  });
}
