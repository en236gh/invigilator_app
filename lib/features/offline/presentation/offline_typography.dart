import 'package:flutter/material.dart';
import '../../../app/constants/app_colors.dart';
import '../../../app/constants/app_typography.dart';

/// A compact, shared hierarchy for every step of offline attendance.
class OfflineTypography {
  static final pageTitle = AppTypography.dashboardTitle.copyWith(
    fontSize: 28,
    height: 1.25,
    letterSpacing: -0.4,
  );
  static final heading = AppTypography.cardTitle.copyWith(height: 1.3);
  static const body = AppTypography.body;
  static const supporting = AppTypography.description;
  static final action = AppTypography.bodyStrong.copyWith(height: 1.25);

  static ThemeData theme(ThemeData base) => base.copyWith(
    textTheme: base.textTheme.copyWith(
      headlineMedium: pageTitle,
      headlineSmall: heading,
      titleMedium: heading,
      bodyLarge: body,
      bodyMedium: body,
      bodySmall: supporting,
      labelLarge: action,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style:
          base.filledButtonTheme.style?.copyWith(
            textStyle: WidgetStatePropertyAll(action),
          ) ??
          FilledButton.styleFrom(textStyle: action),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style:
          base.outlinedButtonTheme.style?.copyWith(
            textStyle: WidgetStatePropertyAll(action),
          ) ??
          OutlinedButton.styleFrom(textStyle: action),
    ),
    textButtonTheme: TextButtonThemeData(
      style:
          base.textButtonTheme.style?.copyWith(
            textStyle: WidgetStatePropertyAll(action),
          ) ??
          TextButton.styleFrom(textStyle: action),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      labelStyle: body.copyWith(color: AppColors.muted),
      floatingLabelStyle: supporting,
    ),
  );
}
