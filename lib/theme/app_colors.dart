import 'package:flutter/material.dart';

/// Единая система цветовых токенов Tavsiya.
/// Все экраны и компоненты должны брать цвета отсюда,
/// а не хардкодить Color(0x...) напрямую — это то, что
/// позволяет теме (day/night) переключаться без "поломок".
///
/// Палитра — по дизайн-бандлу Ember (тёплая бумага + один акцент —
/// коралл), а не типовой сине-фиолетовый ИИ-градиент.
class AppColors {
  AppColors._();

  // --- Brand: coral (единственный акцент во всём продукте) ---
  static const Color primaryLight = Color(0xFFFF6B57); // coral-500
  static const Color primaryDark = Color(0xFFFF7A66); // coral-400
  static const Color accentPress = Color(0xFFD9503C); // coral-700

  /// Акцент для рейтингов/бейджей — один и тот же оттенок коралла
  /// независимо от темы (даёт узнаваемый "house accent").
  static const Color accentOrange = Color(0xFFFF7A66);

  // --- Light theme (тёплая бумага) ---
  static const Color lightBackground = Color(0xFFFBFAF8); // paper-050
  static const Color lightSurface = Color(0xFFFFFFFF); // paper-000
  static const Color lightSurfaceBubble = Color(0xFFF3F1EE); // paper-200
  static const Color lightTextPrimary = Color(0xFF111111);
  static const Color lightTextSecondary = Color(0xFF6F6A62); // ink-500
  static const Color lightTextMuted = Color(0xFF9A948A); // ink-300
  static const Color lightBorder = Color(0xFFE2DED6); // paper-300

  // --- Dark theme (тёплый почти-чёрный, не сине-фиолетовый) ---
  static const Color darkBackground = Color(0xFF111010); // ink-900
  static const Color darkSurface = Color(0xFF1A1817); // ink-800
  static const Color darkSurfaceBubble = Color(0xFF1A1817); // ink-800
  static const Color darkTextPrimary = Color(0xFFF7F4EF); // paper-100
  static const Color darkTextSecondary = Color(0xFFB3ABA1); // ink-350
  static const Color darkTextMuted = Color(0xFF7D766D);
  static const Color darkBorder = Color(0xFF2B2724);

  // --- Semantic (плюсы/минусы в отзывах) ---
  static const Color positive = Color(0xFF3F9469);
  static const Color negative = Color(0xFFC8564F);

  /// Тень, тонированная под тон поверхности — вместо плоского чёрного
  /// withValues(alpha: ...), который выглядит генерично.
  static Color tintedShadow({required bool isDark, double opacity = 0.16}) {
    final base = isDark ? const Color(0xFF928A80) : primaryLight;
    return base.withValues(alpha: opacity);
  }

  /// Сплошной (не градиентный) фирменный цвет категории — как заливка
  /// VenueBubble/CategoryFolder в бандле Ember. В отличие от [headerGradient]
  /// это ровно те hex-токены cat-restaurant/cat-cafe/cat-park/cat-mall.
  static Color categoryColor(String category) => switch (category) {
        'restaurant' => const Color(0xFFFF7A66),
        'cafe' => const Color(0xFFFFC42E),
        'park' => const Color(0xFF38B96A),
        'mall' => const Color(0xFFB79CF5),
        _ => const Color(0xFF6B675F),
      };

  /// Достаточно ли тёмная заливка категории, чтобы текст поверх был белым
  /// (иначе — тёмный текст). Соответствует onDark из бандла.
  static bool categoryOnDark(String category) => switch (category) {
        'restaurant' => true,
        'cafe' => false,
        'park' => true,
        'mall' => false,
        _ => true,
      };

  /// Тональный (одноцветный) градиент для "шапок" карточек мест — цвета
  /// категорий фиксированы дизайн-системой (Ember): ресторан/кафе/парк/ТЦ.
  /// category: 'restaurant' | 'cafe' | 'park' | 'mall'
  static List<Color> headerGradient(String category, {required bool isDark}) {
    final base = switch (category) {
      'restaurant' => const [Color(0xFFFF8570), Color(0xFFD9503C)], // коралл
      'cafe' => const [Color(0xFFFFC42E), Color(0xFFC98F1F)], // янтарь
      'park' => const [Color(0xFF4FCB80), Color(0xFF237A46)], // зелень
      'mall' => const [Color(0xFFC6ADFB), Color(0xFF8A63D1)], // лаванда
      _ => const [Color(0xFF6B675F), Color(0xFF44413B)],
    };
    if (!isDark) return base;
    // На тёмной теме приглушаем и добавляем "свечение" за счёт альфы
    return base
        .map((c) => Color.alphaBlend(Colors.black.withValues(alpha: 0.25), c))
        .toList();
  }
}
