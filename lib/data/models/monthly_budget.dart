class MonthlyBudget {
  const MonthlyBudget({
    required this.amount,
    required this.version,
    this.allocations = const {},
  });

  final int amount;

  /// Server `revision`, renewed on every save. Sent back to detect a concurrent
  /// change.
  final String version;

  /// Expense top-level category ID → allocated amount.
  final Map<String, int> allocations;

  int get allocatedTotal => allocations.values.fold(0, (sum, v) => sum + v);
  int get unallocated => amount - allocatedTotal;

  factory MonthlyBudget.fromJson(Map<String, dynamic> json) {
    final rows = json['budget_allocations'] as List<dynamic>? ?? const [];
    return MonthlyBudget(
      amount: json['amount'] as int,
      version: json['revision'] as String,
      allocations: {
        for (final row in rows.cast<Map<String, dynamic>>())
          row['category_id'] as String: row['amount'] as int,
      },
    );
  }
}

/// Someone else saved or reset the budget after it was loaded.
class BudgetConflictException implements Exception {
  const BudgetConflictException();
}
