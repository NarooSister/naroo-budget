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

  @override
  Future<HouseholdMember> createCustom({
    required String householdId,
    required String name,
  }) async {
    final row = await _requireClient()
        .rpc<List<Map<String, dynamic>>>(
          'create_custom_member',
          params: {
            'target_household_id': householdId,
            'member_name': _name(name),
          },
        )
        .single();
    return HouseholdMember.fromJson(row);
  }

  @override
  Future<HouseholdMember> renameCustom({
    required String memberId,
    required String name,
  }) async {
    final row = await _requireClient()
        .rpc<List<Map<String, dynamic>>>(
          'rename_custom_member',
          params: {'target_member_id': memberId, 'member_name': _name(name)},
        )
        .single();
    return HouseholdMember.fromJson(row);
  }

  @override
  Future<HouseholdMember> setCustomHidden({
    required String memberId,
    required bool isHidden,
  }) async {
    final row = await _requireClient()
        .rpc<List<Map<String, dynamic>>>(
          'set_custom_member_hidden',
          params: {'target_member_id': memberId, 'hidden': isHidden},
        )
        .single();
    return HouseholdMember.fromJson(row);
  }

  String _name(String raw) {
    final name = raw.trim();
    if (name.isEmpty) throw ArgumentError('이름을 입력해 주세요.');
    return name;
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase가 설정되지 않았습니다.');
    }
    return client;
  }
}
