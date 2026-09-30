import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:naroo/data/repositories/auth_repository.dart';

import 'support/supabase_test_server.dart';

void main() {
  test('설정이 없으면 signedOut이며 인증 요청을 거절한다', () async {
    final repository = AuthRepository(null);
    expect(repository.isConfigured, false);
    expect(repository.currentSession, isNull);
    expect(await repository.authSessionChanges().first, isNull);
    await expectLater(repository.signInWithGoogle(), throwsStateError);
    await expectLater(repository.signOut(), throwsStateError);
  });

  for (final status in [204, 400]) {
    test('실제 SDK 세션과 로그아웃 이벤트, HTTP $status 결과를 전달한다', () async {
      var calls = 0;
      final client = await localSupabaseClient((request) async {
        calls++;
        expect(request.method, 'POST');
        expect(request.uri.path, '/auth/v1/logout');
        expect(request.uri.queryParameters['scope'], 'local');
        expect(
          request.headers.value('authorization'),
          'Bearer ${_session().accessToken}',
        );
        respond(request, {'msg': 'logout failed'}, status: status);
      });
      final repository = AuthRepository(client);
      final events = <Session?>[];
      final subscription = repository.authSessionChanges().listen(events.add);
      addTearDown(subscription.cancel);
      expect(repository.isConfigured, true);
      expect(repository.currentSession, isNull);
      await client.auth.recoverSession(jsonEncode(_session().toJson()));
      expect(repository.currentSession?.user.id, 'u1');
      if (status == 204) {
        await repository.signOut();
      } else {
        await expectLater(repository.signOut(), throwsA(isA<AuthException>()));
      }
      await Future<void>.delayed(Duration.zero);
      // The SDK clears local state before the remote logout request.
      expect(repository.currentSession, isNull);
      expect(events.any((session) => session?.user.id == 'u1'), true);
      expect(events.last, isNull);
      expect(calls, 1);
    });
  }
}

Session _session() => Session(
  accessToken: 'test-access-token',
  refreshToken: 'test-refresh-token',
  tokenType: 'bearer',
  expiresIn: 3600,
  user: User(
    id: 'u1',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-09-30T00:00:00Z',
  ),
);
