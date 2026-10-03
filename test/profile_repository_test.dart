import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:naroo/data/models/profile.dart';
import 'package:naroo/data/repositories/profile_repository.dart';

import 'support/supabase_test_server.dart';

void main() {
  test('기존 Profile이 있으면 인증 사용자 ID로 조회하고 새로 생성하지 않는다', () async {
    var calls = 0;
    final client = await localSupabaseClient((request) async {
      calls++;
      expect(request.method, 'GET');
      expect(request.uri.path, '/rest/v1/profiles');
      expect(request.uri.queryParameters['id'], 'eq.u1');
      respond(request, [
        {'id': 'u1', 'display_name': '기존 이름'},
      ]);
    });
    final profile = await ProfileRepository(client).ensureProfile(_user());
    expect(profile.id, 'u1');
    expect(profile.displayName, '기존 이름');
    expect(calls, 1);
  });

  for (final entry in [
    (
      metadata: <String, dynamic>{'full_name': ' 전체 이름 ', 'name': '이름'},
      expected: '전체 이름',
    ),
    (
      metadata: <String, dynamic>{'full_name': ' ', 'name': ' 이름 '},
      expected: '이름',
    ),
    (metadata: <String, dynamic>{'name': ' '}, expected: 'u1@example.com'),
    (metadata: <String, dynamic>{}, expected: 'u1@example.com'),
  ]) {
    test('Profile이 없으면 이름 우선순위 ${entry.expected}로 생성한다', () async {
      final methods = <String>[];
      final client = await localSupabaseClient((request) async {
        methods.add(request.method);
        expect(request.uri.path, '/rest/v1/profiles');
        if (request.method == 'GET') {
          respond(request, []);
        } else {
          expect(request.method, 'POST');
          expect(jsonDecode(await utf8.decoder.bind(request).join()), {
            'id': 'u1',
            'display_name': entry.expected,
          });
          respond(request, {'id': 'u1', 'display_name': entry.expected});
        }
      });
      final profile = await ProfileRepository(client)
          .ensureProfile(_user(metadata: entry.metadata));
      expect(profile.displayName, entry.expected);
      expect(methods, ['GET', 'POST']);
    });
  }

  test('이름과 이메일이 모두 없으면 null 이름으로 생성한다', () async {
    final client = await localSupabaseClient((request) async {
      if (request.method == 'GET') {
        respond(request, []);
      } else {
        expect(jsonDecode(await utf8.decoder.bind(request).join()), {
          'id': 'u1',
          'display_name': null,
        });
        respond(request, {'id': 'u1', 'display_name': null});
      }
    });
    expect(
      (await ProfileRepository(client).ensureProfile(_user(email: null)))
          .displayName,
      null,
    );
  });

  for (final failureMethod in ['GET', 'POST']) {
    test('Profile $failureMethod 실패는 빈 Profile이나 생성 성공으로 숨기지 않는다', () async {
      final client = await localSupabaseClient((request) async {
        if (request.method == failureMethod) {
          respond(request, {'message': 'denied', 'code': '42501'}, status: 403);
        } else {
          respond(request, []);
        }
      });
      await expectLater(
        ProfileRepository(client).ensureProfile(_user()),
        throwsA(isA<PostgrestException>()),
      );
    });
  }

  test('기존 Profile의 이름 확인 여부를 구분한다', () async {
    final client = await localSupabaseClient((request) async {
      respond(request, [
        {
          'id': 'u1',
          'display_name': '확인한 이름',
          'name_confirmed_at': '2026-10-03T00:00:00Z',
        },
      ]);
    });
    final profile = await ProfileRepository(client).ensureProfile(_user());
    expect(profile.isNameConfirmed, isTrue);
    expect(
      Profile.fromJson({'id': 'u1', 'display_name': '구글 이름'}).isNameConfirmed,
      isFalse,
    );
  });

  test('이름 저장은 공백을 제거해 RPC 한 번으로 요청한다', () async {
    var calls = 0;
    final client = await localSupabaseClient((request) async {
      calls++;
      expect(request.method, 'POST');
      expect(request.uri.path, '/rest/v1/rpc/set_profile_name');
      expect(jsonDecode(await utf8.decoder.bind(request).join()), {
        'profile_name': '나루',
      });
      respond(request, {
        'id': 'u1',
        'display_name': '나루',
        'name_confirmed_at': '2026-10-03T00:00:00Z',
      });
    });
    final profile = await ProfileRepository(client).saveName('  나루 ');
    expect(profile.displayName, '나루');
    expect(profile.isNameConfirmed, isTrue);
    expect(calls, 1);
  });

  test('잘못된 이름과 서버 오류는 저장 성공으로 처리하지 않는다', () async {
    var calls = 0;
    final client = await localSupabaseClient((request) async {
      calls++;
      respond(request, {'message': 'invalid', 'code': '23514'}, status: 400);
    });
    final repository = ProfileRepository(client);
    await expectLater(repository.saveName('  '), throwsArgumentError);
    await expectLater(repository.saveName('가' * 31), throwsArgumentError);
    expect(calls, 0);
    await expectLater(
      repository.saveName('나루'),
      throwsA(isA<PostgrestException>()),
    );
    expect(calls, 1);
  });

  test('Supabase 미설정에서는 Profile 접근을 거부한다', () async {
    await expectLater(
      ProfileRepository(null).ensureProfile(_user()),
      throwsStateError,
    );
  });
}

User _user({
  Map<String, dynamic> metadata = const {},
  String? email = 'u1@example.com',
}) => User(
  id: 'u1',
  appMetadata: {},
  userMetadata: metadata,
  aud: 'authenticated',
  createdAt: '2026-09-30T00:00:00Z',
  email: email,
);
