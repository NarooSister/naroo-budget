class Profile {
  const Profile({required this.id, this.displayName});

  final String id;
  final String? displayName;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      displayName: json['display_name'] as String?,
    );
  }
}
