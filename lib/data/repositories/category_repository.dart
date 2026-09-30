import '../models/category.dart';

abstract class CategoryRepository {
  Future<List<Category>> listByHousehold(
    String householdId, {
    CategoryType? type,
    bool includeHidden = true,
  });

  Future<Category> create({
    required String householdId,
    required CategoryType type,
    required String name,
  });

  Future<Category> rename({required String categoryId, required String name});

  Future<Category> setHidden({
    required String categoryId,
    required bool isHidden,
  });
}
