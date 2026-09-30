import '../../core/amount_rules.dart';

abstract class MonthlyBudgetRepository {
  static const maxAmount = AmountRules.maxAmount;
  Future<int?> find(String householdId, DateTime month);
  Future<void> save(String householdId, DateTime month, int amount);
}
