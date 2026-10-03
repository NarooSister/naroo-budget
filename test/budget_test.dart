import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:naroo/app/app.dart';
import 'package:naroo/core/selected_month.dart';
import 'package:naroo/core/session/app_session.dart';
import 'package:naroo/data/models/category.dart';
import 'package:naroo/data/models/household_member.dart';
import 'package:naroo/data/models/monthly_budget.dart';
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

const _categories = [
  Category(
    id: 'food',
    householdId: 'household-1',
    type: CategoryType.expense,
    name: '식비',
  ),
  Category(
    id: 'grocery',
    householdId: 'household-1',
    type: CategoryType.expense,
    name: '장보기',
    parentId: 'food',
  ),
  Category(
    id: 'bus',
    householdId: 'household-1',
    type: CategoryType.expense,
    name: '교통',
  ),
  Category(
    id: 'unc',
    householdId: 'household-1',
    type: CategoryType.expense,
    name: '미분류',
    isUncategorized: true,
  ),
  Category(
    id: 'salary',
    householdId: 'household-1',
    type: CategoryType.income,
    name: '월급',
  ),
];

TransactionListItem _item(
  String id,
  int amount,
  String categoryId, {
  CategoryType type = CategoryType.expense,
  String? subcategoryId,
  String? subcategoryName,
}) => TransactionListItem(
  transaction: Transaction(
    id: id,
    householdId: 'household-1',
    memberId: 'member-1',
    type: type,
    amount: amount,
    categoryId: categoryId,
    subcategoryId: subcategoryId,
    occurredOn: DateTime(2026, 8, 5),
  ),
  categoryName: _categories.firstWhere((c) => c.id == categoryId).name,
  subcategoryName: subcategoryName,
  memberName: '나루',
);

final _august = DateTime(2026, 8);
final _july = DateTime(2026, 7);

Future<void> _pumpApp(
  WidgetTester tester,
  FakeMonthlyBudgetRepository budgets,
) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appSessionProvider.overrideWith(_Session.new),
        currentMonthProvider.overrideWith((ref) => _august),
        monthlyBudgetRepositoryProvider.overrideWithValue(budgets),
        categoryRepositoryProvider.overrideWithValue(
          FakeCategoryRepository(_categories),
        ),
        householdMemberRepositoryProvider.overrideWithValue(
          FakeHouseholdMemberRepository([_member]),
        ),
        transactionRepositoryProvider.overrideWithValue(
          FakeTransactionRepository([
            _item('a', 12000, 'food'),
            _item(
              'b',
              3000,
              'food',
              subcategoryId: 'grocery',
              subcategoryName: '장보기',
            ),
            _item('c', 2000, 'bus'),
            _item('d', 100000, 'salary', type: CategoryType.income),
          ]),
        ),
      ],
      child: const NarooApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _allocation(String categoryId) =>
    find.byKey(ValueKey('allocation-$categoryId'));
final _total = find.widgetWithText(TextField, '총예산');

String _text(WidgetTester tester, Finder field) =>
    tester.widget<TextField>(field).controller!.text;

void main() {
  testWidgets('지난달 예산을 불러와 배분 후 저장하고 예산 페이지에서 카테고리 지출을 본다', (tester) async {
    final budgets = FakeMonthlyBudgetRepository({
      _july: FakeMonthlyBudgetRepository.budget(500000, {'food': 300000}),
    });
    await _pumpApp(tester, budgets);

    expect(find.text('아직 예산이 없어요.'), findsOneWidget);
    await tester.tap(find.text('예산 설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('지난달 예산 불러오기'));
    await tester.pumpAndSettle();
    expect(_text(tester, _total), '500000');
    expect(_text(tester, _allocation('food')), '300000');
    expect(_text(tester, _allocation('bus')), '');
    expect(_allocation('grocery'), findsNothing, reason: '소분류는 배분 대상이 아니다');
    expect(_allocation('unc'), findsNothing);
    expect(_allocation('salary'), findsNothing);
    expect(find.text('미배분 200,000원'), findsOneWidget);
    expect(budgets.writes, 0, reason: '불러오기는 저장 전까지 반영하지 않는다');

    await tester.enterText(_allocation('bus'), '250000');
    await tester.pumpAndSettle();
    expect(find.text('50,000원 초과'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();
    expect(find.text('배분 합계가 총예산을 넘습니다. 배분이나 총예산을 조정해 주세요.'), findsOneWidget);
    expect(budgets.writes, 0);

    await tester.enterText(_allocation('bus'), '');
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();
    expect(budgets.budgets[_august]!.amount, 500000);
    expect(budgets.budgets[_august]!.allocations, {
      'food': 300000,
    }, reason: '빈칸은 배분 없음');
    expect(budgets.budgets[_july]!.version, 'seed', reason: '다른 달은 그대로');

    expect(find.text('17,000 / 500,000원'), findsOneWidget);
    expect(find.text('483,000원 남음'), findsOneWidget);
    await tester.tap(find.text('예산'));
    await tester.pumpAndSettle();
    expect(find.text('총예산 500,000원'), findsOneWidget);
    expect(find.text('미배분 200,000원'), findsOneWidget);
    expect(find.text('15,000 / 300,000원'), findsOneWidget, reason: '소분류 지출 포함');
    expect(find.text('285,000원 남음'), findsOneWidget);
    expect(find.text('교통'), findsNothing, reason: '배분 없는 카테고리는 표시하지 않는다');

    await tester.tap(find.text('식비'));
    await tester.pumpAndSettle();
    expect(find.text('-12,000원'), findsOneWidget);
    expect(find.text('-3,000원'), findsOneWidget);
    expect(find.text('식비 · 장보기'), findsOneWidget);
    expect(find.text('-2,000원'), findsNothing);
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('이전 달'));
    await tester.pumpAndSettle();
    expect(find.text('2026년 7월'), findsOneWidget);
    expect(find.text('0 / 300,000원'), findsOneWidget);
    await tester.tap(find.byTooltip('다음 달'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('다음 달'));
    await tester.pumpAndSettle();
    expect(find.text('이 달 예산이 없어요.'), findsOneWidget);
    await tester.tap(find.byTooltip('이전 달'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('예산 수정'));
    await tester.pumpAndSettle();
    expect(find.text('지난달 예산 불러오기'), findsNothing);
    await tester.tap(find.text('예산 초기화'));
    await tester.pumpAndSettle();
    expect(find.text('8월 예산과 카테고리 배분을 모두 지울까요?'), findsOneWidget);
    await tester.tap(find.text('초기화'));
    await tester.pumpAndSettle();
    expect(budgets.budgets[_august], isNull);
    expect(budgets.budgets[_july], isNotNull);
    expect(find.text('이 달 예산이 없어요.'), findsOneWidget);
  });

  testWidgets('다른 사람이 먼저 저장하면 거부하고 다시 불러온 뒤 저장한다', (tester) async {
    final budgets = FakeMonthlyBudgetRepository({
      _august: FakeMonthlyBudgetRepository.budget(100000),
    });
    await _pumpApp(tester, budgets);
    await tester.tap(find.text('예산'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('예산 수정'));
    await tester.pumpAndSettle();
    expect(_text(tester, _total), '100000');

    budgets.budgets[_august] = const MonthlyBudget(
      amount: 150000,
      version: 'partner',
    );
    await tester.enterText(_total, '200000');
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();
    expect(find.text('다른 사람이 먼저 예산을 바꿨어요. 다시 불러온 뒤 저장해 주세요.'), findsOneWidget);
    expect(budgets.budgets[_august]!.amount, 150000);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '저장'))
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('다시 불러오기'));
    await tester.pumpAndSettle();
    expect(_text(tester, _total), '150000');
    await tester.enterText(_total, '200000');
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();
    expect(budgets.budgets[_august]!.amount, 200000);
    expect(find.text('총예산 200,000원'), findsOneWidget);
  });

  testWidgets('예산이 있으면 홈 예산을 눌러 예산 페이지로 간다', (tester) async {
    await _pumpApp(
      tester,
      FakeMonthlyBudgetRepository({
        _august: FakeMonthlyBudgetRepository.budget(10000),
      }),
    );
    expect(find.text('17,000 / 10,000원'), findsOneWidget);
    expect(find.text('7,000원 초과'), findsOneWidget);
    await tester.tap(find.text('17,000 / 10,000원'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '예산'), findsOneWidget);
    expect(find.text('카테고리별 예산이 없어요. 수정에서 배분할 수 있어요.'), findsOneWidget);
  });
}
