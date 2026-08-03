import 'package:flutter/material.dart';

/// Единая система цветовых токенов Tavsiya.
/// Все экраны и компоненты должны брать цвета отсюда,
/// а не хардкодить Color(0x...) напрямую — это то, что
/// позволяет теме (day/night) переключаться без "поломок".
class AppColors {
  AppColors._();

  // --- Brand ---
  static const Color primaryLight = Color(0xFF7C4DFF); // фиолетовый акцент
  static const Color primaryDark = Color(0xFF9E7BFF); // чуть светлее/glow на тёмном фоне
  static const Color accentOrange = Color(0xFFFFA726); // звёзды рейтинга (обе темы)

  // --- Light theme ---
  static const Color lightBackground = Color(0xFFF6F3FB); // светло-сиреневый фон
  static const Color lightSurface = Color(0xFFFFFFFF); // белые карточки
  static const Color lightTextPrimary = Color(0xFF1B1B1F);
  static const Color lightTextSecondary = Color(0xFF6E6B7A);
  static const Color lightBorder = Color(0xFFE8E3F5);

  // --- Dark theme ---
  static const Color darkBackground = Color(0xFF121014); // почти чёрный
  static const Color darkSurface = Color(0xFF1E1B22); // на тон светлее фона
  static const Color darkTextPrimary = Color(0xFFF2F0F5);
  static const Color darkTextSecondary = Color(0xFFA9A5B5);
  static const Color darkBorder = Color(0xFF2C2833);

  // --- Semantic (плюсы/минусы в отзывах) ---
  static const Color positive = Color(0xFF4CAF7D);
  static const Color negative = Color(0xFFE5605A);

  /// Мягкий градиент для "шапок" карточек мест (glassmorphism-подложка).
  /// category: 'restaurant' | 'cafe' | 'park' | 'mall'
  static List<Color> headerGradient(String category, {required bool isDark}) {
    final base = switch (category) {
      'restaurant' => const [Color(0xFFFF8A65), Color(0xFF7C4DFF)],
      'cafe' => const [Color(0xFFFFB74D), Color(0xFF9575CD)],
      'park' => const [Color(0xFF66BB6A), Color(0xFF7C4DFF)],
      'mall' => const [Color(0xFF4FC3F7), Color(0xFF7C4DFF)],
      _ => const [Color(0xFF9575CD), Color(0xFF7C4DFF)],
    };
    if (!isDark) return base;
    // На тёмной теме приглушаем и добавляем "свечение" за счёт альфы
    return base.map((c) => Color.alphaBlend(Colors.black.withValues(alpha: 0.25), c)).toList();
  }
}
