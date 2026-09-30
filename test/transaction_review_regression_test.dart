import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:naroo/app/app.dart';
import 'package:naroo/app/theme/naroo_widgets.dart';
import 'package:naroo/core/seoul_date.dart';
import 'package:naroo/core/session/app_session.dart';
import 'package:naroo/data/models/category.dart';
import 'package:naroo/data/models/household_member.dart';
import 'package:naroo/data/models/profile.dart';
import 'package:naroo/data/models/transaction.dart';
import 'package:naroo/data/repository_providers.dart';
import 'package:naroo/features/transaction/transaction_editor_controller.dart';
import 'package:naroo/features/transaction/transaction_list_controller.dart';

import 'fake_category_repository.dart';
import 'fake_household_member_repository.dart';
import 'fake_transaction_repository.dart';

const _member = HouseholdMember(
  id: 'member-1',
  householdId: 'household-1',
  userId: 'user-1',
  displayName: '사용자 A',
);

void main() {
  for (final raw in [
    '',
    '0',
    '12.34',
    '-100',
    '+100',
    '12,34',
    '1e3',
    '2147483648',
    '999999999999999999999999999999',
  ]) {
    testWidgets('잘못된 금액 "$raw"는 원문을 유지하고 저장하지 않는다', (tester) async {
      final repository = FakeTransactionRepository();
      await _pumpApp(tester, repository);
      await tester.tap(find.byTooltip('기록 추가'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, raw);
      await tester.tap(find.text('식비'));
      await tester.tap(find.widgetWithText(FilledButton, '저장'));
      await tester.pumpAndSettle();
      expect(repository.createCalls, 0);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        raw,
      );
      expect(
        find.text(
          raw == '2147483648'
              ? '금액은 2,147,483,647원 이하로 입력해 주세요.'
              : '금액은 0보다 큰 정수로 입력해 주세요.',
        ),
        findsOneWidget,
      );
    });
  }

  for (final (raw, amount) in [('12,000', 12000), ('2147483647', 2147483647)]) {
    testWidgets('허용 금액 $raw 저장', (tester) async {
      final repository = FakeTransactionRepository();
      await _pumpApp(tester, repository);
      await tester.tap(find.byTooltip('기록 추가'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, raw);
      await tester.tap(find.text('식비'));
      await tester.tap(find.widgetWithText(FilledButton, '저장'));
      await tester.pumpAndSettle();
      expect(repository.created.single.amount, amount);
    });
  }

  for (final missing in [false, true]) {
    testWidgets('조회 ${missing ? '대상 없음' : '실패'} 시 쓰기 차단, 재조회 후 복구', (
      tester,
    ) async {
      final repository = FakeTransactionRepository([_item()])
        ..readError = missing ? null : StateError('offline')
        ..missingOnRead = missing;
      await _pumpApp(tester, repository);
      await _openTab(tester, '내역');
      await tester.tap(find.text('기존 기록'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) => widget is IconButton && widget.tooltip == '삭제',
              ),
            )
            .onPressed,
        isNull,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NarooApp)),
      );
      final controller = container.read(
        transactionEditorProvider('existing').notifier,
      );
      expect(
        await controller.save(_input(SeoulDate.today(), memo: '덮어쓰기')),
        isFalse,
      );
      expect(await controller.delete(), isFalse);
      expect(repository.updateCalls, 0);
      expect(repository.deleteCalls, 0);

      repository.readError = null;
      repository.missingOnRead = false;
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(find.text('12000'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '12.34');
      await tester.tap(find.widgetWithText(FilledButton, '수정 저장'));
      await tester.pumpAndSettle();
      expect(repository.updateCalls, 0);
      await tester.enterText(find.byType(TextField).first, '15,000');
      await tester.tap(find.widgetWithText(FilledButton, '수정 저장'));
      await tester.pumpAndSettle();
      expect(repository.updateCalls, 1);
      expect((await repository.findById('existing'))!.amount, 15000);
    });
  }

  for (final change in ['create', 'update', 'delete']) {
    testWidgets('내역 재진입은 외부 $change 반영 후 월과 필터를 유지한다', (tester) async {
      final previousMonth = SeoulDate.previousMonth(SeoulDate.monthStart());
      final repository = FakeTransactionRepository([
        _item(date: previousMonth),
      ]);
      await _pumpApp(tester, repository);
      await _openTab(tester, '내역');
      await tester.tap(find.byTooltip('이전 달'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('지출'));
      await tester.pumpAndSettle();
      expect(find.text('기존 기록'), findsOneWidget);
      await _openTab(tester, '홈');

      // Change the fake server directly, without invalidating any app provider.
      switch (change) {
        case 'create':
          await repository.create(_input(previousMonth, memo: '상대방 추가'));
        case 'update':
          await repository.update(
            transactionId: 'existing',
            input: _input(previousMonth, memo: '상대방 수정'),
          );
        case 'delete':
          await repository.delete('existing');
      }
      final callsBeforeReturn = repository.listCalls;
      await _openTab(tester, '내역');

      expect(repository.listCalls, greaterThan(callsBeforeReturn));
      expect(find.text(SeoulDate.monthLabel(previousMonth)), findsOneWidget);
      final filter = tester.widget<SegmentedButton<TransactionListFilter>>(
        find.byType(SegmentedButton<TransactionListFilter>),
      );
      expect(filter.selected, {TransactionListFilter.expense});
      expect(
        find.text(change == 'create' ? '상대방 추가' : '상대방 수정'),
        change == 'delete' ? findsNothing : findsOneWidget,
      );
      if (change == 'delete') {
        expect(find.text('아직 기록이 없어요.'), findsOneWidget);
      }
    });
  }

  for (final action in ['create', 'update', 'delete']) {
    testWidgets('$action 중 화면을 나가도 완료 후 목록을 갱신한다', (tester) async {
      final repository = FakeTransactionRepository([_item()]);
      await _pumpApp(tester, repository);
      await _openTab(tester, '내역');
      if (action == 'create') {
        await _openTab(tester, '홈');
        await tester.tap(find.byTooltip('기록 추가'));
      } else {
        await tester.tap(find.text('기존 기록'));
      }
      await tester.pumpAndSettle();
      repository.delay = const Duration(seconds: 3);

      if (action == 'delete') {
        await tester.tap(find.byTooltip('삭제'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, '삭제'));
      } else {
        await tester.enterText(find.byType(TextField).first, '15000');
        if (action == 'create') {
          await tester.tap(find.text('식비'));
        }
        await tester.tap(
          find.widgetWithText(
            FilledButton,
            action == 'create' ? '저장' : '수정 저장',
          ),
        );
      }
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      if (action == 'create') {
        await _openTab(tester, '내역');
      }
      // The request is still in flight, and the editor has been disposed.
      expect(find.text('-15,000'), findsNothing);
      final callsBeforeCompletion = repository.listCalls;
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(repository.listCalls, greaterThan(callsBeforeCompletion));
      if (action == 'delete') {
        expect(find.text('기존 기록'), findsNothing);
        expect(repository.deleteCalls, 1);
      } else {
        expect(find.text('-15,000'), findsOneWidget);
        expect(
          action == 'create' ? repository.createCalls : repository.updateCalls,
          1,
        );
      }
    });
  }

  testWidgets('수정 중 같은 거래에 재진입해도 중복 저장 없이 완료된 값을 불러온다', (tester) async {
    final repository = FakeTransactionRepository([_item()]);
    await _pumpApp(tester, repository);
    await _openTab(tester, '내역');
    await tester.tap(find.text('기존 기록'));
    await tester.pumpAndSettle();
    repository.delay = const Duration(seconds: 3);
    await tester.enterText(find.byType(TextField).first, '15000');
    await tester.tap(find.widgetWithText(FilledButton, '수정 저장'));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('기존 기록'));
    await tester.pump(const Duration(milliseconds: 400));

    // Loading this editor again must not unlock the save button.
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('15000'), findsOneWidget);
    expect(repository.updateCalls, 1);
    expect(tester.takeException(), isNull);
  });

  for (final categoryId in ['food', 'old-hidden']) {
    testWidgets('수정 시 기존 $categoryId 외의 숨김 카테고리는 선택할 수 없다', (tester) async {
      final repository = FakeTransactionRepository([
        _item(categoryId: categoryId),
      ]);
      await _pumpApp(tester, repository);
      await _openTab(tester, '내역');
      await tester.tap(find.text('기존 기록'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(NarooCategoryChip, '식비'), findsOneWidget);
      expect(
        find.widgetWithText(NarooCategoryChip, '기존 숨김'),
        categoryId == 'old-hidden' ? findsOneWidget : findsNothing,
      );
      expect(find.widgetWithText(NarooCategoryChip, '다른 숨김'), findsNothing);
      expect(find.widgetWithText(NarooCategoryChip, '월급'), findsNothing);

      await tester.tap(find.text('수입'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(NarooCategoryChip, '월급'), findsOneWidget);
      expect(find.widgetWithText(NarooCategoryChip, '기존 숨김'), findsNothing);
      expect(find.widgetWithText(NarooCategoryChip, '숨긴 수입'), findsNothing);
      await tester.tap(find.text('지출'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(
          NarooCategoryChip,
          categoryId == 'old-hidden' ? '기존 숨김' : '식비',
        ),
      );
      await tester.tap(find.widgetWithText(FilledButton, '수정 저장'));
      await tester.pumpAndSettle();
      expect((await repository.findById('existing'))?.categoryId, categoryId);
      expect(repository.updateCalls, 1);
    });
  }

  testWidgets('저장 실패 후 입력을 유지하고 다시 저장할 수 있다', (tester) async {
    final repository = FakeTransactionRepository()
      ..writeError = StateError('simulated network failure');
    await _pumpApp(tester, repository);
    await tester.tap(find.byTooltip('기록 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '15000');
    await tester.tap(find.text('식비'));
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();
    expect(find.text('기록을 저장하지 못했습니다.'), findsOneWidget);
    expect(find.text('15000'), findsOneWidget);

    repository.writeError = null;
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();
    expect(repository.createCalls, 2);
    expect(repository.created, hasLength(1));
    expect(find.text('NAROO.'), findsOneWidget);
  });
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(NavigationDestination, label));
  await tester.pumpAndSettle();
}

TransactionListItem _item({DateTime? date, String categoryId = 'food'}) {
  return TransactionListItem(
    transaction: Transaction(
      id: 'existing',
      householdId: _member.householdId,
      memberId: _member.id,
      type: CategoryType.expense,
      amount: 12000,
      categoryId: categoryId,
      occurredOn: date ?? SeoulDate.today(),
      memo: '기존 기록',
    ),
    categoryName: '식비',
  );
}

NewTransaction _input(DateTime date, {required String memo}) => NewTransaction(
  householdId: _member.householdId,
  memberId: _member.id,
  type: CategoryType.expense,
  amount: 15000,
  categoryId: 'food',
  occurredOn: date,
  memo: memo,
);

Future<void> _pumpApp(
  WidgetTester tester,
  FakeTransactionRepository repository,
) async {
  final categories = [
    ('food', '식비', CategoryType.expense, false),
    ('old-hidden', '기존 숨김', CategoryType.expense, true),
    ('other-hidden', '다른 숨김', CategoryType.expense, true),
    ('salary', '월급', CategoryType.income, false),
    ('hidden-income', '숨긴 수입', CategoryType.income, true),
  ];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appSessionProvider.overrideWith(_ReadySession.new),
        categoryRepositoryProvider.overrideWithValue(
          FakeCategoryRepository([
            for (final (id, name, type, hidden) in categories)
              Category(
                id: id,
                householdId: _member.householdId,
                type: type,
                name: name,
                isDefault: false,
                isHidden: hidden,
              ),
          ]),
        ),
        householdMemberRepositoryProvider.overrideWithValue(
          FakeHouseholdMemberRepository([_member]),
        ),
        transactionRepositoryProvider.overrideWithValue(repository),
      ],
      child: const NarooApp(),
    ),
  );
  await tester.pumpAndSettle();
}

class _ReadySession extends AppSessionNotifier {
  @override
  Future<AppSession> build() async => const AppSession.ready(
    userId: 'user-1',
    profile: Profile(id: 'user-1', displayName: '사용자 A'),
    member: _member,
  );
}
