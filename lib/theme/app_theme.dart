import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
      textTheme:
          _textTheme(AppColors.lightTextPrimary, AppColors.lightTextSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.lightTextPrimary,
        titleTextStyle: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w600,
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
        secondary: AppColors.accentOrange,
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
        titleTextStyle: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w600,
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
        minimumSize: const Size.fromHeight(52),
        elevation: 2,
        // тонированная тень под цвет кнопки — не плоский чёрный
        shadowColor: primary.withValues(alpha: 0.45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600, fontSize: 16),
        animationDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(
      Color primary, Color border) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600, fontSize: 16),
        animationDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme(Color primary) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Outfit — для заголовков (характерный шрифт с индивидуальностью вместо
  // системного дефолта), Plus Jakarta Sans — для текста (читаемый, но не
  // "ещё один Inter"). Отрицательный tracking на крупных заголовках и
  // положительный на мелких лейблах — по тому же принципу, что в капсах/лейблах.
  static TextTheme _textTheme(Color primary, Color secondary) {
    return TextTheme(
      headlineLarge: GoogleFonts.outfit(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: primary,
          height: 1.15,
          letterSpacing: -0.6),
      headlineMedium: GoogleFonts.outfit(
          fontSize: 21,
          fontWeight: FontWeight.w600,
          color: primary,
          height: 1.2,
          letterSpacing: -0.3),
      titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: primary,
          letterSpacing: -0.1),
      bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: primary,
          height: 1.45),
      bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: secondary,
          height: 1.45),
      // tabularFigures — рейтинги/счётчики отзывов не "прыгают" по ширине
      labelSmall: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: secondary,
        letterSpacing: 0.2,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
