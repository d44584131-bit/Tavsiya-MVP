import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../l10n/strings.dart';
import '../../supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/place_card.dart';
import '../../widgets/place_review_card.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart' show AppLanguage;
import 'business_dashboard_screen.dart';
import 'business_place_form_screen.dart';

/// "Войти как заведение" — точка входа из профиля пользователя. Показывает
/// места, которыми управляет текущий аккаунт (place_owners), с возможностью
/// добавить новое. Тот же логин, что и обычный пользователь — разница
/// только в наборе экранов, открытых отсюда.
class BusinessScreen extends StatefulWidget {
  final AppLanguage language;
  const BusinessScreen({super.key, required this.language});

  @override
  State<BusinessScreen> createState() => _BusinessScreenState();
}

class _BusinessScreenState extends State<BusinessScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  List<PlaceCardData> _places = const [];
  Map<String, OwnedPlaceReviewStats> _stats = const {};
  int _unreadNotifications = 0;

  // Отзывы конкретного места подгружаем и показываем прямо на этом экране
  // только когда у аккаунта ровно одно заведение — не нужен лишний тап,
  // чтобы увидеть, что о нём пишут. При нескольких местах открываем их
  // отзывы через полноценный дашборд конкретного места.
  bool _isLoadingReviews = false;
  List<PlaceReviewData> _reviews = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final places = await SupabaseService.fetchOwnedPlaces();
      final stats = await SupabaseService.fetchOwnedPlacesReviewStats(
          places.map((p) => p.id).toList());
      if (!mounted) return;
      setState(() {
        _places = places;
        _stats = stats;
        _isLoading = false;
      });
      SupabaseService.fetchUnreadNotificationsCount().then((count) {
        if (mounted) setState(() => _unreadNotifications = count);
      }).catchError((_) {});
      if (places.length == 1) {
        _loadReviews(places.first.id);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadReviews(String placeId) async {
    setState(() => _isLoadingReviews = true);
    try {
      final reviews = await SupabaseService.fetchApprovedReviews(placeId,
          language: widget.language);
      if (!mounted) return;
      setState(() {
        _reviews = reviews;
        _isLoadingReviews = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingReviews = false);
    }
  }

  Future<bool> _submitReviewReply(PlaceReviewData review, String text) async {
    try {
      await SupabaseService.submitReviewReply(reviewId: review.id, text: text);
      if (mounted && _places.length == 1) _loadReviews(_places.first.id);
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s(context).replySubmitError)));
      return false;
    }
  }

  Future<bool> _editReviewReply(String replyId, String text) async {
    try {
      await SupabaseService.updateReviewReply(replyId: replyId, text: text);
      if (mounted && _places.length == 1) _loadReviews(_places.first.id);
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s(context).replySubmitError)));
      return false;
    }
  }

  Future<void> _toggleReviewHelpful(PlaceReviewData review, bool like) async {
    setState(() {
      _reviews = _reviews
          .map((r) => r.id == review.id
              ? r.copyWith(
                  isHelpfulByMe: like,
                  helpfulCount: review.helpfulCount + (like ? 1 : -1))
              : r)
          .toList();
    });
    try {
      await SupabaseService.toggleReviewHelpful(review.id, like: like);
    } catch (_) {
      if (mounted && _places.length == 1) _loadReviews(_places.first.id);
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    if (!mounted) return;
    setState(() => _unreadNotifications = 0);
  }

  Future<void> _addPlace() async {
    final created = await Navigator.of(context).push<PlaceCardData>(
      MaterialPageRoute(builder: (_) => const BusinessPlaceFormScreen()),
    );
    if (created == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s(context).businessCreatedSnackbar)),
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            BusinessDashboardScreen(place: created, language: widget.language),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _openPlace(PlaceCardData place, {int initialTab = 0}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BusinessDashboardScreen(
            place: place, language: widget.language, initialTabIndex: initialTab),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Column(
        children: [
          Expanded(child: _buildBody(theme)),
          // Тот же приём, что и в обычном нижнем меню (BottomNavBar): фон
          // заливает весь безопасный отступ снизу (жестовая панель Android),
          // а сама кнопка держится в SafeArea над системными кнопками —
          // иначе на телефонах с жестовой навигацией кнопка "Выйти" оказывалась
          // под системной панелью.
          Container(
            color: theme.cardColor,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context)
                        .popUntil((route) => route.isFirst),
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(s(context).businessExitButton),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s(context).businessModeLabel.toUpperCase(),
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.labelSmall?.color)),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                  child: Text(s(context).businessListTitle,
                      style: theme.textTheme.headlineLarge)),
              _RoundIconButton(
                icon: Icons.notifications_outlined,
                badgeCount: _unreadNotifications,
                onTap: _openNotifications,
              ),
              const SizedBox(width: 10),
              _RoundIconButton(
                icon: Icons.add_rounded,
                filled: true,
                onTap: _addPlace,
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s(context).loadErrorGeneric,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: Text(s(context).retry)),
            ],
          ),
        ),
      );
    }
    if (_places.isEmpty) {
      return Column(
        children: [
          _buildHeader(theme),
          Expanded(
            child: EmptyState(
              icon: Icons.storefront_outlined,
              title: s(context).businessEmptyTitle,
              subtitle: s(context).businessEmptySubtitle,
              action: ElevatedButton(
                  onPressed: _addPlace,
                  child: Text(s(context).businessAddPlaceButton)),
            ),
          ),
        ],
      );
    }

    final totalReviews =
        _stats.values.fold<int>(0, (sum, s) => sum + s.reviewsCount);
    final totalUnanswered =
        _stats.values.fold<int>(0, (sum, s) => sum + s.unansweredCount);
    final avgRating = totalReviews == 0
        ? 0.0
        : _stats.values.fold<double>(0, (sum, s) => sum + s.avgRating * s.reviewsCount) /
            totalReviews;
    final singlePlace = _places.length == 1 ? _places.first : null;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _buildHeader(theme),
          // Пока по всем заведениям аккаунта нет ни одного одобренного
          // отзыва, сводная карточка показывала бы только нули первым, что
          // видит владелец — до появления первых отзывов её не показываем.
          if (totalReviews > 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _DarkStatsCard(
                totalReviews: totalReviews,
                avgRating: avgRating,
                unanswered: totalUnanswered,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: _places.map((place) {
                final stats = _stats[place.id];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _OwnedPlaceCard(
                    place: place,
                    stats: stats,
                    onTap: () => _openPlace(place),
                    onTapUnanswered: stats != null && stats.unansweredCount > 0
                        ? () => _openPlace(place, initialTab: 2)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
          if (singlePlace != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(s(context).reviewsAboutPlace(singlePlace.name),
                        style: theme.textTheme.headlineMedium,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (_reviews.isNotEmpty)
                    InkWell(
                      onTap: () => _openPlace(singlePlace, initialTab: 2),
                      child: Text(
                          '${s(context).seeAll} ${_stats[singlePlace.id]?.reviewsCount ?? _reviews.length}',
                          style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: theme.colorScheme.primary)),
                    ),
                ],
              ),
            ),
            if (_isLoadingReviews)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_reviews.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text(s(context).noReviewsYet,
                    style: theme.textTheme.bodyMedium),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: _reviews
                      .map((r) => PlaceReviewCard(
                            data: r,
                            onSubmitReply: (text) => _submitReviewReply(r, text),
                            onEditReply: (replyId, text) =>
                                _editReviewReply(replyId, text),
                            onToggleHelpful: (like) =>
                                _toggleReviewHelpful(r, like),
                          ))
                      .toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Белая круглая кнопка-иконка в шапке — как в профиле пользователя, но с
/// вариантом "залитая акцентом" для основного действия ("+").
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final int badgeCount;
  final bool filled;
  final VoidCallback onTap;
  const _RoundIconButton(
      {required this.icon,
      required this.onTap,
      this.badgeCount = 0,
      this.filled = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: filled ? theme.colorScheme.primary : theme.cardColor,
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
            child: Icon(icon,
                color: filled ? Colors.white : theme.textTheme.bodyLarge?.color),
          ),
        ),
      ),
    );
  }
}

/// Тёмная карточка сводной статистики по всем заведениям аккаунта.
class _DarkStatsCard extends StatelessWidget {
  final int totalReviews;
  final double avgRating;
  final int unanswered;
  const _DarkStatsCard(
      {required this.totalReviews,
      required this.avgRating,
      required this.unanswered});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.darkChip(isDark),
        borderRadius: BorderRadius.circular(AppRadius.folder),
      ),
      child: Row(
        children: [
          Expanded(
              child: _StatColumn(
                  value: '$totalReviews', label: s(context).totalReviewsLabel)),
          _divider(),
          Expanded(
              child: _StatColumn(
                  value: avgRating.toStringAsFixed(1),
                  label: s(context).ratingLabel)),
          _divider(),
          Expanded(
            child: _StatColumn(
              value: '$unanswered',
              label: s(context).unansweredLabel,
              valueColor: unanswered > 0 ? AppColors.accentOrange : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
      width: 1, height: 32, color: Colors.white.withValues(alpha: 0.12));
}

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;
  const _StatColumn(
      {required this.value, required this.label, this.valueColor = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.unbounded(
                fontSize: 20, fontWeight: FontWeight.w800, color: valueColor)),
        const SizedBox(height: 3),
        Text(label.toUpperCase(),
            textAlign: TextAlign.center,
            style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.55))),
      ],
    );
  }
}

/// Карточка одного заведения в списке — аватар-квадрат с буквой категории,
/// название/категория/район, и снизу рейтинг + число отзывов + бейдж
/// "N без ответа", если есть неотвеченные.
class _OwnedPlaceCard extends StatelessWidget {
  final PlaceCardData place;
  final OwnedPlaceReviewStats? stats;
  final VoidCallback onTap;
  final VoidCallback? onTapUnanswered;
  const _OwnedPlaceCard(
      {required this.place,
      required this.stats,
      required this.onTap,
      this.onTapUnanswered});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppColors.categoryColor(place.category);
    final onDark = AppColors.categoryOnDark(place.category);
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(AppRadius.folder),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.folder),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.folder),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(AppRadius.field)),
                    child: Text(
                        place.name.isNotEmpty ? place.name[0].toUpperCase() : '?',
                        style: GoogleFonts.unbounded(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: onDark ? Colors.white : const Color(0xFF111111))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(place.name,
                            style: theme.textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(AppRadius.tag),
                              ),
                              child: Text(
                                  s(context).categoryLabel(place.category).toUpperCase(),
                                  style: GoogleFonts.jetBrainsMono(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: color)),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(place.district,
                                  style: theme.textTheme.labelSmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (place.status == 'pending' || place.status == 'rejected')
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (place.status == 'pending'
                                ? AppColors.accentOrange
                                : AppColors.negative)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.tag),
                      ),
                      child: Text(
                        place.status == 'pending'
                            ? s(context).pendingBadge
                            : s(context).rejectedBadge,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: place.status == 'pending'
                              ? AppColors.accentOrange
                              : AppColors.negative,
                        ),
                      ),
                    )
                  else
                    Icon(Icons.chevron_right_rounded,
                        color: theme.textTheme.labelSmall?.color),
                ],
              ),
              if (stats != null) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: theme.dividerColor),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('★ ${stats!.avgRating.toStringAsFixed(1)}',
                          style: GoogleFonts.jetBrainsMono(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: onDark ? Colors.white : const Color(0xFF111111))),
                    ),
                    const SizedBox(width: 8),
                    Text(s(context).reviewsCount(stats!.reviewsCount),
                        style: theme.textTheme.labelSmall),
                    const Spacer(),
                    if (stats!.unansweredCount > 0)
                      InkWell(
                        onTap: onTapUnanswered,
                        borderRadius: BorderRadius.circular(AppRadius.tag),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.tag),
                          ),
                          child: Text(
                              s(context).unansweredCount(stats!.unansweredCount),
                              style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary)),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
