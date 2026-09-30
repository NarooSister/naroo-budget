import 'package:flutter_riverpod/flutter_riverpod.dart';

final transactionChangesProvider = NotifierProvider<TransactionChanges, int>(
  TransactionChanges.new,
);

class TransactionChanges extends Notifier<int> {
  @override
  int build() => 0;
  void changed() => state++;
}
