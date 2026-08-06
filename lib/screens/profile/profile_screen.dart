import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;
import '../../l10n/strings.dart';
import '../../supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/place_card.dart';
import '../../widgets/place_list_tile.dart';
import '../../widgets/place_review_card.dart';
import '../auth/auth_screen.dart';
import '../business/business_screen.dart';
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

  const ProfileScreen({
    super.key,
    required this.language,
    required this.themeMode,
    required this.onLanguageChanged,
    required this.onThemeModeChanged,
    this.isActive = true,
    this.onPlaceTap,
    this.onOpenDraft,
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
  }

  @override
  void dispose() {
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
        SupabaseService.fetchUnreadNotificationsCount(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as MyProfileData;
        _myReviews = results[1] as List<PlaceReviewData>;
        _savedPlaces = results[2] as List<PlaceCardData>;
        _drafts = results[3] as List<ReviewDraftData>;
        _unreadNotifications = results[4] as int;
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
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AuthScreen()));
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
        onFeedback: () {
          Navigator.of(context).pop();
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const FeedbackScreen()));
        },
        onBusiness: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => BusinessScreen(language: widget.language)));
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

    return Scaffold(
      appBar: AppBar(
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
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 8),
              CircleAvatar(
                radius: 40,
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.15),
                child: Text(
                  profile.displayName.isNotEmpty
                      ? profile.displayName[0].toUpperCase()
                      : '?',
                  style: theme.textTheme.headlineLarge
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 12),
              Text(profile.displayName, style: theme.textTheme.headlineMedium),
              if (profile.bio != null) ...[
                const SizedBox(height: 4),
                Text(profile.bio!,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                      child: _CounterItem(
                          value: '${profile.reviewsCount}',
                          label: s(context).statReviews)),
                  Expanded(
                      child: _CounterItem(
                          value: '${profile.helpfulVotesCount}',
                          label: s(context).usefulLabel)),
                  Expanded(
                      child: _CounterItem(
                          value: '${profile.savedCount}',
                          label: s(context).savedLabel)),
                  Expanded(
                      child: _CounterItem(
                          value: '${profile.followersCount}',
                          label: s(context).followersLabel)),
                ],
              ),
              if (profile.reviewsCount > 0) ...[
                const SizedBox(height: 16),
                StatusBadge(
                  statusLabel: profile.reviewsCount >= 10
                      ? s(context).expertBadge
                      : s(context).noviceBadge,
                  currentPoints: profile.reviewsCount,
                  nextLevelPoints: 50,
                  nextLevelLabel: s(context)
                      .toGuruLevel((50 - profile.reviewsCount).clamp(0, 50)),
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
          tabs: [
            s(context).tabMyReviews,
            s(context).tabSaved,
            s(context).tabSubscriptions,
            s(context).tabDrafts,
          ].map((t) => Tab(text: t)).toList(),
        ),
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
              decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text(s(context).languageSectionTitle,
              style: theme.textTheme.titleMedium),
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
          Text(s(context).themeSectionTitle,
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SegmentButton(
                  label: s(context).themeSystem,
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
                  label: s(context).themeLight,
                  icon: Icons.light_mode_rounded,
                  selected: themeMode == AppThemeMode.light,
                  onTap: () => onThemeModeChanged(AppThemeMode.light),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SegmentButton(
                  label: s(context).themeDark,
                  icon: Icons.dark_mode_rounded,
                  selected: themeMode == AppThemeMode.dark,
                  onTap: () => onThemeModeChanged(AppThemeMode.dark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (isSignedIn) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onBusiness,
                icon: const Icon(Icons.storefront_outlined),
                label: Text(s(context).businessEntryButton),
              ),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onFeedback,
              icon: const Icon(Icons.flag_outlined),
              label: Text(s(context).feedbackButton),
            ),
          ),
          if (isSignedIn) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onSignOut,
                icon: const Icon(Icons.logout_rounded),
                label: Text(s(context).signOutButton),
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
