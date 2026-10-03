import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/amount_rules.dart';
import '../models/monthly_budget.dart';
import '../repositories/monthly_budget_repository.dart';

class SupabaseMonthlyBudgetRepository implements MonthlyBudgetRepository {
  SupabaseMonthlyBudgetRepository(this._client);
  final SupabaseClient? _client;
  SupabaseClient get client =>
      _client ?? (throw StateError('Supabase가 설정되지 않았습니다.'));

  @override
  Future<MonthlyBudget?> find(String householdId, DateTime month) async {
    final row = await client
        .from('monthly_budgets')
        .select('amount, revision, budget_allocations(category_id, amount)')
        .eq('household_id', householdId)
        .eq('year', month.year)
        .eq('month', month.month)
        .maybeSingle();
    return row == null ? null : MonthlyBudget.fromJson(row);
  }

  @override
  Future<void> save(
    String householdId,
    DateTime month, {
    required int amount,
    required Map<String, int> allocations,
    required String? expectedVersion,
  }) async {
    final allocated = allocations.values.fold(0, (sum, v) => sum + v);
    if (!AmountRules.isValidBudget(amount) ||
        allocations.values.any((v) => !AmountRules.isValidBudget(v)) ||
        allocated > amount) {
      throw ArgumentError('예산 금액이 범위를 벗어났습니다.');
    }
    await _call('save_monthly_budget', {
      'target_household_id': householdId,
      'target_year': month.year,
      'target_month': month.month,
      'total_amount': amount,
      'allocations': [
        for (final entry in allocations.entries)
          {'category_id': entry.key, 'amount': entry.value},
      ],
      'expected_revision': expectedVersion,
    });
  }

  @override
  Future<void> reset(
    String householdId,
    DateTime month, {
    required String? expectedVersion,
  }) {
    return _call('reset_monthly_budget', {
      'target_household_id': householdId,
      'target_year': month.year,
      'target_month': month.month,
      'expected_revision': expectedVersion,
    });
  }

  Future<void> _call(String function, Map<String, dynamic> params) async {
    try {
      await client.rpc<dynamic>(function, params: params);
    } on PostgrestException catch (error) {
      if (error.code == 'PT409' || error.code == '409') {
        throw const BudgetConflictException();
      }
      rethrow;
    }
  }
}
