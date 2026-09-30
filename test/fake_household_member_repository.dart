import 'package:naroo/data/models/household_member.dart';
import 'package:naroo/data/repositories/household_member_repository.dart';

class FakeHouseholdMemberRepository implements HouseholdMemberRepository {
  FakeHouseholdMemberRepository([List<HouseholdMember>? seed])
    : _items = List<HouseholdMember>.from(seed ?? const []);

  final List<HouseholdMember> _items;

  @override
  Future<HouseholdMember?> findByUserId(String userId) async {
    for (final item in _items) {
      if (item.userId == userId) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<List<HouseholdMember>> listByHousehold(String householdId) async {
    return _items
        .where((item) => item.householdId == householdId)
        .toList(growable: false);
  }
}
