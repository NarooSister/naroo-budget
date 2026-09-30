import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:naroo/app/app.dart';
import 'package:naroo/core/session/app_session.dart';
import 'package:naroo/data/models/category.dart';
import 'package:naroo/data/models/household_member.dart';
import 'package:naroo/data/models/profile.dart';
import 'package:naroo/data/repository_providers.dart';
import 'package:naroo/features/settings/category_controller.dart';
import 'package:naroo/features/settings/category_management_screen.dart';

import 'fake_category_repository.dart';

const _profile = Profile(id: 'user-1', displayName: '테스트 사용자');
const _member = HouseholdMember(
  id: 'member-1',
  householdId: 'household-1',
  userId: 'user-1',
  displayName: '테스트 사용자',
);

void main() {
  testWidgets('사용자 카테고리를 수정·숨김·복원하고 수입 카테고리를 추가한다', (tester) async {
    final repository = FakeCategoryRepository([
      const Category(
        id: 'custom',
        householdId: 'household-1',
        type: CategoryType.expense,
        name: '구독',
        isDefault: false,
        isHidden: false,
      ),
    ]);
    await _pumpManagement(tester, repository);
    await tester.tap(find.byTooltip('수정'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '구독',
    );
    await tester.enterText(find.byType(TextField), ' 정기 구독 ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('정기 구독'), findsOneWidget);
    expect(find.text('구독'), findsNothing);
    await tester.tap(find.byTooltip('숨기기'));
    await tester.pumpAndSettle();
    expect(find.text('숨김'), findsOneWidget);
    await tester.tap(find.byTooltip('숨김 해제'));
    await tester.pumpAndSettle();
    expect(find.text('숨김'), findsNothing);
    expect(find.byTooltip('숨기기'), findsOneWidget);
    await tester.tap(find.text('수입'));
    await tester.pumpAndSettle();
    expect(find.text('카테고리가 없어요.'), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('수입 카테고리 추가'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '상여');
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();
    expect(find.text('상여'), findsOneWidget);
    expect(
      (await repository.listByHousehold(
        'household-1',
        type: CategoryType.income,
      )).single.name,
      '상여',
    );
  });

  testWidgets('편집 취소와 저장·숨김·목록 오류를 사용자에게 표시한다', (tester) async {
    final repository = _FailingCategoryRepository([
      const Category(
        id: 'custom',
        householdId: 'household-1',
        type: CategoryType.expense,
        name: '구독',
        isDefault: false,
        isHidden: false,
      ),
    ]);
    final container = await _pumpManagement(tester, repository);
    await tester.tap(find.byTooltip('수정'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '취소한 이름');
    await tester.tapAt(const Offset(10, 100));
    await tester.pumpAndSettle();
    expect(find.text('구독'), findsOneWidget);
    expect(find.text('취소한 이름'), findsNothing);
    await tester.tap(find.byTooltip('수정'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), ' ');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('카테고리를 저장하지 못했습니다.'), findsOneWidget);
    expect(find.text('구독'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('숨기기'));
    await tester.pumpAndSettle();
    expect(find.text('카테고리 숨김 상태를 바꾸지 못했습니다.'), findsOneWidget);
    expect(find.byTooltip('숨기기'), findsOneWidget);
    repository.failLoad = true;
    container.invalidate(categoriesProvider);
    await tester.pumpAndSettle();
    expect(find.text('카테고리를 불러오지 못했습니다.'), findsOneWidget);
    repository.failLoad = false;
    container.invalidate(categoriesProvider);
    await tester.pumpAndSettle();
    expect(find.text('구독'), findsOneWidget);
  });

  testWidgets('설정에서 카테고리 관리로 들어가 목록을 보고 추가할 수 있다', (tester) async {
    final repository = FakeCategoryRepository([
      const Category(
        id: 'c1',
        householdId: 'household-1',
        type: CategoryType.expense,
        name: '식비',
        isDefault: true,
        isHidden: false,
      ),
      const Category(
        id: 'c2',
        householdId: 'household-1',
        type: CategoryType.income,
        name: '월급',
        isDefault: true,
        isHidden: false,
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
          categoryRepositoryProvider.overrideWithValue(repository),
        ],
        child: const NarooApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, '설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('카테고리 관리'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, '카테고리 관리'), findsOneWidget);
    expect(find.text('식비'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '구독');
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();

    expect(find.text('구독'), findsOneWidget);

    await tester.tap(find.text('수입'));
    await tester.pumpAndSettle();
    expect(find.text('월급'), findsOneWidget);
  });
}

Future<ProviderContainer> _pumpManagement(
  WidgetTester tester,
  FakeCategoryRepository repository,
) async {
  final container = ProviderContainer(
    overrides: [
      appSessionProvider.overrideWith(
        () => _FakeAppSessionNotifier(
          const AppSession.ready(
            userId: 'user-1',
            profile: _profile,
            member: _member,
          ),
        ),
      ),
      categoryRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CategoryManagementScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

class _FailingCategoryRepository extends FakeCategoryRepository {
  _FailingCategoryRepository(super.seed);
  bool failLoad = false;
  @override
  Future<List<Category>> listByHousehold(
    String householdId, {
    CategoryType? type,
    bool includeHidden = true,
  }) {
    if (failLoad) throw StateError('load failed');
    return super.listByHousehold(
      householdId,
      type: type,
      includeHidden: includeHidden,
    );
  }

  @override
  Future<Category> setHidden({
    required String categoryId,
    required bool isHidden,
  }) async => throw StateError('denied');
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
