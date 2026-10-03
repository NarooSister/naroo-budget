import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:naroo/app/app.dart';
import 'package:naroo/core/selected_month.dart';
import 'package:naroo/core/session/app_session.dart';
import 'package:naroo/data/models/category.dart';
import 'package:naroo/data/models/household_member.dart';
import 'package:naroo/data/models/payment_method.dart';
import 'package:naroo/data/models/profile.dart';
import 'package:naroo/data/models/transaction.dart';
import 'package:naroo/data/repository_providers.dart';
import 'package:naroo/features/statistics/statistics_summary.dart';

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
const _partner = HouseholdMember(
  id: 'member-2',
  householdId: 'household-1',
  userId: null,
  displayName: '하루',
  isHidden: true,
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
  int amount, {
  CategoryType type = CategoryType.expense,
  String categoryId = 'food',
  String categoryName = '식비',
  String? subcategoryName,
  HouseholdMember? member = _member,
  PaymentMethod? paymentMethod,
  DateTime? date,
}) => TransactionListItem(
  transaction: Transaction(
    id: id,
    householdId: 'household-1',
    memberId: member?.id,
    attributionKind: member == null
        ? AttributionKind.shared
        : AttributionKind.member,
    type: type,
    amount: amount,
    categoryId: categoryId,
    paymentMethod: paymentMethod,
    occurredOn: date ?? DateTime(2026, 8, 3),
  ),
  categoryName: categoryName,
  subcategoryName: subcategoryName,
  memberName: member?.displayName,
);

final _seed = [
  _item('a', 12000, paymentMethod: PaymentMethod.creditCard),
  _item('b', 3000, subcategoryName: '장보기', member: null),
  _item(
    'c',
    5000,
    categoryId: 'bus',
    categoryName: '교통',
    member: _partner,
    paymentMethod: PaymentMethod.cash,
    date: DateTime(2026, 8, 31),
  ),
  _item(
    'd',
    2500000,
    type: CategoryType.income,
    categoryId: 'salary',
    categoryName: '월급',
    date: DateTime(2026, 8, 1),
  ),
  _item('e', 7000, date: DateTime(2026, 7, 31)),
];

Future<FakeTransactionRepository> _pumpApp(
  WidgetTester tester, {
  List<TransactionListItem>? seed,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final transactions = FakeTransactionRepository(seed ?? _seed);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appSessionProvider.overrideWith(_Session.new),
        currentMonthProvider.overrideWith((ref) => DateTime(2026, 8)),
        monthlyBudgetRepositoryProvider.overrideWithValue(
          FakeMonthlyBudgetRepository({}),
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
              id: 'bus',
              householdId: 'household-1',
              type: CategoryType.expense,
              name: '교통',
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
          FakeHouseholdMemberRepository([_member, _partner]),
        ),
        transactionRepositoryProvider.overrideWithValue(transactions),
      ],
      child: const NarooApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(NavigationDestination, '통계'));
  await tester.pumpAndSettle();
  return transactions;
}

void main() {
  group('StatisticsSummary', () {
    test('ID로 묶고 금액·이름·ID 순으로 정렬해 색을 배정한다', () {
      final summary = StatisticsSummary(
        month: DateTime(2026, 8),
        items: [
          _item('a', 100, categoryId: 'x2', categoryName: '같은 이름'),
          _item('b', 100, categoryId: 'x1', categoryName: '같은 이름'),
          _item('c', 300, categoryId: 'z', categoryName: '가'),
          _item('d', 1, categoryId: 'y', categoryName: '작은 항목'),
          _item('e', 9, type: CategoryType.income, categoryId: 'salary'),
        ],
      );
      final slices = summary.slices(
        StatisticsGroup.category,
        CategoryType.expense,
      );
      expect([for (final s in slices) s.key], ['z', 'x1', 'x2', 'y']);
      expect(summary.total(CategoryType.expense), 501);
      expect(
        slices.fold(0, (t, s) => t + s.amount),
        summary.total(CategoryType.expense),
      );
      expect(slices.first.percentOf(501), '60%');
      expect(slices.last.percentOf(501), '<1%');
      expect(slices[0].color, isNot(slices[1].color));
    });

    test('공용·숨긴 구성원·결제 수단 미지정을 따로 묶는다', () {
      final summary = StatisticsSummary(month: DateTime(2026, 8), items: _seed);
      final members = summary.slices(
        StatisticsGroup.member,
        CategoryType.expense,
      );
      expect(
        [for (final s in members) (s.label, s.amount)],
        [('나루', 19000), ('하루', 5000), ('공용', 3000)],
      );
      final methods = summary.slices(
        StatisticsGroup.paymentMethod,
        CategoryType.expense,
      );
      expect(
        [for (final s in methods) (s.label, s.amount)],
        [('신용카드', 12000), ('미지정', 10000), ('현금', 5000)],
      );
      expect(StatisticsGroup.forType(CategoryType.income), [
        StatisticsGroup.category,
        StatisticsGroup.member,
      ]);
    });
  });

  testWidgets('통계 탭은 선택 월 지출을 카테고리·구성원·결제 수단 원그래프로 보여준다', (tester) async {
    await _pumpApp(tester);

    expect(find.text('2026년 8월'), findsOneWidget);
    expect(
      find.bySemanticsLabel('지출 카테고리별 원그래프, 식비 15,000원 75%, 교통 5,000원 25%'),
      findsOneWidget,
    );
    expect(find.text('20,000원'), findsWidgets, reason: '차트 가운데 총액');

    await tester.scrollUntilVisible(find.text('지출 결제 수단별'), 300);
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(
        '지출 구성원별 원그래프, 나루 12,000원 60%, 하루 5,000원 25%, 공용 3,000원 15%',
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('미지정'), 300);
    expect(
      find.bySemanticsLabel(
        '지출 결제 수단별 원그래프, 신용카드 12,000원 60%, 현금 5,000원 25%, 미지정 3,000원 15%',
      ),
      findsOneWidget,
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('수입'));
    await tester.pumpAndSettle();
    expect(find.text('수입 카테고리별'), findsOneWidget);
    expect(find.text('수입 구성원별'), findsOneWidget);
    expect(find.textContaining('결제 수단별'), findsNothing);
    expect(
      find.bySemanticsLabel('수입 카테고리별 원그래프, 월급 2,500,000원 100%'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('이전 달'));
    await tester.pumpAndSettle();
    expect(find.text('이 달 수입이 없어요.'), findsOneWidget);
    await tester.tap(find.text('지출'));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('지출 카테고리별 원그래프, 식비 7,000원 100%'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(NavigationDestination, '홈'));
    await tester.pumpAndSettle();
    expect(find.text('2026년 7월'), findsOneWidget, reason: '홈과 같은 월');
  });

  testWidgets('조각과 범례를 누르면 그 항목 기록을 열고 삭제가 통계에 반영된다', (tester) async {
    final transactions = await _pumpApp(tester);

    final chart = find.bySemanticsLabel(RegExp('^지출 카테고리별 원그래프'));
    final box = tester.getRect(chart);
    // Just right of 12 o'clock is the largest slice.
    await tester.tapAt(box.topCenter + Offset(12, box.height * 0.1));
    await tester.pumpAndSettle();
    expect(find.text('식비 · 장보기'), findsOneWidget, reason: '소분류 포함');
    expect(find.text('-12,000원'), findsOneWidget);
    expect(find.text('교통'), findsOneWidget, reason: '시트 뒤 범례만 남는다');
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('공용'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('공용'));
    await tester.pumpAndSettle();
    expect(find.text('-3,000원'), findsOneWidget);
    await tester.tap(find.text('-3,000원'));
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
    expect(transactions.deletedIds, ['b']);
    expect(find.text('이 달 지출이 없어요.'), findsOneWidget);
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    expect(find.text('공용'), findsNothing);
    expect(find.text('17,000원'), findsWidgets);
    expect(find.text('20,000원'), findsNothing);
  });

  testWidgets('360px에서 큰 금액과 긴 이름이 넘치지 않는다', (tester) async {
    await _pumpApp(
      tester,
      size: const Size(360, 740),
      seed: [
        for (final id in ['a', 'b', 'c'])
          _item(
            id,
            2147483647,
            categoryId: id,
            categoryName: '아주 긴 카테고리 이름이 들어가는 경우 $id',
          ),
      ],
    );
    expect(tester.takeException(), isNull);
    expect(find.text('6,442,450,941원'), findsWidgets);
    expect(find.text('33%'), findsWidgets);
    await tester.scrollUntilVisible(find.text('지출 결제 수단별'), 300);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
