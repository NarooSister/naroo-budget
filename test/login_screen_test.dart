import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naroo/core/session/app_session.dart';
import 'package:naroo/features/auth/login_screen.dart';

void main() {
  testWidgets('로그인 중 중복 요청을 막고 실패 후 오류를 표시하며 재시도한다', (tester) async {
    final notifier = _LoginSession();
    await _pump(tester, notifier);
    await tester.tap(find.text('Google로 계속하기'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.byType(FilledButton));
    expect(notifier.calls, 1);
    notifier.pending.completeError(StateError('raw-secret-error'));
    await tester.pumpAndSettle();
    expect(find.text('로그인을 시작하지 못했습니다. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
    expect(find.textContaining('raw-secret-error'), findsNothing);
    notifier.pending = Completer<void>();
    await tester.tap(find.text('Google로 계속하기'));
    await tester.pump();
    expect(find.text('로그인을 시작하지 못했습니다. 잠시 후 다시 시도해 주세요.'), findsNothing);
    notifier.pending.complete();
    await tester.pumpAndSettle();
    expect(notifier.calls, 2);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  for (final fail in [false, true]) {
    testWidgets('화면이 닫힌 뒤 로그인 ${fail ? '실패' : '완료'}해도 disposed 화면을 갱신하지 않는다', (
      tester,
    ) async {
      final notifier = _LoginSession();
      await _pump(tester, notifier);
      await tester.tap(find.text('Google로 계속하기'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      if (fail) {
        notifier.pending.completeError(StateError('failed'));
      } else {
        notifier.pending.complete();
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(notifier.calls, 1);
    });
  }
}

Future<void> _pump(WidgetTester tester, _LoginSession notifier) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appSessionProvider.overrideWith(() => notifier)],
      child: const MaterialApp(home: LoginScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

class _LoginSession extends AppSessionNotifier {
  var pending = Completer<void>();
  int calls = 0;
  @override
  Future<AppSession> build() async => const AppSession.signedOut();
  @override
  Future<void> signInWithGoogle() {
    calls++;
    return pending.future;
  }
}
