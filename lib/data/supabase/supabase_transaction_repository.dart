import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/amount_rules.dart';
import '../../core/seoul_date.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../repositories/transaction_repository.dart';

class SupabaseTransactionRepository implements TransactionRepository {
  SupabaseTransactionRepository(this._client);

  final SupabaseClient? _client;

  @override
  Future<Transaction> create(NewTransaction input) async {
    final client = _requireClient();
    _validate(input);

    final row = await client
        .from('transactions')
        .insert(_toRow(input))
        .select()
        .single();

    return Transaction.fromJson(row);
  }

  @override
  Future<Transaction> update({
    required String transactionId,
    required NewTransaction input,
  }) async {
    final client = _requireClient();
    _validate(input);

    final row = await client
        .from('transactions')
        .update(_toRow(input))
        .eq('id', transactionId)
        .select()
        .single();

    return Transaction.fromJson(row);
  }

  @override
  Future<void> delete(String transactionId) async {
    final client = _requireClient();

    final deleted = await client
        .from('transactions')
        .delete()
        .eq('id', transactionId)
        .select('id');
    if (deleted.isEmpty) {
      throw StateError('기록을 찾을 수 없습니다.');
    }
  }

  @override
  Future<Transaction?> findById(String transactionId) async {
    final client = _requireClient();

    final row = await client
        .from('transactions')
        .select()
        .eq('id', transactionId)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return Transaction.fromJson(row);
  }

  @override
  Future<List<TransactionListItem>> listByMonth({
    required String householdId,
    required DateTime month,
    CategoryType? type,
  }) async {
    final client = _requireClient();
    final start = SeoulDate.monthStart(month);
    final end = SeoulDate.monthEnd(month);

    final items = <TransactionListItem>[];
    const pageSize = 500;
    while (true) {
      var query = client
          .from('transactions')
          .select(
            '*, categories!transactions_category_id_fkey(name), '
            'subcategory:categories!transactions_subcategory_id_fkey(name), '
            'household_members(display_name)',
          )
          .eq('household_id', householdId)
          .gte('occurred_on', SeoulDate.format(start))
          .lte('occurred_on', SeoulDate.format(end));

      if (type != null) {
        query = query.eq('type', type.dbValue);
      }

      final rows = await query
          .order('occurred_on', ascending: false)
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .range(items.length, items.length + pageSize - 1);

      // A short page can be caused by a server cap below the requested size.
      // Advance by the actual count and stop only when the server returns none.
      if (rows.isEmpty) {
        return items;
      }
      items.addAll(rows.map(TransactionListItem.fromJson));
    }
  }

  Map<String, Object?> _toRow(NewTransaction input) {
    final memo = input.memo?.trim();
    return {
      'household_id': input.householdId,
      'member_id': input.memberId,
      'attribution_kind': input.attributionKind.name,
      'type': input.type.dbValue,
      'amount': input.amount,
      'category_id': input.categoryId,
      'subcategory_id': input.subcategoryId,
      'payment_method': input.paymentMethod?.dbValue,
      'occurred_on': SeoulDate.format(input.occurredOn),
      'memo': (memo == null || memo.isEmpty) ? null : memo,
    };
  }

  void _validate(NewTransaction input) {
    if (input.amount <= 0) {
      throw ArgumentError('금액은 0보다 큰 정수여야 합니다.');
    }
    if (!AmountRules.isValidTransaction(input.amount)) {
      throw ArgumentError('금액은 2,147,483,647원 이하여야 합니다.');
    }
    if (input.categoryId.trim().isEmpty) {
      throw ArgumentError('카테고리를 선택해 주세요.');
    }
    if (input.type == CategoryType.income && input.paymentMethod != null) {
      throw ArgumentError('수입에는 결제 수단을 지정할 수 없습니다.');
    }
    if (input.attributionKind == AttributionKind.member &&
        (input.memberId == null || input.memberId!.trim().isEmpty)) {
      throw ArgumentError('구성원을 선택해 주세요.');
    }
    if (input.attributionKind == AttributionKind.shared &&
        input.memberId != null) {
      throw ArgumentError('공용 기록에는 구성원을 지정할 수 없습니다.');
    }
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase가 설정되지 않았습니다.');
    }
    return client;
  }
}
