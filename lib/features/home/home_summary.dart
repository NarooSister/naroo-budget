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
  List<TransactionListItem> get recent => items.take(5).toList();
}
