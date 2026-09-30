import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient? _client;

  Future<Profile> ensureProfile(User user) async {
    final client = _requireClient();

    final existing = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (existing != null) {
      return Profile.fromJson(existing);
    }

    final displayName = _displayNameFor(user);
    final created = await client
        .from('profiles')
        .insert({'id': user.id, 'display_name': displayName})
        .select()
        .single();

    return Profile.fromJson(created);
  }

  String? _displayNameFor(User user) {
    final metadata = user.userMetadata;
    final fullName = metadata?['full_name'] as String?;
    if (fullName != null && fullName.trim().isNotEmpty) {
      return fullName.trim();
    }

    final name = metadata?['name'] as String?;
    if (name != null && name.trim().isNotEmpty) {
      return name.trim();
    }

    return user.email;
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase가 설정되지 않았습니다.');
    }
    return client;
  }
}
