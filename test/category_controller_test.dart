import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naroo/core/session/app_session.dart';
import 'package:naroo/data/models/category.dart';
import 'package:naroo/data/models/household_member.dart';
import 'package:naroo/data/models/profile.dart';
import 'package:naroo/data/repository_providers.dart';
import 'package:naroo/features/settings/category_controller.dart';

import 'fake_category_repository.dart';

void main() {
  test('생성·이름 변경·숨김·복원 뒤 Household 목록을 갱신한다', () async {
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
    await notifier.setHidden(categoryId: created.id, isHidden: true);
    expect(
      container.read(categoriesProvider).requireValue.single.isHidden,
      true,
    );
    await notifier.setHidden(categoryId: created.id, isHidden: false);
    expect(
      container.read(categoriesProvider).requireValue.single.isHidden,
      false,
    );
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
    bool includeHidden = true,
  }) {
    if (failLoad) throw StateError('load failed');
    return super.listByHousehold(
      householdId,
      type: type,
      includeHidden: includeHidden,
    );
  }
}
