import 'package:flutter/material.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/place_card.dart';
import '../home/home_screen.dart';
import '../search/search_screen.dart';
import '../saved/saved_screen.dart';
import '../profile/profile_screen.dart';
import '../place/place_detail_screen.dart';
import '../review_form/review_form_screen.dart';

/// Корневая оболочка приложения после онбординга: единая нижняя навигация
/// поверх 4 вкладок + переходы на Карточку места и Форму отзыва.
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
  int _navIndex = 0;

  void _openPlace(BuildContext context, PlaceCardData place) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaceDetailScreen(placeId: place.id),
      ),
    );
  }

  void _openReviewForm(BuildContext context, {PlaceCardData? place}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewFormScreen(preselectedPlace: place, language: widget.language),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      HomeScreen(onPlaceTap: (p) => _openPlace(context, p)),
      SearchScreen(onPlaceTap: (p) => _openPlace(context, p)),
      SavedScreen(onPlaceTap: (p) => _openPlace(context, p)),
      ProfileScreen(
        language: widget.language,
        themeMode: widget.themeMode,
        onLanguageChanged: widget.onLanguageChanged,
        onThemeModeChanged: widget.onThemeModeChanged,
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _navIndex, children: tabs),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _navIndex,
        onTabSelected: (i) => setState(() => _navIndex = i),
        onAddReview: () => _openReviewForm(context),
      ),
    );
  }
}
