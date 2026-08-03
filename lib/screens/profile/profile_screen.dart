import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;
import '../../supabase_service.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/place_review_card.dart';
import '../auth/auth_screen.dart';

enum AppLanguage { ru, uz }

enum AppThemeMode { system, light, dark }

class MyProfileData {
  final String displayName;
  final String? bio;
  final int reviewsCount;
  final int helpfulVotesCount;
  final int savedCount;
  final int followersCount;

  const MyProfileData({
    required this.displayName,
    this.bio,
    required this.reviewsCount,
    required this.helpfulVotesCount,
    required this.savedCount,
    required this.followersCount,
  });
}

class ProfileScreen extends StatefulWidget {
  final AppLanguage language;
  final AppThemeMode themeMode;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final ValueChanged<AppThemeMode> onThemeModeChanged;

  const ProfileScreen({
    super.key,
    required this.language,
    required this.themeMode,
    required this.onLanguageChanged,
    required this.onThemeModeChanged,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 4, vsync: this);
  late final StreamSubscription<AuthState> _authSub;

  bool _isLoading = true;
  bool _hasError = false;
  MyProfileData? _profile;
  List<PlaceReviewData> _myReviews = const [];

  @override
  void initState() {
    super.initState();
    _load();
    _authSub = SupabaseService.authStateChanges.listen((_) => _load());
  }

  @override
  void dispose() {
    _authSub.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (SupabaseService.currentUser == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = false;
        _profile = null;
        _myReviews = const [];
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final results = await Future.wait([
        SupabaseService.fetchMyProfile(),
        SupabaseService.fetchMyReviews(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as MyProfileData;
        _myReviews = results[1] as List<PlaceReviewData>;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _openAuth() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
  }

  Future<void> _signOut() async {
    await SupabaseService.signOut();
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _SettingsSheet(
        language: widget.language,
        themeMode: widget.themeMode,
        onLanguageChanged: widget.onLanguageChanged,
        onThemeModeChanged: widget.onThemeModeChanged,
        isSignedIn: SupabaseService.currentUser != null,
        onSignOut: () {
          Navigator.of(context).pop();
          _signOut();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        actions: [
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: _openSettings),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (SupabaseService.currentUser == null) {
      return EmptyState(
        icon: Icons.person_outline_rounded,
        title: 'Войдите в аккаунт',
        subtitle: 'Чтобы видеть свой профиль, отзывы и сохранённые места',
        action: ElevatedButton(onPressed: _openAuth, child: const Text('Войти')),
      );
    }
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hasError || _profile == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Не удалось загрузить профиль', style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Повторить')),
            ],
          ),
        ),
      );
    }

    final profile = _profile!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 8),
              CircleAvatar(
                radius: 40,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                child: Text(
                  profile.displayName.isNotEmpty ? profile.displayName[0].toUpperCase() : '?',
                  style: theme.textTheme.headlineLarge?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 12),
              Text(profile.displayName, style: theme.textTheme.headlineMedium),
              if (profile.bio != null) ...[
                const SizedBox(height: 4),
                Text(profile.bio!, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _CounterItem(value: '${profile.reviewsCount}', label: 'Отзывов')),
                  Expanded(child: _CounterItem(value: '${profile.helpfulVotesCount}', label: 'Полезно')),
                  Expanded(child: _CounterItem(value: '${profile.savedCount}', label: 'Сохранено')),
                  Expanded(child: _CounterItem(value: '${profile.followersCount}', label: 'Подписчиков')),
                ],
              ),
              if (profile.reviewsCount > 0) ...[
                const SizedBox(height: 16),
                StatusBadge(
                  statusLabel: profile.reviewsCount >= 10 ? 'Вы эксперт' : 'Новичок',
                  currentPoints: profile.reviewsCount,
                  nextLevelPoints: 50,
                  nextLevelLabel: 'До уровня «Гуру» — ещё ${(50 - profile.reviewsCount).clamp(0, 50)} отзывов',
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.textTheme.bodyMedium?.color,
          indicatorColor: theme.colorScheme.primary,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMyReviewsTab(theme),
              _buildEmptyTab(
                icon: Icons.bookmark_border_rounded,
                title: 'Смотрите на вкладке «Сохранено»',
                subtitle: 'Все сохранённые места собраны в нижней навигации',
              ),
              _buildEmptyTab(
                icon: Icons.group_outlined,
                title: 'Нет подписок',
                subtitle: 'Подписывайтесь на других пользователей, чтобы видеть их отзывы первыми',
              ),
              _buildEmptyTab(
                icon: Icons.edit_note_rounded,
                title: 'Нет черновиков',
                subtitle: 'Незаконченные отзывы будут сохраняться здесь автоматически',
              ),
            ],
          ),
        ),
      ],
    );
  }

  static const _tabs = ['Мои отзывы', 'Сохранённое', 'Подписки', 'Черновики'];

  Widget _buildMyReviewsTab(ThemeData theme) {
    if (_myReviews.isEmpty) {
      return _buildEmptyTab(
        icon: Icons.rate_review_outlined,
        title: 'Пока нет отзывов',
        subtitle: 'Оставьте первый отзыв о месте, в котором были — это займёт меньше минуты',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: _myReviews.length,
      itemBuilder: (context, i) => PlaceReviewCard(data: _myReviews[i]),
    );
  }

  Widget _buildEmptyTab({required IconData icon, required String title, required String subtitle}) {
    return EmptyState(icon: icon, title: title, subtitle: subtitle);
  }
}

class _CounterItem extends StatelessWidget {
  final String value;
  final String label;
  const _CounterItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: theme.textTheme.titleMedium),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

/// Нижний лист настроек: язык интерфейса, тема (day/night/системная) и выход из аккаунта.
class _SettingsSheet extends StatelessWidget {
  final AppLanguage language;
  final AppThemeMode themeMode;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final ValueChanged<AppThemeMode> onThemeModeChanged;
  final bool isSignedIn;
  final VoidCallback onSignOut;

  const _SettingsSheet({
    required this.language,
    required this.themeMode,
    required this.onLanguageChanged,
    required this.onThemeModeChanged,
    required this.isSignedIn,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text('Язык интерфейса', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SegmentButton(
                  label: 'Русский',
                  selected: language == AppLanguage.ru,
                  onTap: () => onLanguageChanged(AppLanguage.ru),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SegmentButton(
                  label: "O'zbekcha",
                  selected: language == AppLanguage.uz,
                  onTap: () => onLanguageChanged(AppLanguage.uz),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Тема оформления', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SegmentButton(
                  label: 'Как в системе',
                  selected: themeMode == AppThemeMode.system,
                  onTap: () => onThemeModeChanged(AppThemeMode.system),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SegmentButton(
                  label: 'Светлая',
                  icon: Icons.light_mode_rounded,
                  selected: themeMode == AppThemeMode.light,
                  onTap: () => onThemeModeChanged(AppThemeMode.light),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SegmentButton(
                  label: 'Тёмная',
                  icon: Icons.dark_mode_rounded,
                  selected: themeMode == AppThemeMode.dark,
                  onTap: () => onThemeModeChanged(AppThemeMode.dark),
                ),
              ),
            ],
          ),
          if (isSignedIn) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onSignOut,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Выйти из аккаунта'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  const _SegmentButton({required this.label, required this.selected, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? theme.colorScheme.primary : theme.dividerColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: selected ? Colors.white : theme.textTheme.bodyLarge?.color),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : theme.textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
