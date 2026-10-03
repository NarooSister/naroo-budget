import 'package:flutter_test/flutter_test.dart';
import 'package:naroo/data/models/category.dart';

import 'fake_category_repository.dart';

void main() {
  test('가계부/유형별 목록과 일반 분류 수정·삭제', () async {
    final repository = FakeCategoryRepository([
      const Category(
        id: 'food',
        householdId: 'h1',
        type: CategoryType.expense,
        name: '식비',
      ),
      const Category(
        id: 'salary',
        householdId: 'h1',
        type: CategoryType.income,
        name: '월급',
      ),
      const Category(
        id: 'other',
        householdId: 'h2',
        type: CategoryType.expense,
        name: '다른 집',
      ),
    ]);
    expect(
      (await repository.listByHousehold(
        'h1',
        type: CategoryType.expense,
      )).single.id,
      'food',
    );
    expect(
      (await repository.rename(categoryId: 'food', name: ' 먹거리 ')).name,
      '먹거리',
    );
    await repository.delete('food');
    expect(
      await repository.listByHousehold('h1', type: CategoryType.expense),
      isEmpty,
    );
    expect(await repository.listByHousehold('h2'), hasLength(1));
  });

  test('미분류 식별값 변환과 수정·삭제 보호', () async {
    final category = Category.fromJson({
      'id': 'u',
      'household_id': 'h1',
      'type': 'expense',
      'name': '미분류',
      'is_uncategorized': true,
    });
    expect(category.isUncategorized, true);
    final repository = FakeCategoryRepository([category]);
    await expectLater(
      repository.rename(categoryId: 'u', name: '변경'),
      throwsStateError,
    );
    await expectLater(repository.delete('u'), throwsStateError);
    expect((await repository.listByHousehold('h1')).single.id, 'u');
  });
}
