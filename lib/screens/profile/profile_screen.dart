import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;
import '../../l10n/strings.dart';
import '../../services/reviewer_level.dart';
import '../../supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/place_card.dart';
import '../../widgets/place_list_tile.dart';
import '../../widgets/place_review_card.dart';
import '../auth/auth_screen.dart';
import '../feedback/feedback_screen.dart';
import '../notifications/notifications_screen.dart';
import '../review_form/review_form_screen.dart' show ReviewDraftData;

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
  final bool isActive;
  final void Function(PlaceCardData place)? onPlaceTap;
  final void Function(ReviewDraftData draft)? onOpenDraft;
  final VoidCallback onOpenBusiness;
  final Listenable? reviewsChanged;

  const ProfileScreen({
    super.key,
    required this.language,
    required this.themeMode,
    required this.onLanguageChanged,
    required this.onThemeModeChanged,
    this.isActive = true,
    this.onPlaceTap,
    this.onOpenDraft,
    required this.onOpenBusiness,
    this.reviewsChanged,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 4, vsync: this);
  late final StreamSubscription<AuthState> _authSub;

  bool _isLoading = true;
  bool _isSigningOut = false;
  bool _hasError = false;
  MyProfileData? _profile;
  List<PlaceReviewData> _myReviews = const [];
  List<PlaceCardData> _savedPlaces = const [];
  List<ReviewDraftData> _drafts = const [];
  int _savedSubTab = 0; // 0 = места, 1 = отзывы
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _authSub = SupabaseService.authStateChanges.listen((_) => _load());
    widget.reviewsChanged?.addListener(_load);
  }

  @override
  void dispose() {
    widget.reviewsChanged?.removeListener(_load);
    _authSub.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Вкладка живёт внутри IndexedStack и не пересоздаётся при переключении
    // табов — подгружаем профиль и отзывы заново при каждом возврате на неё
    // (например, после публикации отзыва с другого экрана).
    if (widget.isActive && !oldWidget.isActive) {
      _load();
    }
  }

  Future<void> _load() async {
    if (SupabaseService.currentUser == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = false;
        _profile = null;
        _myReviews = const [];
        _savedPlaces = const [];
        _drafts = const [];
        _unreadNotifications = 0;
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
        SupabaseService.fetchMyReviews(language: widget.language),
        SupabaseService.fetchSavedPlaces(),
        SupabaseService.fetchMyDrafts(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as MyProfileData;
        _myReviews = results[1] as List<PlaceReviewData>;
        _savedPlaces = results[2] as List<PlaceCardData>;
        _drafts = results[3] as List<ReviewDraftData>;
        _isLoading = false;
      });
      // отдельно и не блокируя основной профиль — если таблица notifications
      // ещё не создана (миграция не применена), это не должно ронять весь экран
      SupabaseService.fetchUnreadNotificationsCount().then((count) {
        if (mounted) setState(() => _unreadNotifications = count);
      }).catchError((_) {});
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _openAuth() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AuthScreen()));
  }

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    try {
      await SupabaseService.signOut();
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
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
        onFeedback: () {
          Navigator.of(context).pop();
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const FeedbackScreen()));
        },
        onBusiness: () {
          Navigator.of(context).pop();
          widget.onOpenBusiness();
        },
      ),
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    if (!mounted) return;
    setState(() => _unreadNotifications = 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Свой заголовок с круглыми кнопками рисуем только когда профиль
    // реально загружен — на состояниях загрузки/ошибки/выхода из аккаунта
    // используем обычный AppBar, чтобы не дублировать три версии шапки.
    final showCustomHeader = !_isSigningOut &&
        SupabaseService.currentUser != null &&
        !_isLoading &&
        !_hasError &&
        _profile != null;

    return Scaffold(
      appBar: showCustomHeader
          ? null
          : AppBar(
              title: Text(s(context).profileTitle),
              actions: [
                if (SupabaseService.currentUser != null)
                  IconButton(
                    icon: Badge(
                      isLabelVisible: _unreadNotifications > 0,
                      label: Text('$_unreadNotifications'),
                      child: const Icon(Icons.notifications_outlined),
                    ),
                    onPressed: _openNotifications,
                  ),
                IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: _openSettings),
              ],
            ),
      body: SafeArea(bottom: false, child: _buildBody(theme)),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isSigningOut) {
      return const Center(child: CircularProgressIndicator());
    }
    if (SupabaseService.currentUser == null) {
      return EmptyState(
        icon: Icons.person_outline_rounded,
        title: s(context).signInPromptTitle,
        subtitle: s(context).signInPromptSubtitle,
        action: ElevatedButton(
            onPressed: _openAuth, child: Text(s(context).signInButton)),
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
              Text(s(context).profileLoadError,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: Text(s(context).retry)),
            ],
          ),
        ),
      );
    }

    final profile = _profile!;
    final level = reviewerLevelFor(profile.reviewsCount);
    final handle =
        '@${profile.displayName.toLowerCase().replaceAll(RegExp(r'\s+'), '')}';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text(s(context).profileTitle,
                          style: theme.textTheme.headlineLarge)),
                  _RoundIconButton(
                    icon: Icons.notifications_outlined,
                    badgeCount: _unreadNotifications,
                    onTap: _openNotifications,
                  ),
                  const SizedBox(width: 10),
                  _RoundIconButton(
                    icon: Icons.settings_outlined,
                    onTap: _openSettings,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(AppRadius.field),
                    ),
                    child: Text(
                      profile.displayName.isNotEmpty
                          ? profile.displayName[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.unbounded(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.displayName,
                            style: theme.textTheme.headlineMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(
                            '$handle · ${s(context).cityLabel(SupabaseService.cityKey).toUpperCase()}',
                            style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                letterSpacing: 0.4,
                                color: theme.textTheme.labelSmall?.color)),
                      ],
                    ),
                  ),
                ],
              ),
              if (profile.bio != null) ...[
                const SizedBox(height: 8),
                Text(profile.bio!, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: 10),
              _LevelPill(level: level),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                      child: _StatCard(
                          value: '${profile.reviewsCount}',
                          label: s(context).statReviews)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _StatCard(
                          value: '${profile.helpfulVotesCount}',
                          label: s(context).usefulLabel)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _StatCard(
                          value: '${profile.savedCount}',
                          label: s(context).savedLabel)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _StatCard(
                          value: '${profile.followersCount}',
                          label: s(context).followersLabel)),
                ],
              ),
              const SizedBox(height: 14),
              _DarkLevelCard(profile: profile, level: level),
            ],
          ),
        ),
        _PillTabBar(
          controller: _tabController,
          labels: [
            s(context).tabMyReviews,
            s(context).tabSaved,
            s(context).tabSubscriptions,
            s(context).tabDrafts,
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMyReviewsTab(theme),
              _buildSavedTab(theme),
              _buildEmptyTab(
                icon: Icons.group_outlined,
                title: s(context).noSubscriptionsTitle,
                subtitle: s(context).noSubscriptionsSubtitle,
              ),
              _buildDraftsTab(theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMyReviewsTab(ThemeData theme) {
    if (_myReviews.isEmpty) {
      return _buildEmptyTab(
        icon: Icons.rate_review_outlined,
        title: s(context).noReviewsTitle,
        subtitle: s(context).noReviewsSubtitle,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: _myReviews.length,
      itemBuilder: (context, i) => PlaceReviewCard(data: _myReviews[i]),
    );
  }

  Widget _buildSavedTab(ThemeData theme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: _SegmentButton(
                  label: s(context).savedSubTabPlaces,
                  selected: _savedSubTab == 0,
                  onTap: () => setState(() => _savedSubTab = 0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SegmentButton(
                  label: s(context).savedSubTabReviews,
                  selected: _savedSubTab == 1,
                  onTap: () => setState(() => _savedSubTab = 1),
                ),
              ),
            ],
          ),
        ),
        Expanded(
            child: _savedSubTab == 0
                ? _buildSavedPlacesList(theme)
                : _buildSavedReviewsEmpty()),
      ],
    );
  }

  Widget _buildSavedPlacesList(ThemeData theme) {
    if (_savedPlaces.isEmpty) {
      return EmptyState(
        icon: Icons.bookmark_border_rounded,
        title: s(context).noSavedPlacesTitle,
        subtitle: s(context).noSavedPlacesSubtitle,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        itemCount: _savedPlaces.length,
        itemBuilder: (context, i) {
          final p = _savedPlaces[i];
          return PlaceListTile(
              data: p, onTap: () => widget.onPlaceTap?.call(p));
        },
      ),
    );
  }

  Widget _buildSavedReviewsEmpty() {
    return EmptyState(
      icon: Icons.rate_review_outlined,
      title: s(context).noSavedReviewsTitle,
      subtitle: s(context).noSavedReviewsSubtitle,
    );
  }

  Widget _buildDraftsTab(ThemeData theme) {
    if (_drafts.isEmpty) {
      return EmptyState(
        icon: Icons.edit_note_rounded,
        title: s(context).noDraftsTitle,
        subtitle: s(context).noDraftsSubtitle,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: _drafts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final draft = _drafts[i];
        return _DraftTile(
          data: draft,
          onTap: () => widget.onOpenDraft?.call(draft),
          onDelete: () => _deleteDraft(draft),
        );
      },
    );
  }

  Future<void> _deleteDraft(ReviewDraftData draft) async {
    setState(() => _drafts = _drafts.where((d) => d.id != draft.id).toList());
    try {
      await SupabaseService.deleteDraft(draft.id);
    } catch (_) {
      if (mounted) _load();
    }
  }

  Widget _buildEmptyTab(
      {required IconData icon,
      required String title,
      required String subtitle}) {
    return EmptyState(icon: icon, title: title, subtitle: subtitle);
  }
}

class _DraftTile extends StatelessWidget {
  final ReviewDraftData data;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _DraftTile(
      {required this.data, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.placeName ?? s(context).draftNoPlace,
                      style: theme.textTheme.titleMedium),
                  if (data.rating != null && data.rating! > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          Icons.star_rounded,
                          size: 13,
                          color: i < data.rating!
                              ? AppColors.accentOrange
                              : theme.dividerColor,
                        ),
                      ),
                    ),
                  ],
                  if (data.text != null && data.text!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(data.text!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
            IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}

/// Белая круглая кнопка-иконка в шапке (уведомления/настройки) — с
/// красным бейджем непрочитанного, если [badgeCount] > 0.
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final int badgeCount;
  final VoidCallback onTap;
  const _RoundIconButton(
      {required this.icon, required this.onTap, this.badgeCount = 0});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Badge(
            isLabelVisible: badgeCount > 0,
            label: Text('$badgeCount'),
            child: Icon(icon, color: theme.textTheme.bodyLarge?.color),
          ),
        ),
      ),
    );
  }
}

/// Компактная моно-плашка уровня рецензента (НОВИЧОК/ЭКСПЕРТ/ГУРУ).
class _LevelPill extends StatelessWidget {
  final ReviewerLevel level;
  const _LevelPill({required this.level});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = switch (level) {
      ReviewerLevel.novice => s(context).levelNovice,
      ReviewerLevel.expert => s(context).levelExpert,
      ReviewerLevel.guru => s(context).levelGuru,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(AppRadius.bubble),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(label.toUpperCase(),
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Colors.white)),
        ],
      ),
    );
  }
}

/// Белая карточка-счётчик в ряду статистики профиля.
class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.folder),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.unbounded(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: theme.textTheme.bodyLarge?.color)),
          const SizedBox(height: 2),
          Text(label.toUpperCase(),
              textAlign: TextAlign.center,
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  letterSpacing: 0.4,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.labelSmall?.color)),
        ],
      ),
    );
  }
}

/// Тёмная карточка прогресса до следующего уровня — контрастный акцент
/// на светлом фоне профиля, как в референсе.
class _DarkLevelCard extends StatelessWidget {
  final MyProfileData profile;
  final ReviewerLevel level;
  const _DarkLevelCard({required this.profile, required this.level});

  @override
  Widget build(BuildContext context) {
    final count = profile.reviewsCount;
    final (label, target, nextLevelName) = switch (level) {
      ReviewerLevel.novice => (s(context).levelNovice, 10, s(context).levelExpert),
      ReviewerLevel.expert => (s(context).levelExpert, 50, s(context).levelGuru),
      ReviewerLevel.guru => (s(context).levelGuru, count == 0 ? 1 : count, null),
    };
    final progress = target == 0 ? 1.0 : (count / target).clamp(0.0, 1.0);
    final titleText = nextLevelName != null
        ? s(context).toLevelTitle(nextLevelName)
        : s(context).maxLevelReached;
    final subtitleText = nextLevelName != null
        ? s(context).reviewsRemaining(target - count)
        : s(context).maxLevelReached;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111010),
        borderRadius: BorderRadius.circular(AppRadius.folder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accentOrange,
                  borderRadius: BorderRadius.circular(AppRadius.bubble),
                ),
                child: Text(label.toUpperCase(),
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: Colors.white)),
              ),
              const Spacer(),
              Text('$count / $target',
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentOrange)),
            ],
          ),
          const SizedBox(height: 12),
          Text(titleText,
              style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                valueColor:
                    const AlwaysStoppedAnimation(AppColors.accentOrange),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(subtitleText.toUpperCase(),
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  letterSpacing: 0.4,
                  color: Colors.white.withValues(alpha: 0.5))),
        ],
      ),
    );
  }
}

/// Горизонтальный ряд табов-пилюль поверх TabController — тот же чёрный
/// активный/белый неактивный стиль, что и фильтр-чипы на главной.
class _PillTabBar extends StatefulWidget {
  final TabController controller;
  final List<String> labels;
  const _PillTabBar({required this.controller, required this.labels});

  @override
  State<_PillTabBar> createState() => _PillTabBarState();
}

class _PillTabBarState extends State<_PillTabBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: widget.labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final active = widget.controller.index == i;
          return Material(
            color: active ? const Color(0xFF111010) : theme.cardColor,
            borderRadius: BorderRadius.circular(AppRadius.bubble),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.bubble),
              onTap: () => widget.controller.animateTo(i),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.bubble),
                  border: active
                      ? null
                      : Border.all(color: theme.dividerColor),
                ),
                alignment: Alignment.center,
                child: Text(widget.labels[i],
                    style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: active
                            ? Colors.white
                            : theme.textTheme.bodyLarge?.color)),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Нижний лист настроек: язык интерфейса, тема (day/night/системная) и выход из аккаунта.
class _SettingsSheet extends StatefulWidget {
  final AppLanguage language;
  final AppThemeMode themeMode;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final ValueChanged<AppThemeMode> onThemeModeChanged;
  final bool isSignedIn;
  final VoidCallback onSignOut;
  final VoidCallback onFeedback;
  final VoidCallback onBusiness;

  const _SettingsSheet({
    required this.language,
    required this.themeMode,
    required this.onLanguageChanged,
    required this.onThemeModeChanged,
    required this.isSignedIn,
    required this.onSignOut,
    required this.onFeedback,
    required this.onBusiness,
  });

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  String? _version;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    }).catchError((_) {});
  }

  Widget _sectionLabel(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Text(text.toUpperCase(),
        style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: theme.textTheme.labelSmall?.color));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom + 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                      child: Text(s(context).settingsTitle,
                          style: theme.textTheme.headlineMedium)),
                  if (_version != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('v $_version',
                          style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              color: theme.textTheme.labelSmall?.color)),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _sectionLabel(context, s(context).languageSectionTitle),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _SegmentButton(
                      label: 'Русский',
                      selected: widget.language == AppLanguage.ru,
                      onTap: () => widget.onLanguageChanged(AppLanguage.ru),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SegmentButton(
                      label: "O'zbekcha",
                      selected: widget.language == AppLanguage.uz,
                      onTap: () => widget.onLanguageChanged(AppLanguage.uz),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _sectionLabel(context, s(context).themeSectionTitle),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _SegmentButton(
                      label: s(context).themeSystem,
                      selected: widget.themeMode == AppThemeMode.system,
                      onTap: () =>
                          widget.onThemeModeChanged(AppThemeMode.system),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SegmentButton(
                      label: s(context).themeLight,
                      icon: Icons.light_mode_rounded,
                      selected: widget.themeMode == AppThemeMode.light,
                      onTap: () =>
                          widget.onThemeModeChanged(AppThemeMode.light),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SegmentButton(
                      label: s(context).themeDark,
                      icon: Icons.dark_mode_rounded,
                      selected: widget.themeMode == AppThemeMode.dark,
                      onTap: () =>
                          widget.onThemeModeChanged(AppThemeMode.dark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _sectionLabel(context, s(context).accountSectionTitle),
              const SizedBox(height: 8),
              if (widget.isSignedIn) ...[
                _AccountListItem(
                  icon: Icons.storefront_outlined,
                  iconColor: theme.colorScheme.primary,
                  title: s(context).businessEntryButton,
                  subtitle: s(context).businessEntrySubtitle,
                  onTap: widget.onBusiness,
                ),
                const SizedBox(height: 10),
              ],
              _AccountListItem(
                icon: Icons.flag_outlined,
                iconColor: AppColors.accentOrange,
                title: s(context).feedbackButton,
                subtitle: s(context).feedbackSubtitle,
                onTap: widget.onFeedback,
              ),
              if (widget.isSignedIn) ...[
                const SizedBox(height: 16),
                Material(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(AppRadius.folder),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.folder),
                    onTap: widget.onSignOut,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(AppRadius.folder),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.logout_rounded,
                              size: 18, color: AppColors.negative),
                          const SizedBox(width: 8),
                          Text(s(context).signOutButton,
                              style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.negative)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Пункт списка "Аккаунт" — цветная иконка-квадрат + заголовок/подзаголовок + шеврон.
class _AccountListItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _AccountListItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(AppRadius.folder),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.folder),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.folder),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.field),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: theme.textTheme.labelSmall?.color),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  const _SegmentButton(
      {required this.label,
      required this.selected,
      required this.onTap,
      this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.primary : theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color:
                    selected ? theme.colorScheme.primary : theme.dividerColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 16,
                    color: selected
                        ? Colors.white
                        : theme.textTheme.bodyLarge?.color),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : theme.textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
