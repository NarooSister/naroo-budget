import '../../core/amount_rules.dart';
import '../models/monthly_budget.dart';

abstract class MonthlyBudgetRepository {
  static const maxAmount = AmountRules.maxAmount;

  Future<MonthlyBudget?> find(String householdId, DateTime month);

  /// Replaces the month's total and allocations. [expectedVersion] is the
  /// loaded [MonthlyBudget.version], or null when the month had no budget.
  /// Throws [BudgetConflictException] when the budget changed in between.
  Future<void> save(
    String householdId,
    DateTime month, {
    required int amount,
    required Map<String, int> allocations,
    required String? expectedVersion,
  });

  /// Returns the month to the unset state.
  Future<void> reset(
    String householdId,
    DateTime month, {
    required String? expectedVersion,
  });
}
