import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/permission_service.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/place_card.dart';
import '../business/business_screen.dart';
import '../home/home_screen.dart';
import '../search/search_screen.dart';
import '../profile/profile_screen.dart';
import '../place/place_detail_screen.dart';
import '../review_form/review_form_screen.dart';

const _prefsPermissionsRequestedKey = 'tavsiya.permissions_requested';

/// Корневая оболочка приложения после онбординга: единая нижняя навигация
/// (Главная, Поиск, Профиль + кнопка "Добавить отзыв" по центру), которая
/// остаётся на экране всегда — переходы на Карточку места, Форму отзыва и
/// т.д. идут через вложенный Navigator внутри тела Scaffold, а не поверх
/// всего экрана, поэтому нижнее меню не пропадает при переходе вглубь.
class AppShell extends StatefulWidget {
  final AppLanguage language;
  final AppThemeMode themeMode;
  final String selectedCity;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final ValueChanged<AppThemeMode> onThemeModeChanged;
  final ValueChanged<String> onCityChanged;

  const AppShell({
    super.key,
    required this.language,
    required this.themeMode,
    required this.selectedCity,
    required this.onLanguageChanged,
    required this.onThemeModeChanged,
    required this.onCityChanged,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  int _navIndex = 0;
  bool _reviewFormActive = false;
  bool _businessModeActive = false;

  @override
  void initState() {
    super.initState();
    _maybeRequestPermissions();
  }

  Future<void> _maybeRequestPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefsPermissionsRequestedKey) ?? false) return;
    await PermissionService.requestInitialPermissions();
    await prefs.setBool(_prefsPermissionsRequestedKey, true);
  }

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

  void _openSearch() => _onTabSelected(1);

  Future<void> _openReviewForm(
      {PlaceCardData? place, ReviewDraftData? draft}) async {
    setState(() => _reviewFormActive = true);
    await _navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => ReviewFormScreen(
            preselectedPlace: place,
            initialDraft: draft,
            language: widget.language),
      ),
    );
    if (mounted) setState(() => _reviewFormActive = false);
  }

  /// Режим заведения открывается поверх той же вложенной навигации, что и
  /// остальные экраны (карточка места, форма отзыва) — поэтому нижнее меню
  /// (bottomNavigationBar Scaffold'а) скрывается на всё время, пока
  /// пользователь внутри (BusinessScreen и всё, что он откроет поверх себя),
  /// а не просто на один пуш.
  Future<void> _openBusiness() async {
    setState(() => _businessModeActive = true);
    await _navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => BusinessScreen(language: widget.language),
      ),
    );
    if (mounted) setState(() => _businessModeActive = false);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      HomeScreen(
        language: widget.language,
        onPlaceTap: _openPlace,
        onOpenSearch: _openSearch,
        selectedCity: widget.selectedCity,
        onCityChanged: widget.onCityChanged,
      ),
      SearchScreen(onPlaceTap: _openPlace),
      ProfileScreen(
        language: widget.language,
        themeMode: widget.themeMode,
        onLanguageChanged: widget.onLanguageChanged,
        onThemeModeChanged: widget.onThemeModeChanged,
        isActive: _navIndex == 2,
        onPlaceTap: _openPlace,
        onOpenDraft: (d) => _openReviewForm(draft: d),
        onOpenBusiness: _openBusiness,
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
      bottomNavigationBar: _businessModeActive
          ? null
          : BottomNavBar(
              currentIndex: _navIndex,
              reviewActive: _reviewFormActive,
              onTabSelected: _onTabSelected,
              onAddReview: () => _openReviewForm(),
            ),
    );
  }
}
