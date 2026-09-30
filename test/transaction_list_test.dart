import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:naroo/app/app.dart';
import 'package:naroo/core/money_format.dart';
import 'package:naroo/core/seoul_date.dart';
import 'package:naroo/core/session/app_session.dart';
import 'package:naroo/data/models/category.dart';
import 'package:naroo/data/models/household_member.dart';
import 'package:naroo/data/models/profile.dart';
import 'package:naroo/data/models/transaction.dart';
import 'package:naroo/data/repository_providers.dart';
import 'package:naroo/features/transaction/transaction_list_controller.dart';

import 'fake_category_repository.dart';
import 'fake_household_member_repository.dart';
import 'fake_transaction_repository.dart';

const _profile = Profile(id: 'user-1', displayName: '테스트 사용자');
const _member = HouseholdMember(
  id: 'member-1',
  householdId: 'household-1',
  userId: 'user-1',
  displayName: '테스트 사용자',
);

void main() {
  test('금액 포맷과 월 이동이 동작한다', () {
    expect(MoneyFormat.signed(CategoryType.expense, 12000), '-12,000');
    expect(MoneyFormat.signed(CategoryType.income, 3500000), '+3,500,000');

    final month = DateTime(2026, 1);
    expect(SeoulDate.previousMonth(month), DateTime(2025, 12));
    expect(SeoulDate.nextMonth(DateTime(2025, 12)), DateTime(2026, 1));
  });

  test('날짜별 그룹과 오늘 라벨이 동작한다', () {
    final today = DateTime(2026, 9, 28);
    final items = [
      TransactionListItem(
        transaction: Transaction(
          id: '1',
          householdId: 'h1',
          memberId: 'm1',
          type: CategoryType.expense,
          amount: 12000,
          categoryId: 'c1',
          occurredOn: today,
          memo: '점심',
        ),
        categoryName: '식비',
      ),
      TransactionListItem(
        transaction: Transaction(
          id: '2',
          householdId: 'h1',
          memberId: 'm1',
          type: CategoryType.expense,
          amount: 5500,
          categoryId: 'c2',
          occurredOn: DateTime(2026, 9, 27),
        ),
        categoryName: '카페/간식',
      ),
    ];

    final groups = groupTransactionsByDate(items, today: today);
    expect(groups, hasLength(2));
    expect(groups.first.label, '오늘');
    expect(groups.first.items.single.title, '점심');
    expect(groups.last.label, '9월 27일');
    expect(groups.last.items.single.title, '카페/간식');
  });

  testWidgets('내역에서 월/필터/수정 진입이 동작한다', (tester) async {
    final transactions = FakeTransactionRepository([
      TransactionListItem(
        transaction: Transaction(
          id: 'tx-1',
          householdId: 'household-1',
          memberId: 'member-1',
          type: CategoryType.expense,
          amount: 12000,
          categoryId: 'food',
          occurredOn: DateTime(2026, 9, 28),
          memo: '점심',
        ),
        categoryName: '식비',
        memberName: '테스트 사용자',
      ),
      TransactionListItem(
        transaction: Transaction(
          id: 'tx-2',
          householdId: 'household-1',
          memberId: 'member-1',
          type: CategoryType.income,
          amount: 3500000,
          categoryId: 'salary',
          occurredOn: DateTime(2026, 9, 27),
        ),
        categoryName: '월급',
      ),
      TransactionListItem(
        transaction: Transaction(
          id: 'tx-3',
          householdId: 'household-1',
          memberId: 'member-1',
          type: CategoryType.expense,
          amount: 8000,
          categoryId: 'food',
          occurredOn: DateTime(2026, 8, 15),
        ),
        categoryName: '식비',
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith(
            () => _FakeAppSessionNotifier(
              const AppSession.ready(
                userId: 'user-1',
                email: 'user@example.com',
                profile: _profile,
                member: _member,
              ),
            ),
          ),
          transactionListMonthProvider.overrideWith(_September2026Month.new),
          categoryRepositoryProvider.overrideWithValue(
            FakeCategoryRepository([
              const Category(
                id: 'food',
                householdId: 'household-1',
                type: CategoryType.expense,
                name: '식비',
                isDefault: true,
                isHidden: false,
              ),
              const Category(
                id: 'salary',
                householdId: 'household-1',
                type: CategoryType.income,
                name: '월급',
                isDefault: true,
                isHidden: false,
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

    await tester.tap(find.widgetWithText(NavigationDestination, '내역'));
    await tester.pumpAndSettle();

    expect(find.text('2026년 9월'), findsOneWidget);
    expect(find.text('점심'), findsOneWidget);
    expect(find.text('-12,000'), findsOneWidget);
    expect(find.text('월급'), findsOneWidget);
    expect(find.text('+3,500,000'), findsOneWidget);
    expect(find.text('식비'), findsNothing);

    await tester.tap(find.text('지출'));
    await tester.pumpAndSettle();
    expect(find.text('점심'), findsOneWidget);
    expect(find.text('월급'), findsNothing);

    await tester.tap(find.byTooltip('이전 달'));
    await tester.pumpAndSettle();
    expect(find.text('2026년 8월'), findsOneWidget);
    expect(find.text('-8,000'), findsOneWidget);

    await tester.tap(find.byTooltip('다음 달'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('점심'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, '기록 수정'), findsOneWidget);
    expect(find.text('12000'), findsOneWidget);
  });
}

class _September2026Month extends TransactionListMonth {
  @override
  DateTime build() => DateTime(2026, 9);
}

class _FakeAppSessionNotifier extends AppSessionNotifier {
  _FakeAppSessionNotifier(this._session);

  final AppSession _session;

  @override
  Future<AppSession> build() async => _session;

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async {}
}
