import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    const primary = AppColors.primaryLight;
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: AppColors.accentOrange,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightTextPrimary,
      ),
      cardColor: AppColors.lightSurface,
      dividerColor: AppColors.lightBorder,
      textTheme: _textTheme(AppColors.lightTextPrimary, AppColors.lightTextSecondary),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.lightTextPrimary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      useMaterial3: true,
    );
  }

  static ThemeData dark() {
    const primary = AppColors.primaryDark;
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: AppColors.accentOrange,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
      ),
      cardColor: AppColors.darkSurface,
      dividerColor: AppColors.darkBorder,
      textTheme: _textTheme(AppColors.darkTextPrimary, AppColors.darkTextSecondary),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.darkTextPrimary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: AppColors.darkBackground,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          // лёгкое "свечение" кнопки на тёмной теме имитируем через shadow в обёртке-виджете
        ),
      ),
      useMaterial3: true,
    );
  }

  static TextTheme _textTheme(Color primary, Color secondary) {
    return TextTheme(
      headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: primary, height: 1.2),
      headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: primary, height: 1.25),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: primary),
      bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: primary, height: 1.4),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: secondary, height: 1.4),
      labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: secondary),
    );
  }
}
