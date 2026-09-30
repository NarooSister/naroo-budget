import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:naroo/core/supabase/supabase_initializer.dart';
import 'package:naroo/main.dart' as entrypoint;

void main() {
  testWidgets('Supabase 미설정 상태에서도 진입점이 로그인 화면을 표시한다', (tester) async {
    expect(SupabaseConfig.isConfigured, false);
    await entrypoint.main();
    await tester.pumpAndSettle();
    expect(isSupabaseReady, false);
    expect(find.widgetWithText(FilledButton, 'Google로 계속하기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
