import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:naroo/data/supabase/supabase_household_member_repository.dart';

import 'support/supabase_test_server.dart';

void main() {
  test('계정 없는 구성원과 숨김 상태를 조회한다', () async {
    final client = await localSupabaseClient((request) async {
      respond(request, [
        {..._row(), 'user_id': null, 'is_hidden': true},
      ]);
    });
    final members = await SupabaseHouseholdMemberRepository(client)
        .listByHousehold('h1');
    expect(members.single.userId, isNull);
    expect(members.single.isCustom, isTrue);
    expect(members.single.isHidden, isTrue);
  });

  test('구성원 쓰기는 허용된 RPC 인자만 전송한다', () async {
    final calls = <String>[];
    final client = await localSupabaseClient((request) async {
      expect(request.method, 'POST');
      expect(
        request.headers.value('accept'),
        'application/vnd.pgrst.object+json',
      );
      calls.add(request.uri.path);
      final body = jsonDecode(await utf8.decoder.bind(request).join());
      switch (request.uri.path) {
        case '/rest/v1/rpc/create_custom_member':
          expect(body, {'target_household_id': 'h1', 'member_name': '나루'});
        case '/rest/v1/rpc/rename_custom_member':
          expect(body, {'target_member_id': 'm1', 'member_name': '새 이름'});
        case '/rest/v1/rpc/set_custom_member_hidden':
          expect(body, {'target_member_id': 'm1', 'hidden': true});
        default:
          fail('Unexpected write: ${request.uri}');
      }
      respond(request, {..._row(), 'user_id': null, 'is_hidden': true});
    });
    final repo = SupabaseHouseholdMemberRepository(client);
    expect(
      (await repo.createCustom(householdId: 'h1', name: ' 나루 ')).isCustom,
      isTrue,
    );
    await repo.renameCustom(memberId: 'm1', name: ' 새 이름 ');
    expect(
      (await repo.setCustomHidden(memberId: 'm1', isHidden: true)).isHidden,
      isTrue,
    );
    expect(calls, hasLength(3));
    await expectLater(
      repo.createCustom(householdId: 'h1', name: ' \t'),
      throwsArgumentError,
    );
    await expectLater(
      repo.renameCustom(memberId: 'm1', name: ''),
      throwsArgumentError,
    );
    expect(calls, hasLength(3));
  });

  test('구성원 RPC 권한 오류를 성공으로 처리하지 않는다', () async {
    final client = await localSupabaseClient((request) async {
      respond(request, {'message': 'denied', 'code': '42501'}, status: 403);
    });
    final repo = SupabaseHouseholdMemberRepository(client);
    for (final operation in [
      () => repo.createCustom(householdId: 'h2', name: '나루'),
      () => repo.renameCustom(memberId: 'm2', name: '나루'),
      () => repo.setCustomHidden(memberId: 'm2', isHidden: true),
    ]) {
      await expectLater(operation(), throwsA(isA<PostgrestException>()));
    }
  });

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
