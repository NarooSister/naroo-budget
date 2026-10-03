import 'package:naroo/data/models/category.dart';
import 'package:naroo/data/models/transaction.dart';
import 'package:naroo/data/repositories/transaction_repository.dart';

class FakeTransactionRepository implements TransactionRepository {
  FakeTransactionRepository([List<TransactionListItem>? seed])
    : _items = List<TransactionListItem>.from(seed ?? const []);

  final List<TransactionListItem> _items;
  final List<NewTransaction> created = [];
  var createCalls = 0;
  var updateCalls = 0;
  var deleteCalls = 0;
  var listCalls = 0;
  final deletedIds = <String>[];
  Duration delay = Duration.zero;
  Object? writeError;
  Object? readError;
  bool missingOnRead = false;

  Future<void> _beforeWrite() async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    final error = writeError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<Transaction> create(NewTransaction input) async {
    createCalls += 1;
    if (input.amount <= 0) {
      throw ArgumentError('금액은 0보다 큰 정수여야 합니다.');
    }
    await _beforeWrite();
    created.add(input);
    final transaction = Transaction(
      id: 'tx-$createCalls',
      householdId: input.householdId,
      memberId: input.memberId,
      attributionKind: input.attributionKind,
      type: input.type,
      amount: input.amount,
      categoryId: input.categoryId,
      occurredOn: input.occurredOn,
      memo: input.memo,
    );
    _items.add(
      TransactionListItem(transaction: transaction, categoryName: '카테고리'),
    );
    return transaction;
  }

  @override
  Future<Transaction> update({
    required String transactionId,
    required NewTransaction input,
  }) async {
    updateCalls += 1;
    await _beforeWrite();
    final index = _items.indexWhere(
      (item) => item.transaction.id == transactionId,
    );
    if (index < 0) {
      throw StateError('transaction not found');
    }

    final updated = Transaction(
      id: transactionId,
      householdId: input.householdId,
      memberId: input.memberId,
      attributionKind: input.attributionKind,
      type: input.type,
      amount: input.amount,
      categoryId: input.categoryId,
      occurredOn: input.occurredOn,
      memo: input.memo,
    );
    _items[index] = TransactionListItem(
      transaction: updated,
      categoryName: _items[index].categoryName,
      memberName: _items[index].memberName,
    );
    return updated;
  }

  @override
  Future<void> delete(String transactionId) async {
    deleteCalls += 1;
    await _beforeWrite();
    deletedIds.add(transactionId);
    _items.removeWhere((item) => item.transaction.id == transactionId);
  }

  @override
  Future<Transaction?> findById(String transactionId) async {
    if (readError != null) {
      throw readError!;
    }
    if (missingOnRead) {
      return null;
    }
    for (final item in _items) {
      if (item.transaction.id == transactionId) {
        return item.transaction;
      }
    }
    return null;
  }

  @override
  Future<List<TransactionListItem>> listByMonth({
    required String householdId,
    required DateTime month,
    CategoryType? type,
  }) async {
    listCalls += 1;
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1, 0);

    final filtered =
        _items.where((item) {
          final tx = item.transaction;
          if (tx.householdId != householdId) {
            return false;
          }
          if (type != null && tx.type != type) {
            return false;
          }
          final day = DateTime(
            tx.occurredOn.year,
            tx.occurredOn.month,
            tx.occurredOn.day,
          );
          return !day.isBefore(start) && !day.isAfter(end);
        }).toList()..sort(
          (a, b) =>
              b.transaction.occurredOn.compareTo(a.transaction.occurredOn),
        );

    return filtered;
  }
}
