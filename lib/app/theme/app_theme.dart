import 'package:flutter/material.dart';

import 'naroo_colors.dart';
import 'naroo_icons.dart';
import 'naroo_spacing.dart';
import 'naroo_text.dart';

abstract final class AppTheme {
  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: NarooColors.primary,
      onPrimary: NarooColors.onPrimary,
      primaryContainer: NarooColors.primaryLight,
      onPrimaryContainer: NarooColors.primary,
      secondary: NarooColors.primary,
      onSecondary: NarooColors.onPrimary,
      surface: NarooColors.surface,
      onSurface: NarooColors.textPrimary,
      onSurfaceVariant: NarooColors.textSecondary,
      outline: NarooColors.border,
      outlineVariant: NarooColors.border,
      error: NarooColors.error,
      onError: NarooColors.onPrimary,
      errorContainer: NarooColors.errorSurface,
      onErrorContainer: NarooColors.error,
      surfaceContainerLowest: NarooColors.surface,
      surfaceContainerLow: NarooColors.background,
      surfaceContainer: NarooColors.surfaceMuted,
      surfaceContainerHigh: NarooColors.surfaceSubtle,
      surfaceContainerHighest: NarooColors.surfaceSubtle,
    );

    const buttonText = NarooText.body;

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(NarooRadius.button),
    );

    const inputRadius = BorderRadius.all(Radius.circular(NarooRadius.input));
    const inputBorder = OutlineInputBorder(
      borderRadius: inputRadius,
      borderSide: BorderSide.none,
    );
    const inputFocusBorder = OutlineInputBorder(
      borderRadius: inputRadius,
      borderSide: BorderSide(color: NarooColors.borderFocus, width: 1.5),
    );
    const inputErrorBorder = OutlineInputBorder(
      borderRadius: inputRadius,
      borderSide: BorderSide(color: NarooColors.error),
    );
    const inputErrorFocusBorder = OutlineInputBorder(
      borderRadius: inputRadius,
      borderSide: BorderSide(color: NarooColors.error, width: 1.5),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: NarooText.fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: NarooColors.background,
      splashColor: NarooColors.primary.withValues(alpha: 0.06),
      highlightColor: NarooColors.surfaceSubtle,
      textTheme: const TextTheme(
        displaySmall: NarooText.keypad,
        headlineLarge: NarooText.hero,
        headlineMedium: NarooText.display,
        headlineSmall: NarooText.display,
        titleLarge: NarooText.display,
        titleMedium: NarooText.section,
        titleSmall: NarooText.bodySecondary,
        bodyLarge: NarooText.body,
        bodyMedium: NarooText.bodySecondary,
        bodySmall: NarooText.caption,
        labelLarge: NarooText.body,
        labelMedium: NarooText.caption,
        labelSmall: NarooText.caption,
      ),
      iconTheme: const IconThemeData(
        color: NarooColors.textPrimary,
        size: NarooIcons.action,
      ),
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (context) =>
            const Icon(NarooIcons.back, size: NarooIcons.action),
        closeButtonIconBuilder: (context) =>
            const Icon(NarooIcons.close, size: NarooIcons.action),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: NarooColors.background,
        foregroundColor: NarooColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: NarooText.appBarTitle,
        iconTheme: IconThemeData(color: NarooColors.textPrimary, size: 24),
      ),
      dividerTheme: const DividerThemeData(
        color: NarooColors.border,
        thickness: 1,
        space: 1,
      ),
      cardTheme: const CardThemeData(
        color: NarooColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(NarooRadius.card)),
          side: BorderSide(color: NarooColors.border),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: NarooColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(NarooRadius.dialog)),
        ),
        titleTextStyle: NarooText.display,
        contentTextStyle: NarooText.bodySecondary,
        actionsPadding: EdgeInsets.fromLTRB(24, 0, 24, 24),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: NarooColors.surface,
        modalBackgroundColor: NarooColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(NarooRadius.sheet),
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: NarooColors.textPrimary,
        contentTextStyle: NarooText.bodySecondary.copyWith(
          color: NarooColors.surface,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NarooRadius.input),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: NarooColors.primary,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: NarooColors.primary,
        foregroundColor: NarooColors.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: CircleBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          backgroundColor: NarooColors.primary,
          foregroundColor: NarooColors.onPrimary,
          disabledBackgroundColor: NarooColors.surfaceMuted,
          disabledForegroundColor: NarooColors.textTertiary,
          elevation: 0,
          textStyle: buttonText,
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          backgroundColor: NarooColors.surfaceMuted,
          foregroundColor: NarooColors.textPrimary,
          disabledBackgroundColor: NarooColors.surfaceMuted,
          disabledForegroundColor: NarooColors.textTertiary,
          elevation: 0,
          side: BorderSide.none,
          textStyle: buttonText,
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: NarooColors.primary,
          disabledForegroundColor: NarooColors.textTertiary,
          textStyle: buttonText,
          minimumSize: const Size(48, 48),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: NarooColors.surfaceMuted,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputFocusBorder,
        errorBorder: inputErrorBorder,
        focusedErrorBorder: inputErrorFocusBorder,
        errorStyle: NarooText.errorCaption,
        hintStyle: TextStyle(
          fontFamily: NarooText.fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: NarooColors.textTertiary,
        ),
        labelStyle: NarooText.bodySecondary,
        floatingLabelStyle: NarooText.caption,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: NarooColors.surfaceMuted,
        selectedColor: NarooColors.primaryLight,
        disabledColor: NarooColors.surfaceMuted,
        checkmarkColor: NarooColors.primary,
        showCheckmark: false,
        labelStyle: NarooText.body.copyWith(fontSize: 13, height: 18 / 13),
        secondaryLabelStyle: NarooText.body.copyWith(
          fontSize: 13,
          height: 18 / 13,
          color: NarooColors.primary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NarooRadius.chip),
        ),
        elevation: 0,
        pressElevation: 0,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return NarooColors.primaryLight;
            }
            return NarooColors.surfaceMuted;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return NarooColors.textTertiary;
            }
            if (states.contains(WidgetState.selected)) {
              return NarooColors.primary;
            }
            return NarooColors.textSecondary;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const BorderSide(color: NarooColors.primary, width: 1.5);
            }
            return const BorderSide(color: NarooColors.border);
          }),
          textStyle: WidgetStateProperty.all(NarooText.body),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(NarooRadius.input),
            ),
          ),
          minimumSize: WidgetStateProperty.all(const Size(0, 48)),
          elevation: WidgetStateProperty.all(0),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 60,
        elevation: 0,
        backgroundColor: NarooColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? NarooColors.primary : NarooColors.textTertiary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return selected ? NarooText.navSelected : NarooText.navIdle;
        }),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: NarooColors.primary,
        unselectedLabelColor: NarooColors.textTertiary,
        indicatorColor: NarooColors.primary,
        dividerColor: NarooColors.border,
        labelStyle: NarooText.body,
        unselectedLabelStyle: NarooText.bodySecondary,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: NarooColors.textSecondary,
        textColor: NarooColors.textPrimary,
        titleTextStyle: NarooText.body,
        subtitleTextStyle: NarooText.caption,
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: NarooColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(NarooRadius.dialog)),
        ),
      ),
    );
  }
}
