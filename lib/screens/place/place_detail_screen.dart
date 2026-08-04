import 'package:flutter/material.dart';
import '../../l10n/strings.dart';
import '../../supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/place_card.dart';
import '../../widgets/place_review_card.dart';
import '../auth/auth_screen.dart';
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
  final String? priceLevel; // 'budget' | 'mid' | 'mid_high' | 'high'
  final bool isVerified;
  final double rating;
  final int reviewsCount;
  final int photosCount;

  const PlaceDetailData({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    this.address,
    required this.district,
    this.phone,
    this.website,
    this.priceLevel,
    required this.isVerified,
    required this.rating,
    required this.reviewsCount,
    required this.photosCount,
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
  const PlaceDetailScreen({super.key, required this.placeId, required this.language, required this.onLeaveReview});

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 4, vsync: this);
  bool _aboutExpanded = false;

  bool _isLoading = true;
  String? _error;
  PlaceDetailData? _place;
  List<PlaceReviewData> _reviews = const [];
  bool _isSaved = false;
  bool _isTogglingSave = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        SupabaseService.fetchPlaceById(widget.placeId),
        SupabaseService.fetchApprovedReviews(widget.placeId, language: widget.language),
        SupabaseService.isPlaceSaved(widget.placeId),
      ]);
      if (!mounted) return;
      setState(() {
        _place = results[0] as PlaceDetailData;
        _reviews = results[1] as List<PlaceReviewData>;
        _isSaved = results[2] as bool;
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
    if (SupabaseService.currentUser == null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
      return;
    }
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _place == null) {
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => Navigator.maybePop(context))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error ?? s(context).placeNotFound, textAlign: TextAlign.center),
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
            leading: _CircleIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.maybePop(context)),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: AppColors.headerGradient(place.category, isDark: isDark),
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
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.35)],
                        ),
                      ),
                    ),
                  ),
                  if (place.isVerified)
                    Positioned(
                      top: 60,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_rounded, size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(s(context).verifiedBadge, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
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
                      const Icon(Icons.star_rounded, size: 16, color: AppColors.accentOrange),
                      const SizedBox(width: 4),
                      Text(place.rating.toStringAsFixed(1), style: theme.textTheme.titleMedium),
                      const SizedBox(width: 4),
                      Text('(${s(context).reviewsCount(place.reviewsCount)}) · ${place.district}', style: theme.textTheme.labelSmall),
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
        _QuickAction(icon: Icons.call_rounded, label: s(context).callAction, onTap: () {}),
        _QuickAction(icon: Icons.directions_rounded, label: s(context).routeAction, onTap: () {}),
        _QuickAction(icon: Icons.language_rounded, label: s(context).websiteAction, onTap: () {}),
        _QuickAction(
          icon: _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          label: s(context).saveAction,
          active: _isSaved,
          onTap: _isTogglingSave ? null : _toggleSaved,
        ),
      ],
    );
  }

  Widget _buildStatsRow(PlaceDetailData place) {
    return Row(
      children: [
        Expanded(child: StatTile(icon: Icons.star_rounded, value: place.rating.toStringAsFixed(1), label: s(context).statRating)),
        const SizedBox(width: 10),
        Expanded(child: StatTile(icon: Icons.forum_rounded, value: '${place.reviewsCount}', label: s(context).statReviews)),
        const SizedBox(width: 10),
        Expanded(child: StatTile(icon: Icons.photo_camera_rounded, value: '${place.photosCount}', label: s(context).statPhotos)),
        const SizedBox(width: 10),
        Expanded(child: StatTile(icon: Icons.payments_rounded, value: place.priceLevelLabel, label: s(context).statPrice)),
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
              overflow: _aboutExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
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
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(s(context).recentReviewsShort, style: theme.textTheme.titleMedium),
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
      itemBuilder: (context, i) => PlaceReviewCard(data: _reviews[i]),
    );
  }

  Widget _buildPhotosTab(ThemeData theme, PlaceDetailData place) {
    if (place.photosCount == 0) {
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
      itemCount: place.photosCount,
      itemBuilder: (context, i) => Container(
        decoration: BoxDecoration(
          color: theme.dividerColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.image_rounded, color: theme.textTheme.bodyMedium?.color),
      ),
    );
  }

  Widget _buildInfoTab(ThemeData theme, PlaceDetailData place) {
    final rows = [
      (Icons.place_rounded, s(context).infoAddress, place.address ?? s(context).notSpecified),
      (Icons.phone_rounded, s(context).infoPhone, place.phone ?? s(context).notSpecified),
      (Icons.language_rounded, s(context).infoWebsite, place.website ?? s(context).notSpecified),
      (Icons.payments_rounded, s(context).infoAvgCheck, place.priceLevelLabel),
    ];
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: rows.length,
      separatorBuilder: (_, __) => Divider(height: 24, color: theme.dividerColor),
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
  final VoidCallback? onTap;
  const _QuickAction({required this.icon, required this.label, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = active ? theme.colorScheme.primary : theme.textTheme.bodyLarge?.color;
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
                  color: active ? theme.colorScheme.primary.withValues(alpha: 0.12) : theme.cardColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Icon(icon, color: color, size: 20),
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
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle),
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
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
