import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/strings.dart';
import '../../services/share_service.dart';
import '../../supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/place_card.dart';
import '../../widgets/place_review_card.dart';
import '../../widgets/photo_viewer_screen.dart';
import '../../widgets/auth_required_dialog.dart';
import '../profile/profile_screen.dart' show AppLanguage;

class PlaceDetailData {
  final String id;
  final String name;
  final String category; // 'restaurant' | 'cafe' | 'park' | 'mall'
  final String? description;
  final String? address;
  final String district;
  final String? phone;
  final String? website;
  final String? instagram;
  final String? priceLevel; // 'budget' | 'mid' | 'mid_high' | 'high'
  final bool isVerified;
  final double rating;
  final int reviewsCount;
  final String? status; // 'pending' | 'rejected' | null (= approved)
  final bool isChain; // сеть заведений — несколько филиалов у одного профиля
  final List<String> branches; // адреса филиалов, заполнено только у сетей

  const PlaceDetailData({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    this.address,
    required this.district,
    this.phone,
    this.website,
    this.instagram,
    this.priceLevel,
    required this.isVerified,
    required this.rating,
    required this.reviewsCount,
    this.status,
    this.isChain = false,
    this.branches = const [],
  });

  static const _priceLevelLabels = {
    'budget': '\$',
    'mid': '\$\$',
    'mid_high': '\$\$\$',
    'high': '\$\$\$\$',
  };

  String get priceLevelLabel => _priceLevelLabels[priceLevel] ?? '—';
}

class PlaceDetailScreen extends StatefulWidget {
  final String placeId;
  final AppLanguage language;
  final Future<void> Function(PlaceCardData place) onLeaveReview;
  const PlaceDetailScreen(
      {super.key,
      required this.placeId,
      required this.language,
      required this.onLeaveReview});

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 4, vsync: this);
  final _photoPageController = PageController();
  int _photoPageIndex = 0;
  bool _aboutExpanded = false;

  bool _isLoading = true;
  String? _error;
  PlaceDetailData? _place;
  List<PlaceReviewData> _reviews = const [];
  List<String> _officialPhotos = const [];
  bool _isSaved = false;
  bool _isTogglingSave = false;

  /// Фото, приложенные посетителями к своим отзывам — остаются только в
  /// отзывах и во вкладке "Фото", не смешиваются с официальными фото места
  /// (_officialPhotos), которые показываются в карусели шапки.
  List<String> get _allPhotos => _reviews.expand((r) => r.photoUrls).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _photoPageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        SupabaseService.fetchPlaceById(widget.placeId),
        SupabaseService.fetchApprovedReviews(widget.placeId,
            language: widget.language),
        SupabaseService.isPlaceSaved(widget.placeId),
        SupabaseService.fetchPlacePhotos(widget.placeId),
      ]);
      if (!mounted) return;
      setState(() {
        _place = results[0] as PlaceDetailData;
        _reviews = results[1] as List<PlaceReviewData>;
        _isSaved = results[2] as bool;
        _officialPhotos = results[3] as List<String>;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = s(context).placeLoadError;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleSaved() async {
    if (!await ensureAuthenticated(
        context, s(context).authRequiredActionSave)) {
      return;
    }
    if (!mounted) return;
    final next = !_isSaved;
    setState(() {
      _isSaved = next;
      _isTogglingSave = true;
    });
    try {
      await SupabaseService.toggleSavedPlace(widget.placeId, save: next);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaved = !next);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s(context).saveError)),
      );
    } finally {
      if (mounted) setState(() => _isTogglingSave = false);
    }
  }

  Future<void> _toggleReviewHelpful(PlaceReviewData review, bool like) async {
    if (!await ensureAuthenticated(context, s(context).authRequiredActionLike)) {
      return;
    }
    if (!mounted) return;
    final index = _reviews.indexWhere((r) => r.id == review.id);
    if (index == -1) return;
    setState(() {
      _reviews[index] = review.copyWith(
        isHelpfulByMe: like,
        helpfulCount: review.helpfulCount + (like ? 1 : -1),
      );
    });
    try {
      await SupabaseService.toggleReviewHelpful(review.id, like: like);
    } catch (_) {
      if (!mounted) return;
      setState(() => _reviews[index] = review);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s(context).likeError)));
    }
  }

  Future<bool> _submitReviewReply(PlaceReviewData review, String text) async {
    if (!await ensureAuthenticated(context, s(context).authRequiredActionReply)) {
      return false;
    }
    if (!mounted) return false;
    try {
      await SupabaseService.submitReviewReply(reviewId: review.id, text: text);
      if (mounted) _load();
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s(context).replySubmitError)));
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _place == null) {
      return Scaffold(
        appBar: AppBar(
            leading: BackButton(onPressed: () => Navigator.maybePop(context))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error ?? s(context).placeNotFound,
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _load, child: Text(s(context).retry)),
              ],
            ),
          ),
        ),
      );
    }

    final place = _place!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await widget.onLeaveReview(_toCardData(place));
          // после публикации отзыва подгружаем карточку места заново, чтобы
          // новый отзыв сразу появился в списке, не дожидаясь ручного refresh
          if (mounted) _load();
        },
        icon: const Icon(Icons.rate_review_rounded),
        label: Text(s(context).leaveReview),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            leading: _CircleIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.maybePop(context)),
            actions: [
              _CircleIconButton(
                  icon: Icons.share_rounded, onTap: () => _sharePlace(place)),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (_officialPhotos.isEmpty)
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: AppColors.headerGradient(place.category,
                              isDark: isDark),
                        ),
                      ),
                    )
                  else
                    PageView.builder(
                      controller: _photoPageController,
                      onPageChanged: (i) => setState(() => _photoPageIndex = i),
                      itemCount: _officialPhotos.length,
                      itemBuilder: (context, i) => Image.network(
                        _officialPhotos[i],
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                                ? child
                                : Container(
                                    color: theme.cardColor,
                                    child: const Center(
                                        child: CircularProgressIndicator())),
                        errorBuilder: (context, error, stack) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: AppColors.headerGradient(place.category,
                                  isDark: isDark),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // затемнение снизу, чтобы бейдж/иконки были читаемы на любом фото
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.35)
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_officialPhotos.length > 1)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _officialPhotos.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: i == _photoPageIndex ? 16 : 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(
                                  alpha: i == _photoPageIndex ? 0.95 : 0.5),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (place.isVerified)
                    Positioned(
                      top: 60,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_rounded,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(s(context).verifiedBadge,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name, style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 16, color: AppColors.accentOrange),
                      const SizedBox(width: 4),
                      Text(place.rating.toStringAsFixed(1),
                          style: theme.textTheme.titleMedium),
                      const SizedBox(width: 4),
                      Text(
                          '(${s(context).reviewsCount(place.reviewsCount)}) · ${place.district}',
                          style: theme.textTheme.labelSmall),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildQuickActions(theme, place),
                  const SizedBox(height: 20),
                  _buildStatsRow(place),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(_tabController, [
              s(context).tabOverview,
              s(context).tabReviews,
              s(context).tabPhotos,
              s(context).tabInfo,
            ]),
          ),
          SliverFillRemaining(
            hasScrollBody: true,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(theme, place),
                _buildReviewsTab(theme),
                _buildPhotosTab(theme, place),
                _buildInfoTab(theme, place),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PlaceCardData _toCardData(PlaceDetailData d) => PlaceCardData(
        id: d.id,
        name: d.name,
        category: d.category,
        rating: d.rating,
        reviewsCount: d.reviewsCount,
        district: d.district,
      );

  Widget _buildQuickActions(ThemeData theme, PlaceDetailData place) {
    return Row(
      children: [
        _QuickAction(
            icon: Icons.call_rounded,
            label: s(context).callAction,
            onTap: () {}),
        _QuickAction(
            icon: Icons.directions_rounded,
            label: s(context).routeAction,
            onTap: () => _openRoute(place)),
        _QuickAction(
            icon: Icons.language_rounded,
            label: s(context).websiteAction,
            onTap: () => _openWebsite(place)),
        _QuickAction(
            icon: Icons.camera_alt_rounded,
            label: s(context).instagramAction,
            onTap: () => _openInstagram(place)),
        _QuickAction(
          icon:
              _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          label: s(context).saveAction,
          active: _isSaved,
          loading: _isTogglingSave,
          onTap: _isTogglingSave ? null : _toggleSaved,
        ),
      ],
    );
  }

  Widget _buildStatsRow(PlaceDetailData place) {
    return Row(
      children: [
        Expanded(
            child: StatTile(
                icon: Icons.star_rounded,
                value: place.rating.toStringAsFixed(1),
                label: s(context).statRating)),
        const SizedBox(width: 10),
        Expanded(
            child: StatTile(
                icon: Icons.forum_rounded,
                value: '${place.reviewsCount}',
                label: s(context).statReviews)),
        const SizedBox(width: 10),
        Expanded(
            child: StatTile(
                icon: Icons.photo_camera_rounded,
                value: '${_allPhotos.length}',
                label: s(context).statPhotos)),
        const SizedBox(width: 10),
        Expanded(
            child: StatTile(
                icon: Icons.payments_rounded,
                value: place.priceLevelLabel,
                label: s(context).statPrice)),
      ],
    );
  }

  Widget _buildOverviewTab(ThemeData theme, PlaceDetailData place) {
    final about = place.description ?? s(context).noDescription;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s(context).aboutTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: Text(
              about,
              maxLines: _aboutExpanded ? null : 3,
              overflow:
                  _aboutExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (place.description != null && place.description!.length > 140)
            GestureDetector(
              onTap: () => setState(() => _aboutExpanded = !_aboutExpanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _aboutExpanded ? s(context).collapse : s(context).readMore,
                  style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(s(context).recentReviewsShort,
                  style: theme.textTheme.titleMedium),
              TextButton(
                onPressed: () => _tabController.animateTo(1),
                child: Text(s(context).seeAll),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_reviews.isEmpty)
            Text(s(context).noReviewsYet, style: theme.textTheme.bodyMedium)
          else
            ..._reviews.take(2).map((r) => PlaceReviewCard(data: r)),
        ],
      ),
    );
  }

  Widget _buildReviewsTab(ThemeData theme) {
    if (_reviews.isEmpty) {
      return Center(
        child: Text(s(context).noReviewsYet, style: theme.textTheme.bodyMedium),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: _reviews.length,
      itemBuilder: (context, i) => PlaceReviewCard(
        data: _reviews[i],
        onToggleHelpful: (like) => _toggleReviewHelpful(_reviews[i], like),
        onSubmitReply: (text) => _submitReviewReply(_reviews[i], text),
      ),
    );
  }

  Widget _buildPhotosTab(ThemeData theme, PlaceDetailData place) {
    if (_allPhotos.isEmpty) {
      return Center(
        child: Text(s(context).noPhotosYet, style: theme.textTheme.bodyMedium),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _allPhotos.length,
      itemBuilder: (context, i) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openPhotoViewer(i),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            _allPhotos[i],
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : Container(color: theme.dividerColor),
            errorBuilder: (context, error, stack) => Container(
              color: theme.dividerColor,
              child: Icon(Icons.broken_image_rounded,
                  color: theme.textTheme.bodyMedium?.color),
            ),
          ),
        ),
      ),
    );
  }

  void _sharePlace(PlaceDetailData place) {
    ShareService.sharePlace(
        placeId: place.id, placeName: place.name, language: widget.language);
  }

  void _showNotSpecified() {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s(context).notSpecified)));
  }

  Future<void> _launch(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s(context).linkOpenError)));
    }
  }

  Future<void> _openWebsite(PlaceDetailData place) async {
    final website = place.website?.trim();
    if (website == null || website.isEmpty) {
      _showNotSpecified();
      return;
    }
    final normalized =
        website.startsWith('http://') || website.startsWith('https://')
            ? website
            : 'https://$website';
    final uri = Uri.tryParse(normalized);
    if (uri == null) return;
    await _launch(uri);
  }

  Future<void> _openInstagram(PlaceDetailData place) async {
    final instagram = place.instagram?.trim();
    if (instagram == null || instagram.isEmpty) {
      _showNotSpecified();
      return;
    }
    final handle = instagram.replaceFirst(RegExp(r'^@'), '');
    final target =
        handle.startsWith('http') ? handle : 'https://instagram.com/$handle';
    final uri = Uri.tryParse(target);
    if (uri == null) return;
    await _launch(uri);
  }

  Future<void> _openRoute(PlaceDetailData place) async {
    final address = place.address?.trim();
    if (address == null || address.isEmpty) {
      _showNotSpecified();
      return;
    }
    final query =
        Uri.encodeComponent('$address, ${place.district}, ${s(context).cityName}');
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final selected = await showModalBottomSheet<Uri>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.map_rounded),
              title: Text(s(context).routeGoogleMaps),
              onTap: () => Navigator.pop(
                context,
                Uri.parse(
                    'https://www.google.com/maps/search/?api=1&query=$query'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.map_rounded),
              title: Text(s(context).routeYandexMaps),
              onTap: () => Navigator.pop(
                context,
                Uri.parse('https://yandex.ru/maps/?text=$query'),
              ),
            ),
            if (isIOS)
              ListTile(
                leading: const Icon(Icons.map_rounded),
                title: Text(s(context).routeAppleMaps),
                onTap: () => Navigator.pop(
                  context,
                  Uri.parse('https://maps.apple.com/?q=$query'),
                ),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    await _launch(selected);
  }

  void _openPhotoViewer(int index) {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          PhotoViewerScreen(photos: _allPhotos, initialIndex: index),
    ));
  }

  Widget _buildInfoTab(ThemeData theme, PlaceDetailData place) {
    final addressValue = place.isChain && place.branches.isNotEmpty
        ? place.branches.join('\n')
        : place.address ?? s(context).notSpecified;
    final rows = [
      (Icons.place_rounded, s(context).infoAddress, addressValue),
      (
        Icons.phone_rounded,
        s(context).infoPhone,
        place.phone ?? s(context).notSpecified
      ),
      (
        Icons.language_rounded,
        s(context).infoWebsite,
        place.website ?? s(context).notSpecified
      ),
      (
        Icons.camera_alt_rounded,
        s(context).infoInstagram,
        place.instagram ?? s(context).notSpecified
      ),
      (Icons.payments_rounded, s(context).infoAvgCheck, place.priceLevelLabel),
    ];
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: rows.length,
      separatorBuilder: (_, __) =>
          Divider(height: 24, color: theme.dividerColor),
      itemBuilder: (context, i) {
        final (icon, label, value) = rows[i];
        return Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.labelSmall),
                  Text(value, style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool loading;
  final VoidCallback? onTap;
  const _QuickAction(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.active = false,
      this.loading = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        active ? theme.colorScheme.primary : theme.textTheme.bodyLarge?.color;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: active
                      ? theme.colorScheme.primary.withValues(alpha: 0.12)
                      : theme.cardColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.dividerColor),
                ),
                child: loading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: color),
                      )
                    : Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(label, style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}


/// Табы с плавным анимированным underline (встроено в TabBar через indicator).
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController controller;
  final List<String> tabs;
  _TabBarDelegate(this.controller, this.tabs);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: TabBar(
        controller: controller,
        isScrollable: false,
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: theme.textTheme.bodyMedium?.color,
        indicatorColor: theme.colorScheme.primary,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        tabs: tabs.map((t) => Tab(text: t)).toList(),
      ),
    );
  }

  @override
  double get maxExtent => 48;
  @override
  double get minExtent => 48;
  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}
