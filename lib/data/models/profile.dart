class Profile {
  const Profile({
    required this.id,
    this.displayName,
    this.isNameConfirmed = true,
  });

  final String id;
  final String? displayName;
  final bool isNameConfirmed;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      displayName: json['display_name'] as String?,
      isNameConfirmed: json['name_confirmed_at'] != null,
    );
  }
}
