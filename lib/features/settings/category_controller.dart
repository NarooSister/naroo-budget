import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/app_session.dart';
import '../../data/models/category.dart';
import '../../data/repository_providers.dart';

final categoriesProvider =
    AsyncNotifierProvider<CategoriesNotifier, List<Category>>(
      CategoriesNotifier.new,
    );

class CategoriesNotifier extends AsyncNotifier<List<Category>> {
  @override
  Future<List<Category>> build() {
    return _load();
  }

  Future<List<Category>> _load() async {
    final session = await ref.watch(appSessionProvider.future);
    final householdId = session.member?.householdId;
    if (householdId == null) {
      return const [];
    }

    return ref.read(categoryRepositoryProvider).listByHousehold(householdId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> create({
    required CategoryType type,
    required String name,
  }) async {
    final session = await ref.read(appSessionProvider.future);
    final householdId = session.member?.householdId;
    if (householdId == null) {
      throw StateError('Household에 연결되지 않았습니다.');
    }

    await ref
        .read(categoryRepositoryProvider)
        .create(householdId: householdId, type: type, name: name);
    await refresh();
  }

  Future<void> rename({
    required String categoryId,
    required String name,
  }) async {
    await ref
        .read(categoryRepositoryProvider)
        .rename(categoryId: categoryId, name: name);
    await refresh();
  }

  Future<void> setHidden({
    required String categoryId,
    required bool isHidden,
  }) async {
    await ref
        .read(categoryRepositoryProvider)
        .setHidden(categoryId: categoryId, isHidden: isHidden);
    await refresh();
  }
}
