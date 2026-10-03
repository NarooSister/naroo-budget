import 'package:naroo/data/models/household_member.dart';
import 'package:naroo/data/repositories/household_member_repository.dart';

class FakeHouseholdMemberRepository implements HouseholdMemberRepository {
  FakeHouseholdMemberRepository([List<HouseholdMember>? seed])
    : _items = List<HouseholdMember>.from(seed ?? const []);

  final List<HouseholdMember> _items;
  Object? writeError;
  Duration delay = Duration.zero;
  int writes = 0;

  Future<void> _beforeWrite() async {
    writes++;
    await Future<void>.delayed(delay);
    if (writeError != null) throw writeError!;
  }

  @override
  Future<HouseholdMember> createCustom({
    required String householdId,
    required String name,
  }) async {
    await _beforeWrite();
    final member = HouseholdMember(
      id: 'custom-${_items.length}',
      householdId: householdId,
      userId: null,
      displayName: name.trim(),
    );
    _items.add(member);
    return member;
  }

  @override
  Future<HouseholdMember> renameCustom({
    required String memberId,
    required String name,
  }) async {
    await _beforeWrite();
    return _replace(memberId, name: name.trim());
  }

  @override
  Future<HouseholdMember> setCustomHidden({
    required String memberId,
    required bool isHidden,
  }) async {
    await _beforeWrite();
    return _replace(memberId, hidden: isHidden);
  }

  HouseholdMember _replace(String id, {String? name, bool? hidden}) {
    final index = _items.indexWhere((item) => item.id == id && item.isCustom);
    if (index < 0) throw StateError('Custom member not found');
    final old = _items[index];
    return _items[index] = HouseholdMember(
      id: old.id,
      householdId: old.householdId,
      userId: null,
      displayName: name ?? old.displayName,
      isHidden: hidden ?? old.isHidden,
    );
  }

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
