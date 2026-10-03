import '../../core/amount_rules.dart';
import 'category.dart';
import 'payment_method.dart';

enum AttributionKind { member, shared }

class Transaction {
  const Transaction({
    required this.id,
    required this.householdId,
    required this.memberId,
    this.attributionKind = AttributionKind.member,
    required this.type,
    required this.amount,
    required this.categoryId,
    this.subcategoryId,
    this.paymentMethod,
    required this.occurredOn,
    this.memo,
  });

  final String id;
  final String householdId;
  final String? memberId;
  final AttributionKind attributionKind;
  final CategoryType type;
  final int amount;
  final String categoryId;
  final String? subcategoryId;
  final PaymentMethod? paymentMethod;
  final DateTime occurredOn;
  final String? memo;

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      memberId: json['member_id'] as String?,
      attributionKind: AttributionKind.values.byName(
        json['attribution_kind'] as String? ?? 'member',
      ),
      type: CategoryType.fromDb(json['type'] as String),
      amount: json['amount'] as int,
      categoryId: json['category_id'] as String,
      subcategoryId: json['subcategory_id'] as String?,
      paymentMethod: PaymentMethod.fromDb(json['payment_method'] as String?),
      occurredOn: _parseDate(json['occurred_on'] as String),
      memo: json['memo'] as String?,
    );
  }
}

class TransactionListItem {
  const TransactionListItem({
    required this.transaction,
    required this.categoryName,
    this.subcategoryName,
    this.memberName,
  });

  final Transaction transaction;
  final String categoryName;
  final String? subcategoryName;
  final String? memberName;

  String get attributionLabel =>
      transaction.attributionKind == AttributionKind.shared
      ? '공용'
      : memberName ?? '구성원';

  String get categoryLabel => subcategoryName == null
      ? categoryName
      : '$categoryName · $subcategoryName';

  String? get memoText {
    final memo = transaction.memo?.trim();
    return memo == null || memo.isEmpty ? null : memo;
  }

  factory TransactionListItem.fromJson(Map<String, dynamic> json) {
    final categories = json['categories'];
    final subcategory = json['subcategory'];
    final members = json['household_members'];

    return TransactionListItem(
      transaction: Transaction.fromJson(json),
      categoryName: categories is Map<String, dynamic>
          ? (categories['name'] as String? ?? '카테고리')
          : '카테고리',
      subcategoryName: subcategory is Map<String, dynamic>
          ? subcategory['name'] as String?
          : null,
      memberName: members is Map<String, dynamic>
          ? members['display_name'] as String?
          : null,
    );
  }
}

class NewTransaction {
  static const maxAmount = AmountRules.maxAmount;

  const NewTransaction({
    required this.householdId,
    required this.memberId,
    this.attributionKind = AttributionKind.member,
    required this.type,
    required this.amount,
    required this.categoryId,
    this.subcategoryId,
    this.paymentMethod,
    required this.occurredOn,
    this.memo,
  });

  final String householdId;
  final String? memberId;
  final AttributionKind attributionKind;
  final CategoryType type;
  final int amount;
  final String categoryId;
  final String? subcategoryId;
  final PaymentMethod? paymentMethod;
  final DateTime occurredOn;
  final String? memo;
}

DateTime _parseDate(String raw) {
  final parts = raw.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}
