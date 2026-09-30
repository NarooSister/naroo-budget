import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naroo/app/theme/app_theme.dart';
import 'package:naroo/app/theme/naroo_colors.dart';
import 'package:naroo/app/theme/naroo_widgets.dart';

void main() {
  test('light theme uses Naroo color and type tokens', () {
    final theme = AppTheme.light;

    expect(theme.useMaterial3, isTrue);
    expect(theme.textTheme.bodyLarge?.fontFamily, 'Pretendard');
    expect(theme.textTheme.headlineLarge?.fontFamily, 'Pretendard');
    expect(theme.scaffoldBackgroundColor, NarooColors.background);
    expect(theme.colorScheme.primary, NarooColors.primary);
    expect(theme.colorScheme.onPrimary, NarooColors.onPrimary);
    expect(theme.colorScheme.surface, NarooColors.surface);
    expect(theme.colorScheme.onSurface, NarooColors.textPrimary);
    expect(theme.colorScheme.error, NarooColors.error);
    expect(theme.textTheme.headlineLarge?.fontSize, 32);
    expect(theme.textTheme.headlineLarge?.fontWeight, FontWeight.w700);
    expect(theme.textTheme.headlineSmall?.fontSize, 22);
    expect(theme.textTheme.titleMedium?.fontSize, 17);
    expect(theme.textTheme.titleMedium?.fontWeight, FontWeight.w600);
    expect(theme.textTheme.bodyLarge?.fontSize, 15);
    expect(theme.textTheme.bodyLarge?.fontWeight, FontWeight.w500);
    expect(theme.textTheme.bodyMedium?.fontSize, 14);
    expect(theme.textTheme.bodySmall?.fontSize, 12);
    expect(theme.textTheme.displaySmall?.fontSize, 24);
    expect(theme.appBarTheme.backgroundColor, NarooColors.background);
    expect(theme.appBarTheme.elevation, 0);
    expect(theme.appBarTheme.scrolledUnderElevation, 0);
    expect(theme.dividerTheme.color, NarooColors.border);
    expect(
      theme.filledButtonTheme.style?.minimumSize?.resolve({}),
      const Size(64, 52),
    );
    expect(theme.navigationBarTheme.height, 60);
  });

  testWidgets('wordmark period uses the expense terracotta', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: NarooWordmark())),
    );

    final text = tester.widget<Text>(find.text('NAROO.'));
    final span = text.textSpan! as TextSpan;
    final period = span.children!.last as TextSpan;
    expect(period.text, '.');
    expect(period.style?.color, NarooColors.expense);
  });
}
