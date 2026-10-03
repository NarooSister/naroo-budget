import '../models/category.dart';

abstract class CategoryRepository {
  Future<List<Category>> listByHousehold(
    String householdId, {
    CategoryType? type,
  });

  Future<Category> create({
    required String householdId,
    required CategoryType type,
    required String name,
    String? parentId,
  });

  Future<Category> rename({required String categoryId, required String name});

  Future<void> delete(String categoryId);
}
