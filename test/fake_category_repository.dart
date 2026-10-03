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
  }) async {
    return _items
        .where((item) => item.householdId == householdId)
        .where((item) => type == null || item.type == type)
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
    if (current.isUncategorized) {
      throw StateError('미분류 이름은 수정할 수 없습니다.');
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
  Future<void> delete(String categoryId) async {
    final index = _items.indexWhere((item) => item.id == categoryId);
    if (index < 0) throw StateError('category not found');
    if (_items[index].isUncategorized) throw StateError('미분류는 삭제할 수 없습니다.');
    _items.removeAt(index);
  }
}
