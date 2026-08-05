import 'package:flutter/material.dart';

/// Единая система цветовых токенов Tavsiya.
/// Все экраны и компоненты должны брать цвета отсюда,
/// а не хардкодить Color(0x...) напрямую — это то, что
/// позволяет теме (day/night) переключаться без "поломок".
class AppColors {
  AppColors._();

  // --- Brand ---
  // Тёмная бирюза вместо типового "фиолетово-синего" ИИ-градиента — один
  // осознанный акцент, а не смесь ярких цветов на каждом экране.
  static const Color primaryLight = Color(0xFF0E7C74);
  static const Color primaryDark =
      Color(0xFF4FD1C5); // чуть светлее/glow на тёмном фоне
  static const Color accentOrange =
      Color(0xFFE29B3F); // звёзды рейтинга (десатурировано под общий тон)

  // --- Light theme ---
  // Тёплый нейтральный фон (одна серая семья), без сиреневого оттенка.
  static const Color lightBackground = Color(0xFFF6F4F1);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF1C1C1A);
  static const Color lightTextSecondary = Color(0xFF6B6862);
  static const Color lightBorder = Color(0xFFE7E4DE);

  // --- Dark theme ---
  static const Color darkBackground =
      Color(0xFF13100E); // тёплый почти-чёрный, не сине-фиолетовый
  static const Color darkSurface = Color(0xFF1F1B18);
  static const Color darkTextPrimary = Color(0xFFF2F0EC);
  static const Color darkTextSecondary = Color(0xFFA9A499);
  static const Color darkBorder = Color(0xFF2E2925);

  // --- Semantic (плюсы/минусы в отзывах) ---
  static const Color positive = Color(0xFF3F9469);
  static const Color negative = Color(0xFFC8564F);

  /// Тень, тонированная под тон поверхности — вместо плоского чёрного
  /// withValues(alpha: ...), который выглядит генерично.
  static Color tintedShadow({required bool isDark, double opacity = 0.16}) {
    final base = isDark ? const Color(0xFF000000) : primaryLight;
    return base.withValues(alpha: opacity);
  }

  /// Тональный (одноцветный) градиент для "шапок" карточек мест — у каждой
  /// категории свой оттенок вместо всегда одинаковой смеси в фиолетовый.
  /// category: 'restaurant' | 'cafe' | 'park' | 'mall'
  static List<Color> headerGradient(String category, {required bool isDark}) {
    final base = switch (category) {
      'restaurant' => const [Color(0xFFE8815A), Color(0xFFB85A34)], // терракота
      'cafe' => const [Color(0xFFD1A24A), Color(0xFF9C7327)], // тёплый янтарь
      'park' => const [Color(0xFF5FA872), Color(0xFF2F7A48)], // лесная зелень
      'mall' => const [
          Color(0xFF2E8F87),
          Color(0xFF17635D)
        ], // бирюза (в тон primary)
      _ => const [Color(0xFF6B675F), Color(0xFF44413B)],
    };
    if (!isDark) return base;
    // На тёмной теме приглушаем и добавляем "свечение" за счёт альфы
    return base
        .map((c) => Color.alphaBlend(Colors.black.withValues(alpha: 0.25), c))
        .toList();
  }
}
