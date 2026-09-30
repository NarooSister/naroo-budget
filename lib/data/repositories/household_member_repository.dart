import '../models/household_member.dart';

abstract class HouseholdMemberRepository {
  Future<HouseholdMember?> findByUserId(String userId);

  Future<List<HouseholdMember>> listByHousehold(String householdId);
}
