import 'package:flutter/material.dart';

/// App-wide premium navy design system for Peepl.
class PeeplAppTokens {
  PeeplAppTokens._();

  static const background = Color(0xFF071522);
  static const shellNavy = Color(0xFF0D2340);
  static const card = Color(0xFF102748);
  static const card0 = Color(0xFF102748);
  static const cardElevated = Color(0xFF17345C);
  static const searchField = Color(0xFF1A2F47);
  static const chipSurface = Color(0xFF132538);

  static const accentBlue = Color(0xFF2E6CFF);
  static const yellow = Color(0xFFFFC107);
  static const dealsGreen = Color(0xFF66E38D);
  static const danger = Color(0xFFFF6B6B);
  static const success = Color(0xFF66E38D);
  static const warning = Color(0xFFFFC107);

  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFC9D3E6);
  static const textMuted = Color(0x99C9D3E6);

  static const border = Color(0x14FFFFFF);
  static const glassFill = Color(0x33FFFFFF);
  static const glassBorder = Color(0x1FFFFFFF);

  static const cardRadius = 16.0;
  static const shellRadius = 24.0;

  static ThemeData buildTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: false,
      scaffoldBackgroundColor: background,
      primaryColor: shellNavy,
      canvasColor: background,
      dividerColor: border,
      colorScheme: const ColorScheme.dark(
        primary: accentBlue,
        secondary: yellow,
        surface: card,
        onPrimary: textPrimary,
        onSecondary: background,
        onSurface: textPrimary,
        error: danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: shellNavy,
        foregroundColor: textPrimary,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: border),
        ),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      iconTheme: const IconThemeData(color: textSecondary),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textSecondary),
        bodySmall: TextStyle(color: textMuted),
        titleLarge: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        labelLarge: TextStyle(color: textPrimary),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: textPrimary,
        iconColor: textSecondary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: searchField,
        hintStyle: const TextStyle(color: textMuted),
        labelStyle: const TextStyle(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentBlue, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentBlue,
          foregroundColor: textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accentBlue),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: cardElevated,
        contentTextStyle: TextStyle(color: textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: border),
        ),
        titleTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(color: textSecondary, fontSize: 14),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: card,
        modalBackgroundColor: card,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: accentBlue),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accentBlue;
          return textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accentBlue.withValues(alpha: 0.35);
          }
          return cardElevated;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accentBlue;
          return cardElevated;
        }),
        checkColor: WidgetStateProperty.all(textPrimary),
      ),
    );
  }

  static BoxDecoration shellBodyDecoration() => const BoxDecoration(
        color: background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(shellRadius)),
      );

  static BoxDecoration cardDecoration({Color? color}) => BoxDecoration(
        color: color ?? card,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: border),
      );
}
