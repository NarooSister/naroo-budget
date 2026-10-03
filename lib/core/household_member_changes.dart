import 'package:flutter_riverpod/flutter_riverpod.dart';

final householdMemberChangesProvider =
    NotifierProvider<HouseholdMemberChanges, int>(HouseholdMemberChanges.new);

class HouseholdMemberChanges extends Notifier<int> {
  @override
  int build() => 0;
  void changed() => state++;
}
