import 'package:naroo/data/models/category.dart';
import 'package:naroo/data/repositories/category_repository.dart';

class FakeCategoryRepository implements CategoryRepository {
  FakeCategoryRepository([List<Category>? seed])
    : _items = List<Category>.from(seed ?? const []);

  final List<Category> _items;
  var _nextId = 1;

  @override
  Future<List<Category>> listByHousehold(
    String householdId, {
    CategoryType? type,
    bool includeHidden = true,
  }) async {
    return _items
        .where((item) => item.householdId == householdId)
        .where((item) => type == null || item.type == type)
        .where((item) => includeHidden || !item.isHidden)
        .toList(growable: false);
  }

  @override
  Future<Category> create({
    required String householdId,
    required CategoryType type,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('카테고리 이름을 입력해 주세요.');
    }

    final category = Category(
      id: 'fake-${_nextId++}',
      householdId: householdId,
      type: type,
      name: trimmed,
      isDefault: false,
      isHidden: false,
    );
    _items.add(category);
    return category;
  }

  @override
  Future<Category> rename({
    required String categoryId,
    required String name,
  }) async {
    final index = _items.indexWhere((item) => item.id == categoryId);
    if (index < 0) {
      throw StateError('category not found');
    }

    final current = _items[index];
    if (current.isDefault) {
      throw StateError('기본 카테고리 이름은 수정할 수 없습니다.');
    }

    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('카테고리 이름을 입력해 주세요.');
    }

    final updated = current.copyWith(name: trimmed);
    _items[index] = updated;
    return updated;
  }

  @override
  Future<Category> setHidden({
    required String categoryId,
    required bool isHidden,
  }) async {
    final index = _items.indexWhere((item) => item.id == categoryId);
    if (index < 0) {
      throw StateError('category not found');
    }

    final updated = _items[index].copyWith(isHidden: isHidden);
    _items[index] = updated;
    return updated;
  }
}
