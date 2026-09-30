class HouseholdMember {
  const HouseholdMember({
    required this.id,
    required this.householdId,
    required this.userId,
    required this.displayName,
  });

  final String id;
  final String householdId;
  final String userId;
  final String displayName;

  factory HouseholdMember.fromJson(Map<String, dynamic> json) {
    return HouseholdMember(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String,
    );
  }
}
