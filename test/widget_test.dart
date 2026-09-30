import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:naroo/app/app.dart';
import 'package:naroo/core/session/app_session.dart';
import 'package:naroo/data/models/household_member.dart';
import 'package:naroo/data/models/profile.dart';

const _profile = Profile(id: 'user-1', displayName: '테스트 사용자');
const _member = HouseholdMember(
  id: 'member-1',
  householdId: 'household-1',
  userId: 'user-1',
  displayName: '테스트 사용자',
);

void main() {
  testWidgets('세션이 없으면 로그인 화면을 보여준다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith(
            () => _FakeAppSessionNotifier(const AppSession.signedOut()),
          ),
        ],
        child: const NarooApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Google로 계속하기'), findsOneWidget);
    expect(find.text('NAROO.'), findsOneWidget);
  });

  testWidgets('Household 미연결이면 연결 안내 화면을 보여준다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith(
            () => _FakeAppSessionNotifier(
              const AppSession.needsHousehold(
                userId: 'user-1',
                email: 'user@example.com',
                profile: _profile,
              ),
            ),
          ),
        ],
        child: const NarooApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Household에 아직 연결되지 않았어요.'), findsOneWidget);
    expect(find.text('로그아웃'), findsOneWidget);
  });

  testWidgets('연결된 세션이면 홈 탭 navigation이 동작한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith(
            () => _FakeAppSessionNotifier(
              const AppSession.ready(
                userId: 'user-1',
                email: 'user@example.com',
                profile: _profile,
                member: _member,
              ),
            ),
          ),
        ],
        child: const NarooApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NAROO.'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, '홈'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, '내역'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, '설정'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, '내역'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '내역'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, '설정'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '설정'), findsOneWidget);
    expect(find.text('테스트 사용자'), findsOneWidget);
    expect(find.text('로그아웃'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, '홈'));
    await tester.pumpAndSettle();
    expect(find.text('NAROO.'), findsOneWidget);
  });
}

class _FakeAppSessionNotifier extends AppSessionNotifier {
  _FakeAppSessionNotifier(this._session);

  final AppSession _session;

  @override
  Future<AppSession> build() async => _session;

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async {}
}
