import '../../core/amount_rules.dart';
import 'category.dart';

class Transaction {
  const Transaction({
    required this.id,
    required this.householdId,
    required this.memberId,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.occurredOn,
    this.memo,
  });

  final String id;
  final String householdId;
  final String memberId;
  final CategoryType type;
  final int amount;
  final String categoryId;
  final DateTime occurredOn;
  final String? memo;

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      memberId: json['member_id'] as String,
      type: CategoryType.fromDb(json['type'] as String),
      amount: json['amount'] as int,
      categoryId: json['category_id'] as String,
      occurredOn: _parseDate(json['occurred_on'] as String),
      memo: json['memo'] as String?,
    );
  }
}

class TransactionListItem {
  const TransactionListItem({
    required this.transaction,
    required this.categoryName,
    this.memberName,
  });

  final Transaction transaction;
  final String categoryName;
  final String? memberName;

  String get title {
    final memo = transaction.memo?.trim();
    if (memo != null && memo.isNotEmpty) {
      return memo;
    }
    return categoryName;
  }

  factory TransactionListItem.fromJson(Map<String, dynamic> json) {
    final categories = json['categories'];
    final members = json['household_members'];

    return TransactionListItem(
      transaction: Transaction.fromJson(json),
      categoryName: categories is Map<String, dynamic>
          ? (categories['name'] as String? ?? '카테고리')
          : '카테고리',
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
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.occurredOn,
    this.memo,
  });

  final String householdId;
  final String memberId;
  final CategoryType type;
  final int amount;
  final String categoryId;
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
