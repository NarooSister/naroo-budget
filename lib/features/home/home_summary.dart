import '../../data/models/category.dart';
import '../../data/models/transaction.dart';

class HomeSummary {
  HomeSummary({required this.month, required this.budget, required this.items});

  final DateTime month;
  final int? budget;
  final List<TransactionListItem> items;

  int get income => _total(CategoryType.income);
  int get expense => _total(CategoryType.expense);
  int _total(CategoryType type) => items
      .where((i) => i.transaction.type == type)
      .fold(0, (total, i) => total + i.transaction.amount);
  int get balance => income - expense;
  int? get remaining => budget == null ? null : budget! - expense;

  late final Map<DateTime, DayTotal> dailyTotals = () {
    final totals = <DateTime, DayTotal>{};
    for (final item in items) {
      final day = _day(item.transaction.occurredOn);
      final current = totals[day] ?? const DayTotal();
      totals[day] = item.transaction.type == CategoryType.income
          ? DayTotal(
              income: current.income + item.transaction.amount,
              expense: current.expense,
            )
          : DayTotal(
              income: current.income,
              expense: current.expense + item.transaction.amount,
            );
    }
    return totals;
  }();

  List<TransactionListItem> itemsOn(DateTime day) {
    final target = _day(day);
    return [
      for (final item in items)
        if (_day(item.transaction.occurredOn) == target) item,
    ];
  }

  static DateTime _day(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

class DayTotal {
  const DayTotal({this.income = 0, this.expense = 0});

  final int income;
  final int expense;
}
