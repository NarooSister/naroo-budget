import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:naroo/data/supabase/supabase_household_member_repository.dart';

import 'support/supabase_test_server.dart';

void main() {
  for (final connected in [false, true]) {
    test('사용자 ID 조회는 ${connected ? '연결 정보' : '미연결'}를 반환한다', () async {
      final client = await localSupabaseClient((request) async {
        expect(request.method, 'GET');
        expect(request.uri.path, '/rest/v1/household_members');
        expect(request.uri.queryParameters['user_id'], 'eq.u1');
        respond(request, connected ? [_row()] : []);
      });
      final member = await SupabaseHouseholdMemberRepository(client)
          .findByUserId('u1');
      if (connected) {
        expect(member?.id, 'm1');
        expect(member?.householdId, 'h1');
        expect(member?.userId, 'u1');
        expect(member?.displayName, '나루');
      } else {
        expect(member, isNull);
      }
    });
  }

  test('구성원 목록은 Household로 제한하고 이름과 정렬을 유지한다', () async {
    final client = await localSupabaseClient((request) async {
      expect(request.uri.queryParameters['household_id'], 'eq.h1');
      expect(request.uri.queryParameters['order'], 'created_at.desc.nullslast');
      respond(request, [
        _row(),
        {..._row(), 'id': 'm2', 'user_id': 'u2', 'display_name': '파트너'},
      ]);
    });
    final members = await SupabaseHouseholdMemberRepository(client)
        .listByHousehold('h1');
    expect(members.map((member) => member.displayName), ['나루', '파트너']);
  });

  test('구성원 조회 오류를 미연결이나 빈 목록으로 처리하지 않는다', () async {
    final client = await localSupabaseClient((request) async {
      respond(request, {'message': 'denied', 'code': '42501'}, status: 403);
    });
    final repo = SupabaseHouseholdMemberRepository(client);
    await expectLater(
      repo.findByUserId('u1'),
      throwsA(isA<PostgrestException>()),
    );
    await expectLater(
      repo.listByHousehold('h1'),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('미설정 구성원 Repository는 조회를 거부한다', () async {
    final repo = SupabaseHouseholdMemberRepository(null);
    await expectLater(repo.findByUserId('u1'), throwsStateError);
    await expectLater(repo.listByHousehold('h1'), throwsStateError);
  });
}

Map<String, Object?> _row() => {
  'id': 'm1',
  'household_id': 'h1',
  'user_id': 'u1',
  'display_name': '나루',
};
