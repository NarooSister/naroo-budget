import 'package:flutter_riverpod/flutter_riverpod.dart';

final categoryChangesProvider = NotifierProvider<CategoryChanges, int>(
  CategoryChanges.new,
);

class CategoryChanges extends Notifier<int> {
  @override
  int build() => 0;
  void changed() => state++;
}
