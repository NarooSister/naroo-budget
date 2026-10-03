import '../models/household_member.dart';

abstract class HouseholdMemberRepository {
  Future<HouseholdMember?> findByUserId(String userId);

  Future<List<HouseholdMember>> listByHousehold(String householdId);

  Future<HouseholdMember> createCustom({
    required String householdId,
    required String name,
  });

  Future<HouseholdMember> renameCustom({
    required String memberId,
    required String name,
  });

  Future<HouseholdMember> setCustomHidden({
    required String memberId,
    required bool isHidden,
  });
}
