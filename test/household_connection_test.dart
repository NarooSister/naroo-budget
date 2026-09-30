import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naroo/core/session/app_session.dart';
import 'package:naroo/data/models/profile.dart';
import 'package:naroo/features/auth/household_connection_screen.dart';

void main() {
  for (final close in [false, true]) {
    testWidgets('미연결 화면 로그아웃 중 중복 요청을 막고 ${close ? '화면 종료' : '완료'}를 처리한다', (
      tester,
    ) async {
      final session = _Session();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appSessionProvider.overrideWith(() => session)],
          child: const MaterialApp(home: HouseholdConnectionScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('현재 계정: u1@example.com'), findsOneWidget);
      await tester.tap(find.text('로그아웃'));
      await tester.pump();
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      await tester.tap(find.byType(OutlinedButton));
      expect(session.calls, 1);
      if (close) await tester.pumpWidget(const SizedBox.shrink());
      session.pending.complete();
      await tester.pumpAndSettle();
      if (!close) {
        expect(
          tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
          isNotNull,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}

class _Session extends AppSessionNotifier {
  final pending = Completer<void>();
  int calls = 0;
  @override
  Future<AppSession> build() async => const AppSession.needsHousehold(
    userId: 'u1',
    email: 'u1@example.com',
    profile: Profile(id: 'u1', displayName: null),
  );
  @override
  Future<void> signOut() {
    calls++;
    return pending.future;
  }
}
