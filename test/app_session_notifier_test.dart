import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:naroo/core/session/app_session.dart';
import 'package:naroo/data/models/household_member.dart';
import 'package:naroo/data/models/profile.dart';
import 'package:naroo/data/repositories/auth_repository.dart';
import 'package:naroo/data/repositories/profile_repository.dart';
import 'package:naroo/data/repository_providers.dart';

import 'fake_household_member_repository.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profiles;
  late ProviderContainer container;

  setUp(() {
    auth = FakeAuthRepository();
    profiles = FakeProfileRepository();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profiles),
        householdMemberRepositoryProvider.overrideWithValue(
          FakeHouseholdMemberRepository([_member]),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await auth.events.close();
  });

  test('세션이 없으면 Profile 조회 없이 signedOut으로 해석한다', () async {
    expect(
      (await container.read(appSessionProvider.future)).status,
      AppSessionStatus.signedOut,
    );
    expect(profiles.userIds, isEmpty);
  });

  test('연결 사용자와 미연결 사용자를 실제 Notifier에서 구분한다', () async {
    auth.current = _session('u1');
    final ready = await container.read(appSessionProvider.future);
    expect(ready.status, AppSessionStatus.ready);
    expect(ready.member?.householdId, 'h1');
    expect(ready.profile?.id, 'u1');
    auth.current = _session('u2');
    container.invalidate(appSessionProvider);
    final needsHousehold = await container.read(appSessionProvider.future);
    expect(needsHousehold.status, AppSessionStatus.needsHousehold);
    expect(needsHousehold.userId, 'u2');
    expect(needsHousehold.email, 'u2@example.com');
    expect(profiles.userIds, ['u1', 'u2']);
  });

  test('인증 이벤트로 사용자 전환과 로그아웃을 반영한다', () async {
    final sub = container.listen(appSessionProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(appSessionProvider.future);
    await _emitAndSettle(container, auth, _session('u1'));
    expect(
      container.read(appSessionProvider).requireValue.status,
      AppSessionStatus.ready,
    );
    await _emitAndSettle(container, auth, _session('u2'));
    expect(
      container.read(appSessionProvider).requireValue.status,
      AppSessionStatus.needsHousehold,
    );
    await container.read(appSessionProvider.notifier).signOut();
    await container.pump();
    expect(
      (await container.read(appSessionProvider.future)).status,
      AppSessionStatus.signedOut,
    );
  });

  test('동일 사용자 토큰 갱신은 Profile을 다시 조회하지 않는다', () async {
    auth.current = _session('u1');
    final sub = container.listen(appSessionProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(appSessionProvider.future);
    await _emitAndSettle(container, auth, auth.current);
    final before = profiles.userIds.length;
    await _emitAndSettle(container, auth, _session('u1', token: 'new-token'));
    expect(profiles.userIds.length, before);
    expect(
      container.read(appSessionProvider).requireValue.status,
      AppSessionStatus.ready,
    );
  });

  test('Profile 조회 실패는 연결된 세션으로 처리하지 않고 재시도한다', () async {
    auth.current = _session('u1');
    profiles.fail = true;
    await expectLater(
      container.read(appSessionProvider.future),
      throwsStateError,
    );
    expect(container.read(appSessionProvider).hasError, true);
    profiles.fail = false;
    container.invalidate(appSessionProvider);
    expect(
      (await container.read(appSessionProvider.future)).status,
      AppSessionStatus.ready,
    );
  });

  test('로그인 요청과 로그아웃 실패를 Repository 계약대로 전달한다', () async {
    auth.current = _session('u1');
    await container.read(appSessionProvider.future);
    final notifier = container.read(appSessionProvider.notifier);
    await notifier.signInWithGoogle();
    expect(auth.signInCalls, 1);
    auth.failSignOut = true;
    await expectLater(notifier.signOut(), throwsStateError);
    expect(
      container.read(appSessionProvider).requireValue.status,
      AppSessionStatus.ready,
    );
  });
}

const _member = HouseholdMember(
  id: 'm1',
  householdId: 'h1',
  userId: 'u1',
  displayName: '나루',
);

Session _session(String id, {String token = 'test-token'}) => Session(
  accessToken: token,
  tokenType: 'bearer',
  user: User(
    id: id,
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-09-30T00:00:00Z',
    email: '$id@example.com',
  ),
);

Future<void> _emitAndSettle(
  ProviderContainer container,
  FakeAuthRepository auth,
  Session? session,
) async {
  auth.current = session;
  auth.events.add(session);
  await container.pump();
  await container.read(appSessionProvider.future);
}

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository() : super(null);
  final events = StreamController<Session?>.broadcast();
  Session? current;
  int signInCalls = 0;
  bool failSignOut = false;

  @override
  Session? get currentSession => current;
  @override
  Stream<Session?> authSessionChanges() => events.stream;
  @override
  Future<void> signInWithGoogle() async {
    signInCalls++;
  }

  @override
  Future<void> signOut() async {
    if (failSignOut) throw StateError('sign out failed');
    current = null;
    events.add(null);
  }
}

class FakeProfileRepository extends ProfileRepository {
  FakeProfileRepository() : super(null);
  final userIds = <String>[];
  bool fail = false;
  @override
  Future<Profile> ensureProfile(User user) async {
    userIds.add(user.id);
    if (fail) throw StateError('profile failed');
    return Profile(id: user.id, displayName: '나루');
  }
}
