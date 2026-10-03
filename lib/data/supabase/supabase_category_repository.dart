import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category.dart';
import '../repositories/category_repository.dart';

class SupabaseCategoryRepository implements CategoryRepository {
  SupabaseCategoryRepository(this._client);

  final SupabaseClient? _client;

  @override
  Future<List<Category>> listByHousehold(
    String householdId, {
    CategoryType? type,
  }) async {
    final client = _requireClient();

    var query = client
        .from('categories')
        .select()
        .eq('household_id', householdId);

    if (type != null) {
      query = query.eq('type', type.dbValue);
    }

    final rows = await query
        .order('is_uncategorized', ascending: true)
        .order('created_at', ascending: true)
        .order('id', ascending: true);
    return rows.map(Category.fromJson).toList(growable: false);
  }

  @override
  Future<Category> create({
    required String householdId,
    required CategoryType type,
    required String name,
  }) async {
    final client = _requireClient();
    final trimmed = _validateName(name);

    final row = await client
        .from('categories')
        .insert({
          'household_id': householdId,
          'type': type.dbValue,
          'name': trimmed,
        })
        .select()
        .single();

    return Category.fromJson(row);
  }

  @override
  Future<Category> rename({
    required String categoryId,
    required String name,
  }) async {
    final client = _requireClient();
    final trimmed = _validateName(name);

    final existing = await client
        .from('categories')
        .select()
        .eq('id', categoryId)
        .single();
    final category = Category.fromJson(existing);

    if (category.isUncategorized) {
      throw StateError('미분류 이름은 수정할 수 없습니다.');
    }

    final row = await client
        .from('categories')
        .update({'name': trimmed})
        .eq('id', categoryId)
        .select()
        .single();

    return Category.fromJson(row);
  }

  @override
  Future<void> delete(String categoryId) async {
    await _requireClient().rpc<void>(
      'delete_category',
      params: {'target_category_id': categoryId},
    );
  }

  String _validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('카테고리 이름을 입력해 주세요.');
    }
    return trimmed;
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase가 설정되지 않았습니다.');
    }
    return client;
  }
}
