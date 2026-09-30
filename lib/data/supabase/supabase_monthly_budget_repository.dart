import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/amount_rules.dart';
import '../repositories/monthly_budget_repository.dart';

class SupabaseMonthlyBudgetRepository implements MonthlyBudgetRepository {
  SupabaseMonthlyBudgetRepository(this._client);
  final SupabaseClient? _client;
  SupabaseClient get client =>
      _client ?? (throw StateError('Supabase가 설정되지 않았습니다.'));

  @override
  Future<int?> find(String householdId, DateTime month) async {
    final row = await client
        .from('monthly_budgets')
        .select('amount')
        .eq('household_id', householdId)
        .eq('year', month.year)
        .eq('month', month.month)
        .maybeSingle();
    return row?['amount'] as int?;
  }

  @override
  Future<void> save(String householdId, DateTime month, int amount) async {
    if (!AmountRules.isValidBudget(amount)) {
      throw ArgumentError('예산 금액이 범위를 벗어났습니다.');
    }
    await client
        .from('monthly_budgets')
        .upsert({
          'household_id': householdId,
          'year': month.year,
          'month': month.month,
          'amount': amount,
        }, onConflict: 'household_id,year,month')
        .select('amount')
        .single();
  }
}
