import 'package:flutter_test/flutter_test.dart';

import 'package:naroo/data/models/category.dart';

import 'fake_category_repository.dart';

void main() {
  test('타입별 조회와 숨김 제외 필터가 동작한다', () async {
    final repository = FakeCategoryRepository([
      const Category(
        id: '1',
        householdId: 'h1',
        type: CategoryType.expense,
        name: '식비',
        isDefault: true,
        isHidden: false,
      ),
      const Category(
        id: '2',
        householdId: 'h1',
        type: CategoryType.expense,
        name: '숨긴 식비',
        isDefault: false,
        isHidden: true,
      ),
      const Category(
        id: '3',
        householdId: 'h1',
        type: CategoryType.income,
        name: '월급',
        isDefault: true,
        isHidden: false,
      ),
    ]);

    final expenses = await repository.listByHousehold(
      'h1',
      type: CategoryType.expense,
      includeHidden: false,
    );

    expect(expenses.map((item) => item.name), ['식비']);
  });

  test('기본 카테고리 이름 수정은 거부한다', () async {
    final repository = FakeCategoryRepository([
      const Category(
        id: '1',
        householdId: 'h1',
        type: CategoryType.expense,
        name: '식비',
        isDefault: true,
        isHidden: false,
      ),
    ]);

    expect(
      () => repository.rename(categoryId: '1', name: '식비2'),
      throwsStateError,
    );
  });

  test('사용자 카테고리 생성/수정/숨김이 동작한다', () async {
    final repository = FakeCategoryRepository();

    final created = await repository.create(
      householdId: 'h1',
      type: CategoryType.expense,
      name: ' 구독 ',
    );
    expect(created.name, '구독');
    expect(created.isDefault, isFalse);

    final renamed = await repository.rename(
      categoryId: created.id,
      name: '멤버십',
    );
    expect(renamed.name, '멤버십');

    final hidden = await repository.setHidden(
      categoryId: created.id,
      isHidden: true,
    );
    expect(hidden.isHidden, isTrue);
  });
}
