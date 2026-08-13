import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_dimens.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    const primary = AppColors.primaryLight;
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: primary,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightTextPrimary,
      ),
      cardColor: AppColors.lightSurface,
      dividerColor: AppColors.lightBorder,
      textTheme:
          _textTheme(AppColors.lightTextPrimary, AppColors.lightTextSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.lightTextPrimary,
        titleTextStyle: GoogleFonts.unbounded(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: AppColors.lightTextPrimary),
      ),
      elevatedButtonTheme: _elevatedButtonTheme(primary, Colors.white),
      outlinedButtonTheme: _outlinedButtonTheme(primary, AppColors.lightBorder),
      textButtonTheme: _textButtonTheme(primary),
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
        secondary: primary,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
      ),
      cardColor: AppColors.darkSurface,
      dividerColor: AppColors.darkBorder,
      textTheme:
          _textTheme(AppColors.darkTextPrimary, AppColors.darkTextSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.darkTextPrimary,
        titleTextStyle: GoogleFonts.unbounded(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: AppColors.darkTextPrimary),
      ),
      elevatedButtonTheme:
          _elevatedButtonTheme(primary, AppColors.darkBackground),
      outlinedButtonTheme: _outlinedButtonTheme(primary, AppColors.darkBorder),
      textButtonTheme: _textButtonTheme(primary),
      useMaterial3: true,
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme(
      Color primary, Color onPrimary) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        minimumSize: const Size.fromHeight(AppSizes.controlHeight),
        elevation: 2,
        // тонированная тень под цвет кнопки — не плоский чёрный
        shadowColor: primary.withValues(alpha: 0.45),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button)),
        textStyle: GoogleFonts.montserrat(
            fontWeight: FontWeight.w800, fontSize: 17),
        animationDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(
      Color primary, Color border) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSizes.controlHeight),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button)),
        textStyle: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700, fontSize: 16),
        animationDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme(Color primary) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700, fontSize: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.folder)),
      ),
    );
  }

  // Unbounded ExtraBold — тяжёлые заголовки (фирменная "громкая" геометрия
  // вместо системного дефолта), Montserrat — весь остальной UI-текст,
  // JetBrains Mono — мелкие капс-лейблы/метки (в духе "КОФЕЙНЯ", "ШАГ 03/03").
  // Отрицательный tracking на крупных заголовках и положительный на мелких
  // моно-лейблах — по спецификации бандла Ember.
  static TextTheme _textTheme(Color primary, Color secondary) {
    return TextTheme(
      headlineLarge: GoogleFonts.unbounded(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: primary,
          height: 1.1,
          letterSpacing: -0.6),
      headlineMedium: GoogleFonts.unbounded(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          color: primary,
          height: 1.15,
          letterSpacing: -0.4),
      titleLarge: GoogleFonts.montserrat(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: primary,
          letterSpacing: -0.1),
      titleMedium: GoogleFonts.montserrat(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: primary,
          letterSpacing: -0.1),
      bodyLarge: GoogleFonts.montserrat(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: primary,
          height: 1.45),
      bodyMedium: GoogleFonts.montserrat(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: secondary,
          height: 1.45),
      labelLarge: GoogleFonts.montserrat(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: primary,
          letterSpacing: 0.1),
      labelMedium: GoogleFonts.montserrat(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: secondary,
          letterSpacing: 0.1),
      // tabularFigures — рейтинги/счётчики отзывов не "прыгают" по ширине
      labelSmall: GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: secondary,
        letterSpacing: 0.6,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
