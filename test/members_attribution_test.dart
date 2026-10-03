import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naroo/app/app.dart';
import 'package:naroo/app/router.dart';
import 'package:naroo/core/household_member_changes.dart';
import 'package:naroo/core/seoul_date.dart';
import 'package:naroo/core/session/app_session.dart';
import 'package:naroo/data/models/category.dart';
import 'package:naroo/data/models/household_member.dart';
import 'package:naroo/data/models/profile.dart';
import 'package:naroo/data/models/transaction.dart';
import 'package:naroo/data/repository_providers.dart';
import 'package:naroo/features/home/home_summary.dart';
import 'package:naroo/features/home/home_controller.dart';
import 'package:naroo/features/settings/settings_controller.dart';
import 'package:naroo/features/transaction/transaction_editor_controller.dart';

import 'fake_category_repository.dart';
import 'fake_household_member_repository.dart';
import 'fake_transaction_repository.dart';

const _me = HouseholdMember(
  id: 'me',
  householdId: 'h',
  userId: 'u',
  displayName: '사용자',
);
const _custom = HouseholdMember(
  id: 'custom',
  householdId: 'h',
  userId: null,
  displayName: '나루',
);
const _hidden = HouseholdMember(
  id: 'hidden',
  householdId: 'h',
  userId: null,
  displayName: '숨긴 구성원',
  isHidden: true,
);

void main() {
  test('구성원/공용과 숨김 여부는 전체 합계·예산 계산에 영향을 주지 않는다', () {
    final items = [
      for (final kind in AttributionKind.values)
        for (final type in CategoryType.values)
          TransactionListItem(
            transaction: Transaction(
              id: '${kind.name}-${type.name}',
              householdId: 'h',
              memberId: kind == AttributionKind.shared ? null : 'hidden',
              attributionKind: kind,
              type: type,
              amount: type == CategoryType.income ? 500 : 100,
              categoryId: type.name,
              occurredOn: DateTime(2026, 12, 31),
            ),
            categoryName: '분류',
          ),
    ];
    final summary = HomeSummary(
      month: DateTime(2026, 12),
      budget: 1000,
      items: items,
    );
    expect(summary.income, 1000);
    expect(summary.expense, 200);
    expect(summary.balance, 800);
    expect(summary.remaining, 800);
  });

  for (final type in CategoryType.values) {
    testWidgets('${type.name} 입력에서 공용을 선택해 저장한다', (tester) async {
      final transactions = FakeTransactionRepository();
      final container = await _pump(tester, transactions: transactions);
      container.read(appRouterProvider).push('/transactions/new');
      await tester.pumpAndSettle();
      if (type == CategoryType.income) {
        await tester.tap(find.text('수입'));
        await tester.pumpAndSettle();
      }
      await tester.enterText(find.byType(TextField).first, '100');
      await tester.tap(find.text(type == CategoryType.income ? '급여' : '식비'));
      await tester.tap(find.text('날짜 · 구성원 · 메모'));
      await tester.pumpAndSettle();
      final dropdown = tester.widget<DropdownMenu<String>>(
        find.byType(DropdownMenu<String>),
      );
      expect(dropdown.dropdownMenuEntries.map((entry) => entry.value), [
        'shared',
        'me',
        'custom',
      ]);
      await tester.ensureVisible(find.byType(DropdownMenu<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownMenu<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('공용').hitTestable().last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(transactions.created.single.memberId, isNull);
      expect(
        transactions.created.single.attributionKind,
        AttributionKind.shared,
      );
      expect(transactions.created.single.type, type);
    });
  }

  for (final shared in [true, false]) {
    testWidgets('${shared ? '공용' : '숨긴 구성원'} 기존 기록의 귀속을 유지하고 전환한다', (
      tester,
    ) async {
      final transactions = FakeTransactionRepository([
        TransactionListItem(
          transaction: Transaction(
            id: 'tx',
            householdId: 'h',
            memberId: shared ? null : 'hidden',
            attributionKind: shared
                ? AttributionKind.shared
                : AttributionKind.member,
            type: CategoryType.expense,
            amount: 100,
            categoryId: 'expense',
            occurredOn: SeoulDate.today(),
          ),
          categoryName: '식비',
        ),
      ]);
      final container = await _pump(tester, transactions: transactions);
      container.read(appRouterProvider).push('/transactions/tx/edit');
      await tester.pumpAndSettle();
      final dropdown = tester.widget<DropdownMenu<String>>(
        find.byType(DropdownMenu<String>),
      );
      expect(dropdown.initialSelection, shared ? 'shared' : 'hidden');
      expect(
        dropdown.dropdownMenuEntries.any((entry) => entry.value == 'hidden'),
        !shared,
      );
      await tester.tap(find.text('수정 저장'));
      await tester.pumpAndSettle();
      expect(
        (await transactions.findById('tx'))!.memberId,
        shared ? null : 'hidden',
      );
      container.read(appRouterProvider).push('/transactions/tx/edit');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(DropdownMenu<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownMenu<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(shared ? '나루' : '공용').hitTestable().last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('수정 저장'));
      await tester.pumpAndSettle();
      final changed = (await transactions.findById('tx'))!;
      expect(
        changed.attributionKind,
        shared ? AttributionKind.member : AttributionKind.shared,
      );
      expect(changed.memberId, shared ? 'custom' : null);
    });
  }

  testWidgets('구성원 추가·이름 변경·숨김·복원, 실패 시 입력 보존', (tester) async {
    final members = FakeHouseholdMemberRepository([_me]);
    await _pump(tester, members: members);
    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('사용자 관리'), findsNothing);
    await tester.tap(find.text('구성원 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  ');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(members.writes, 0);
    expect(find.text('이름을 입력해 주세요.'), findsOneWidget);
    members.writeError = StateError('private error');
    await tester.enterText(find.byType(TextField), ' 나루 ');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      ' 나루 ',
    );
    expect(find.textContaining('private error'), findsNothing);
    members.writeError = null;
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('나루'), findsOneWidget);
    await tester.tap(find.byTooltip('나루 관리'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이름 변경'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '나루 새 이름');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    for (final action in ['숨김', '복원']) {
      await tester.tap(find.byTooltip('나루 새 이름 관리'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
      expect(
        (await members.listByHousehold('h')).last.isHidden,
        action == '숨김',
      );
    }
  });

  testWidgets('구성원 저장 중 화면을 닫아도 중복 쓰기를 막고 변경을 알린다', (tester) async {
    final members = FakeHouseholdMemberRepository([_me])
      ..delay = const Duration(milliseconds: 300);
    final container = await _pump(tester, members: members);
    final subscription = container.listen(
      transactionMembersProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    await container.read(transactionMembersProvider.future);
    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('구성원 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '나루');
    await tester.tap(find.text('저장'));
    await tester.pump();
    expect(
      await container.read(memberEditorProvider.notifier).saveName(name: '중복'),
      isFalse,
    );
    Navigator.of(tester.element(find.byType(TextField))).pop();
    await tester.pumpAndSettle();
    expect(members.writes, 1);
    expect(container.read(householdMemberChangesProvider), 1);
    expect(
      (await container.read(transactionMembersProvider.future))
          .map((m) => m.displayName),
      ['사용자', '나루'],
    );
  });
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  FakeTransactionRepository? transactions,
  FakeHouseholdMemberRepository? members,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      appSessionProvider.overrideWith(_Session.new),
      homeMonthProvider.overrideWith((ref) => SeoulDate.monthStart()),
      householdMemberRepositoryProvider.overrideWithValue(
        members ?? FakeHouseholdMemberRepository([_me, _custom, _hidden]),
      ),
      transactionRepositoryProvider.overrideWithValue(
        transactions ?? FakeTransactionRepository(),
      ),
      categoryRepositoryProvider.overrideWithValue(
        FakeCategoryRepository([
          for (final type in CategoryType.values)
            Category(
              id: type.name,
              householdId: 'h',
              type: type,
              name: type == CategoryType.income ? '급여' : '식비',
            ),
        ]),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const NarooApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

class _Session extends AppSessionNotifier {
  @override
  Future<AppSession> build() async => const AppSession.ready(
    userId: 'u',
    email: 'u@example.com',
    profile: Profile(id: 'u', displayName: '사용자'),
    member: _me,
  );
}
