import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF140A2B);
  static const background2 = Color(0xFF231047);
  static const surface = Color(0xFF2B1455);
  static const surface2 = Color(0xFF3A1C6C);
  static const purple = Color(0xFF7C3AED);
  static const purpleLight = Color(0xFFA855F7);
  static const gold = Color(0xFFFFC83D);
  static const orange = Color(0xFFFF8A26);
  static const cyan = Color(0xFF45D9FF);
  static const green = Color(0xFF38D996);
  static const red = Color(0xFFFF5B6E);
  static const text = Color(0xFFF9F7FF);
  static const muted = Color(0xFFB9ACD1);
  static const divider = Color(0xFF4B2B78);
}

abstract final class AppGradients {
  static const background = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.background2, AppColors.background],
  );

  static const gold = LinearGradient(
    colors: [Color(0xFFFFE07A), AppColors.orange],
  );

  static const purple = LinearGradient(
    colors: [AppColors.purpleLight, AppColors.purple],
  );

  static const cyan = LinearGradient(
    colors: [Color(0xFF6EF0FF), Color(0xFF2E83FF)],
  );
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.gold,
    secondary: AppColors.purpleLight,
    surface: AppColors.surface,
    error: AppColors.red,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Arial',
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontWeight: FontWeight.w900, color: AppColors.text),
      headlineMedium: TextStyle(fontWeight: FontWeight.w800, color: AppColors.text),
      titleLarge: TextStyle(fontWeight: FontWeight.w800, color: AppColors.text),
      titleMedium: TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
      bodyLarge: TextStyle(color: AppColors.text),
      bodyMedium: TextStyle(color: AppColors.muted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: const TextStyle(color: AppColors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.gold, width: 1.6),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surface2,
      contentTextStyle: const TextStyle(color: AppColors.text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
