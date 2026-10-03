import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naroo/core/session/app_session.dart';
import 'package:naroo/core/category_changes.dart';
import 'package:naroo/core/transaction_changes.dart';
import 'package:naroo/data/models/category.dart';
import 'package:naroo/data/models/household_member.dart';
import 'package:naroo/data/models/profile.dart';
import 'package:naroo/data/repository_providers.dart';
import 'package:naroo/features/settings/category_controller.dart';
import 'package:naroo/features/transaction/transaction_editor_controller.dart';

import 'fake_category_repository.dart';

void main() {
  test('카테고리 변경 후 입력 선택지와 거래 표시 갱신, 실패 시 알림 없음', () async {
    final repository = _CategoryRepository();
    final container = _container(repository);
    final choices = transactionCategoriesProvider(CategoryType.expense);
    final subscription = container.listen(choices, (_, _) {});
    addTearDown(subscription.close);
    expect(await container.read(choices.future), isEmpty);
    await container.read(categoriesProvider.future);
    final notifier = container.read(categoriesProvider.notifier);
    await notifier.create(type: CategoryType.expense, name: '식비');
    final created = (await container.read(choices.future)).single;
    expect(created.name, '식비');
    expect(container.read(transactionChangesProvider), 0);
    await notifier.rename(categoryId: created.id, name: '먹거리');
    expect((await container.read(choices.future)).single.name, '먹거리');
    expect(container.read(transactionChangesProvider), 1);
    final changes = container.read(categoryChangesProvider);
    await expectLater(notifier.delete('missing'), throwsStateError);
    expect(container.read(categoryChangesProvider), changes);
    expect(container.read(transactionChangesProvider), 1);
    await notifier.delete(created.id);
    expect(await container.read(choices.future), isEmpty);
    expect(container.read(transactionChangesProvider), 2);
  });

  test('생성·이름 변경·삭제 뒤 Household 목록을 갱신한다', () async {
    final repository = _CategoryRepository();
    final container = _container(repository);
    expect(await container.read(categoriesProvider.future), isEmpty);
    final notifier = container.read(categoriesProvider.notifier);
    await notifier.create(type: CategoryType.expense, name: ' 구독 ');
    final created = container.read(categoriesProvider).requireValue.single;
    expect(created.householdId, 'h1');
    expect(created.name, '구독');
    await notifier.rename(categoryId: created.id, name: ' 정기 구독 ');
    expect(
      container.read(categoriesProvider).requireValue.single.name,
      '정기 구독',
    );
    await notifier.delete(created.id);
    expect(container.read(categoriesProvider).requireValue, isEmpty);
  });

  test('미연결 사용자는 빈 목록이며 카테고리를 생성하지 못한다', () async {
    final repository = _CategoryRepository();
    final container = _container(repository, connected: false);
    expect(await container.read(categoriesProvider.future), isEmpty);
    await expectLater(
      container
          .read(categoriesProvider.notifier)
          .create(type: CategoryType.income, name: '월급'),
      throwsStateError,
    );
    expect(await repository.listByHousehold('h1'), isEmpty);
  });

  test('목록 실패와 재시도를 반영하고 쓰기 실패로 기존 목록을 잃지 않는다', () async {
    final repository = _CategoryRepository();
    final container = _container(repository);
    await container.read(categoriesProvider.future);
    final notifier = container.read(categoriesProvider.notifier);
    await notifier.create(type: CategoryType.income, name: '급여');
    final original = container.read(categoriesProvider).requireValue.single;
    await expectLater(
      notifier.rename(categoryId: original.id, name: ' '),
      throwsArgumentError,
    );
    expect(container.read(categoriesProvider).requireValue.single.name, '급여');
    repository.failLoad = true;
    await notifier.refresh();
    expect(container.read(categoriesProvider).hasError, true);
    repository.failLoad = false;
    await notifier.refresh();
    expect(
      container.read(categoriesProvider).requireValue.single.id,
      original.id,
    );
  });
}

ProviderContainer _container(
  _CategoryRepository repository, {
  bool connected = true,
}) {
  final container = ProviderContainer(
    overrides: [
      appSessionProvider.overrideWith(() => _Session(connected)),
      categoryRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

class _Session extends AppSessionNotifier {
  _Session(this.connected);
  final bool connected;
  @override
  Future<AppSession> build() async => connected
      ? const AppSession.ready(
          userId: 'u1',
          profile: Profile(id: 'u1', displayName: '나루'),
          member: HouseholdMember(
            id: 'm1',
            householdId: 'h1',
            userId: 'u1',
            displayName: '나루',
          ),
        )
      : const AppSession.signedOut();
}

class _CategoryRepository extends FakeCategoryRepository {
  bool failLoad = false;
  @override
  Future<List<Category>> listByHousehold(
    String householdId, {
    CategoryType? type,
  }) {
    if (failLoad) throw StateError('load failed');
    return super.listByHousehold(householdId, type: type);
  }
}
