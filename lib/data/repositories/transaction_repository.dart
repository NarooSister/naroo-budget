import '../models/category.dart';
import '../models/transaction.dart';

abstract class TransactionRepository {
  Future<Transaction> create(NewTransaction input);

  Future<Transaction> update({
    required String transactionId,
    required NewTransaction input,
  });

  Future<void> delete(String transactionId);

  Future<Transaction?> findById(String transactionId);

  Future<List<TransactionListItem>> listByMonth({
    required String householdId,
    required DateTime month,
    CategoryType? type,
  });
}
