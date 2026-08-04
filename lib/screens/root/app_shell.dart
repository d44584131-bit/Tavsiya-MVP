import 'package:flutter/material.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/place_card.dart';
import '../home/home_screen.dart';
import '../search/search_screen.dart';
import '../profile/profile_screen.dart';
import '../place/place_detail_screen.dart';
import '../review_form/review_form_screen.dart';

/// Корневая оболочка приложения после онбординга: единая нижняя навигация
/// (Главная, Поиск, Профиль + кнопка "Добавить отзыв" по центру), которая
/// остаётся на экране всегда — переходы на Карточку места, Форму отзыва и
/// т.д. идут через вложенный Navigator внутри тела Scaffold, а не поверх
/// всего экрана, поэтому нижнее меню не пропадает при переходе вглубь.
class AppShell extends StatefulWidget {
  final AppLanguage language;
  final AppThemeMode themeMode;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final ValueChanged<AppThemeMode> onThemeModeChanged;

  const AppShell({
    super.key,
    required this.language,
    required this.themeMode,
    required this.onLanguageChanged,
    required this.onThemeModeChanged,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  int _navIndex = 0;

  void _openPlace(PlaceCardData place) {
    _navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => PlaceDetailScreen(
          placeId: place.id,
          language: widget.language,
          onLeaveReview: (p) => _openReviewForm(place: p),
        ),
      ),
    );
  }

  void _onTabSelected(int index) {
    // если поверх текущей вкладки был открыт другой экран (карточка места,
    // подборка и т.д.), сначала закрываем его — иначе переключение вкладки
    // происходит "под" ним и незаметно для пользователя.
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    setState(() => _navIndex = index);
  }

  Future<void> _openReviewForm({PlaceCardData? place, ReviewDraftData? draft}) {
    return _navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => ReviewFormScreen(preselectedPlace: place, initialDraft: draft, language: widget.language),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      HomeScreen(language: widget.language, onPlaceTap: _openPlace),
      SearchScreen(onPlaceTap: _openPlace),
      ProfileScreen(
        language: widget.language,
        themeMode: widget.themeMode,
        onLanguageChanged: widget.onLanguageChanged,
        onThemeModeChanged: widget.onThemeModeChanged,
        isActive: _navIndex == 2,
        onPlaceTap: _openPlace,
        onOpenDraft: (d) => _openReviewForm(draft: d),
      ),
    ];

    return Scaffold(
      // Нижнее меню непрозрачное и теперь всегда закреплено на экране —
      // без extendBody Scaffold сам резервирует под него место, поэтому
      // FAB/нижние панели вложенных экранов больше не прячутся под ним.
      body: Navigator(
        key: _navigatorKey,
        onGenerateRoute: (settings) => MaterialPageRoute(
          settings: settings,
          builder: (_) => IndexedStack(index: _navIndex, children: tabs),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _navIndex,
        onTabSelected: _onTabSelected,
        onAddReview: () => _openReviewForm(),
      ),
    );
  }
}
