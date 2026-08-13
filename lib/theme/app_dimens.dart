/// Шкала отступов и радиусов скругления — по дизайн-бандлу Ember.
/// Используем вместо "магических чисел" в новых/переделываемых виджетах,
/// чтобы весь продукт держался на одной сетке.
class AppSpacing {
  AppSpacing._();

  static const double s1 = 4;
  static const double s2 = 7;
  static const double s3 = 12;
  static const double s4 = 14;
  static const double s5 = 16;
  static const double s6 = 22;
  static const double s7 = 24;
  static const double s8 = 34;
  static const double s9 = 56;

  static const double screenPadX = 24;
  static const double screenPadTop = 56;
  static const double screenPadBottom = 34;
}

class AppRadius {
  AppRadius._();

  static const double tag = 7;
  static const double bubble = 16;
  static const double bubbleHero = 20;
  static const double button = 16;
  static const double card = 26;
  static const double screen = 34;
  static const double venue = 20;
  static const double venueTail = 6;
  static const double folder = 14;
  static const double field = 16;
  static const double nav = 22;
}

class AppSizes {
  AppSizes._();

  static const double controlHeight = 58; // основная кнопка
  static const double fieldHeight = 46;
  static const double navHeight = 76;
}
