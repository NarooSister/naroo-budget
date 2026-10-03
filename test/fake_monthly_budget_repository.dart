import 'dart:async';

import 'package:naroo/data/models/monthly_budget.dart';
import 'package:naroo/data/repositories/monthly_budget_repository.dart';

/// In-memory budgets keyed by month start, with the server's version check.
class FakeMonthlyBudgetRepository extends MonthlyBudgetRepository {
  FakeMonthlyBudgetRepository([Map<DateTime, MonthlyBudget>? seed])
    : budgets = {...?seed};

  final Map<DateTime, MonthlyBudget> budgets;
  int writes = 0;
  int resets = 0;
  bool fail = false;
  Completer<void>? pending;
  var _version = 0;

  static MonthlyBudget budget(
    int amount, [
    Map<String, int> allocations = const {},
  ]) =>
      MonthlyBudget(amount: amount, version: 'seed', allocations: allocations);

  @override
  Future<MonthlyBudget?> find(String householdId, DateTime month) async =>
      budgets[month];

  @override
  Future<void> save(
    String householdId,
    DateTime month, {
    required int amount,
    required Map<String, int> allocations,
    required String? expectedVersion,
  }) async {
    writes++;
    await pending?.future;
    if (fail) throw StateError('private error');
    if (budgets[month]?.version != expectedVersion) {
      throw const BudgetConflictException();
    }
    budgets[month] = MonthlyBudget(
      amount: amount,
      version: 'v${++_version}',
      allocations: allocations,
    );
  }

  @override
  Future<void> reset(
    String householdId,
    DateTime month, {
    required String? expectedVersion,
  }) async {
    resets++;
    if (fail) throw StateError('private error');
    final current = budgets[month];
    if (current == null) return;
    if (current.version != expectedVersion) {
      throw const BudgetConflictException();
    }
    budgets.remove(month);
  }
}
