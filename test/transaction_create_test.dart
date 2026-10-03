import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:naroo/app/app.dart';
import 'package:naroo/core/seoul_date.dart';
import 'package:naroo/core/session/app_session.dart';
import 'package:naroo/data/models/category.dart';
import 'package:naroo/data/models/household_member.dart';
import 'package:naroo/data/models/profile.dart';
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
const _partner = HouseholdMember(
  id: 'member-2',
  householdId: 'household-1',
  userId: 'user-2',
  displayName: '파트너',
);

void main() {
  test('SeoulDate.today는 연월일만 가진다', () {
    final today = SeoulDate.today();
    expect(today.hour, 0);
    expect(today.minute, 0);
    expect(SeoulDate.format(DateTime(2026, 9, 28)), '2026-09-28');
  });

  testWidgets('홈에서 거래 추가 후 저장하면 기본값으로 생성된다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transactions = FakeTransactionRepository();
    final categories = FakeCategoryRepository([
      const Category(
        id: 'food',
        householdId: 'household-1',
        type: CategoryType.expense,
        name: '식비',
      ),
      const Category(
        id: 'hidden',
        householdId: 'household-1',
        type: CategoryType.expense,
        name: '숨김',
      ),
      const Category(
        id: 'salary',
        householdId: 'household-1',
        type: CategoryType.income,
        name: '월급',
      ),
    ]);
    final members = FakeHouseholdMemberRepository([_member, _partner]);

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
          categoryRepositoryProvider.overrideWithValue(categories),
          householdMemberRepositoryProvider.overrideWithValue(members),
          transactionRepositoryProvider.overrideWithValue(transactions),
        ],
        child: const NarooApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('기록 추가'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, '기록 추가'), findsOneWidget);
    expect(find.text('식비'), findsOneWidget);
    expect(find.text('숨김'), findsOneWidget);
    expect(find.text('월급'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '12000');
    await tester.tap(find.text('식비'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(transactions.createCalls, 1);
    expect(transactions.created.single.amount, 12000);
    expect(transactions.created.single.type, CategoryType.expense);
    expect(transactions.created.single.categoryId, 'food');
    expect(transactions.created.single.memberId, 'member-1');
    expect(find.text('NAROO.'), findsOneWidget);
  });

  testWidgets('저장 중 중복 탭은 한 번만 생성한다', (tester) async {
    final transactions = FakeTransactionRepository()
      ..delay = const Duration(milliseconds: 300);
    final categories = FakeCategoryRepository([
      const Category(
        id: 'food',
        householdId: 'household-1',
        type: CategoryType.expense,
        name: '식비',
      ),
    ]);
    final members = FakeHouseholdMemberRepository([_member]);

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
          categoryRepositoryProvider.overrideWithValue(categories),
          householdMemberRepositoryProvider.overrideWithValue(members),
          transactionRepositoryProvider.overrideWithValue(transactions),
        ],
        child: const NarooApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('기록 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '5000');
    await tester.tap(find.text('식비'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('저장'));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(transactions.createCalls, 1);
  });
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
