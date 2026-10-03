import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:naroo/app/app.dart';
import 'package:naroo/core/selected_month.dart';
import 'package:naroo/core/session/app_session.dart';
import 'package:naroo/data/models/category.dart';
import 'package:naroo/data/models/household_member.dart';
import 'package:naroo/data/models/profile.dart';
import 'package:naroo/data/models/transaction.dart';
import 'package:naroo/data/repository_providers.dart';

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
  testWidgets('수정 저장 후 내역 목록이 갱신된다', (tester) async {
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
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(transactions),
        child: const NarooApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, '내역'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('점심'));
    await tester.pumpAndSettle();
    expect(find.text('-12,000원'), findsOneWidget);
    expect(find.text('2026년 9월 28일'), findsOneWidget);
    expect(find.text('체크카드'), findsNothing);
    expect(find.text('미지정'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '수정'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, '기록 수정'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '15000');
    await tester.tap(find.widgetWithText(FilledButton, '수정 저장'));
    await tester.pumpAndSettle();

    expect(transactions.updateCalls, 1);
    expect(find.text('-15,000'), findsOneWidget);
    expect(find.widgetWithText(AppBar, '내역'), findsOneWidget);
  });

  testWidgets('삭제 확인 후 내역에서 제거된다', (tester) async {
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
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(transactions),
        child: const NarooApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, '내역'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('점심'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await tester.pumpAndSettle();

    expect(find.text('기록을 삭제할까요?'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, '삭제'),
      ),
    );
    await tester.pumpAndSettle();

    expect(transactions.deleteCalls, 1);
    expect(transactions.deletedIds, ['tx-1']);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('아직 기록이 없어요.'), findsOneWidget);
    expect(find.textContaining('점심'), findsNothing);
  });

  testWidgets('수정 화면에서도 삭제할 수 있다', (tester) async {
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
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(transactions),
        child: const NarooApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, '내역'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('점심'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '수정'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('삭제'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, '삭제'),
      ),
    );
    await tester.pumpAndSettle();

    expect(transactions.deletedIds, ['tx-1']);
    expect(find.widgetWithText(AppBar, '내역'), findsOneWidget);
    expect(find.text('아직 기록이 없어요.'), findsOneWidget);
  });

  testWidgets('삭제 확인에서 취소하면 삭제되지 않는다', (tester) async {
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
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(transactions),
        child: const NarooApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, '내역'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('점심'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(transactions.deleteCalls, 0);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('-12,000원'), findsOneWidget);
  });
}

List<Override> _overrides(FakeTransactionRepository transactions) {
  return [
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
    currentMonthProvider.overrideWith((ref) => DateTime(2026, 9)),
    categoryRepositoryProvider.overrideWithValue(
      FakeCategoryRepository([
        const Category(
          id: 'food',
          householdId: 'household-1',
          type: CategoryType.expense,
          name: '식비',
        ),
      ]),
    ),
    householdMemberRepositoryProvider.overrideWithValue(
      FakeHouseholdMemberRepository([_member]),
    ),
    transactionRepositoryProvider.overrideWithValue(transactions),
  ];
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
