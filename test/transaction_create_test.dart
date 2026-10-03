import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:naroo/app/app.dart';
import 'package:naroo/core/seoul_date.dart';
import 'package:naroo/core/session/app_session.dart';
import 'package:naroo/data/models/category.dart';
import 'package:naroo/data/models/household_member.dart';
import 'package:naroo/data/models/payment_method.dart';
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

  testWidgets('미분류는 선택지에 없고 소분류는 선택 대분류에 맞춰 바뀐다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transactions = FakeTransactionRepository();
    await _pumpApp(tester, transactions, _subcategoryFixtures);

    await tester.tap(find.byTooltip('기록 추가'));
    await tester.pumpAndSettle();
    expect(find.text('미분류'), findsNothing);
    expect(find.text('소분류 (선택)'), findsNothing);
    expect(find.text('장보기'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '9000');
    await tester.tap(find.text('식비'));
    await tester.pumpAndSettle();
    expect(find.text('소분류 (선택)'), findsOneWidget);
    await tester.tap(find.text('장보기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('카페'));
    await tester.pumpAndSettle();
    expect(find.text('장보기'), findsNothing);
    await tester.tap(find.text('식비'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(transactions.created.single.categoryId, 'food');
    expect(transactions.created.single.subcategoryId, isNull);

    await tester.tap(find.byTooltip('기록 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '9000');
    await tester.tap(find.text('식비'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('외식'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('외식'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('외식'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(transactions.created.last.categoryId, 'food');
    expect(transactions.created.last.subcategoryId, 'eating-out');
  });

  testWidgets('새 지출은 기본 결제 수단을 먼저 선택하고 맨 앞에 둔다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transactions = FakeTransactionRepository();
    await _pumpApp(tester, transactions, _subcategoryFixtures);

    await tester.tap(find.byTooltip('기록 추가'));
    await tester.pumpAndSettle();
    expect(_paymentLabels(tester), ['체크카드', '신용카드', '현금']);
    expect(_selectedPayment(tester), {PaymentMethod.debitCard});
    await tester.enterText(find.byType(TextField).first, '1000');
    await tester.tap(find.text('카페'));
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(transactions.created.single.paymentMethod, PaymentMethod.debitCard);
  });

  testWidgets('자주 쓰는 수단을 앞에 두고 해제·수입 전환 시 미지정으로 저장한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transactions = FakeTransactionRepository();
    await _pumpApp(
      tester,
      transactions,
      [
        ..._subcategoryFixtures,
        const Category(
          id: 'salary',
          householdId: 'household-1',
          type: CategoryType.income,
          name: '월급',
        ),
      ],
      profile: const Profile(
        id: 'user-1',
        displayName: '테스트 사용자',
        defaultPaymentMethod: PaymentMethod.cash,
      ),
    );

    await tester.tap(find.byTooltip('기록 추가'));
    await tester.pumpAndSettle();
    expect(_paymentLabels(tester), ['현금', '체크카드', '신용카드']);
    expect(_selectedPayment(tester), {PaymentMethod.cash});

    await tester.tap(find.text('현금'));
    await tester.pumpAndSettle();
    expect(_selectedPayment(tester), isEmpty);
    expect(find.text('미지정'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '1000');
    await tester.tap(find.text('카페'));
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(transactions.created.single.paymentMethod, isNull);

    await tester.tap(find.byTooltip('기록 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('신용카드'));
    await tester.tap(find.text('수입'));
    await tester.pumpAndSettle();
    expect(find.text('결제 수단'), findsNothing);
    await tester.enterText(find.byType(TextField).first, '5000');
    await tester.tap(find.text('월급'));
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(transactions.created.last.type, CategoryType.income);
    expect(transactions.created.last.paymentMethod, isNull);
  });

  testWidgets('미분류 기존 기록은 수정 시에만 미분류를 유지할 수 있다', (tester) async {
    final transactions = FakeTransactionRepository([
      TransactionListItem(
        transaction: Transaction(
          id: 'tx-1',
          householdId: 'household-1',
          memberId: 'member-1',
          type: CategoryType.expense,
          amount: 3000,
          categoryId: 'unc',
          occurredOn: SeoulDate.today(),
        ),
        categoryName: '미분류',
      ),
    ]);
    await _pumpApp(tester, transactions, _subcategoryFixtures);

    await tester.tap(find.widgetWithText(NavigationDestination, '내역'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('미분류'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '수정'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '기록 수정'), findsOneWidget);
    expect(find.text('미분류'), findsOneWidget);
    await tester.tap(find.text('수정 저장'));
    await tester.pumpAndSettle();
    expect(transactions.updateCalls, 1);
    expect((await transactions.findById('tx-1'))?.categoryId, 'unc');
  });
}

List<String> _paymentLabels(WidgetTester tester) => tester
    .widget<SegmentedButton<PaymentMethod>>(
      find.byType(SegmentedButton<PaymentMethod>),
    )
    .segments
    .map((segment) => (segment.label! as Text).data!)
    .toList();

Set<PaymentMethod> _selectedPayment(WidgetTester tester) => tester
    .widget<SegmentedButton<PaymentMethod>>(
      find.byType(SegmentedButton<PaymentMethod>),
    )
    .selected;

const _subcategoryFixtures = [
  Category(
    id: 'food',
    householdId: 'household-1',
    type: CategoryType.expense,
    name: '식비',
  ),
  Category(
    id: 'groceries',
    householdId: 'household-1',
    type: CategoryType.expense,
    name: '장보기',
    parentId: 'food',
  ),
  Category(
    id: 'eating-out',
    householdId: 'household-1',
    type: CategoryType.expense,
    name: '외식',
    parentId: 'food',
  ),
  Category(
    id: 'cafe',
    householdId: 'household-1',
    type: CategoryType.expense,
    name: '카페',
  ),
  Category(
    id: 'unc',
    householdId: 'household-1',
    type: CategoryType.expense,
    name: '미분류',
    isUncategorized: true,
  ),
];

Future<void> _pumpApp(
  WidgetTester tester,
  FakeTransactionRepository transactions,
  List<Category> categories, {
  Profile profile = _profile,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appSessionProvider.overrideWith(
          () => _FakeAppSessionNotifier(
            AppSession.ready(
              userId: 'user-1',
              email: 'user@example.com',
              profile: profile,
              member: _member,
            ),
          ),
        ),
        categoryRepositoryProvider.overrideWithValue(
          FakeCategoryRepository(categories),
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
