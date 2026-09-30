enum CategoryType {
  income,
  expense;

  String get dbValue => name;

  String get label => switch (this) {
    CategoryType.income => '수입',
    CategoryType.expense => '지출',
  };

  static CategoryType fromDb(String value) {
    return CategoryType.values.firstWhere(
      (type) => type.dbValue == value,
      orElse: () => throw FormatException('Unknown category type: $value'),
    );
  }
}

class Category {
  const Category({
    required this.id,
    required this.householdId,
    required this.type,
    required this.name,
    required this.isDefault,
    required this.isHidden,
  });

  final String id;
  final String householdId;
  final CategoryType type;
  final String name;
  final bool isDefault;
  final bool isHidden;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      type: CategoryType.fromDb(json['type'] as String),
      name: json['name'] as String,
      isDefault: json['is_default'] as bool,
      isHidden: json['is_hidden'] as bool,
    );
  }

  Category copyWith({String? name, bool? isHidden}) {
    return Category(
      id: id,
      householdId: householdId,
      type: type,
      name: name ?? this.name,
      isDefault: isDefault,
      isHidden: isHidden ?? this.isHidden,
    );
  }
}
