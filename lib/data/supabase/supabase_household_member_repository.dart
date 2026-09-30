import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/household_member.dart';
import '../repositories/household_member_repository.dart';

class SupabaseHouseholdMemberRepository implements HouseholdMemberRepository {
  SupabaseHouseholdMemberRepository(this._client);

  final SupabaseClient? _client;

  @override
  Future<HouseholdMember?> findByUserId(String userId) async {
    final client = _requireClient();

    final row = await client
        .from('household_members')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return HouseholdMember.fromJson(row);
  }

  @override
  Future<List<HouseholdMember>> listByHousehold(String householdId) async {
    final client = _requireClient();

    final rows = await client
        .from('household_members')
        .select()
        .eq('household_id', householdId)
        .order('created_at');

    return rows.map(HouseholdMember.fromJson).toList(growable: false);
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase가 설정되지 않았습니다.');
    }
    return client;
  }
}
