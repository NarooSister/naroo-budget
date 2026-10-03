import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naroo/core/selected_month.dart';
import 'package:naroo/features/home/home_controller.dart';
import 'package:naroo/features/home/home_screen.dart';
import 'package:naroo/features/home/home_summary.dart';

import 'fake_monthly_budget_repository.dart';

void main() {
  testWidgets('홈 조회 실패 후 재시도와 앱 복귀로 최신 월 합계를 조회한다', (tester) async {
    var fail = true;
    var calls = 0;
    var budget = 1000;
    final container = ProviderContainer(
      overrides: [
        currentMonthProvider.overrideWith((ref) => DateTime(2026, 12)),
        homeSummaryProvider.overrideWith((ref) async {
          calls++;
          if (fail) throw StateError('private server error');
          return HomeSummary(
            month: DateTime(2026, 12),
            budget: FakeMonthlyBudgetRepository.budget(budget),
            items: const [],
          );
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('이 달 정보를 불러오지 못했습니다.'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('이 달 정보를 불러오지 못했습니다.'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('2026년 12월'), findsOneWidget);
    expect(find.text('1,000원 남음'), findsOneWidget);
    expect(calls, 3);
    budget = 2000;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('2,000원 남음'), findsOneWidget);
    expect(calls, 4);
    expect(tester.takeException(), isNull);
  });
}
