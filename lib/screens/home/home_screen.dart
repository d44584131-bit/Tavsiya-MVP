import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../l10n/strings.dart';
import '../../supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/auth_required_dialog.dart';
import '../../widgets/category_folder_card.dart';
import '../../widgets/place_card.dart';
import '../../widgets/place_list_tile.dart';
import '../../widgets/place_review_card.dart';
import '../../widgets/section_header.dart';
import '../place/collections_list_screen.dart';
import '../place/place_list_screen.dart';
import '../profile/profile_screen.dart' show AppLanguage;
import '../reviews/all_reviews_screen.dart';

const _categories = ['restaurant', 'cafe', 'park', 'mall'];

class CollectionData {
  final String id;
  final String title;
  final List<PlaceCardData> places;
  const CollectionData(
      {required this.id, required this.title, required this.places});
}

class HomeScreen extends StatefulWidget {
  final AppLanguage language;
  final void Function(PlaceCardData place)? onPlaceTap;
  final VoidCallback? onOpenSearch;
  final String selectedCity;
  final ValueChanged<String>? onCityChanged;
  const HomeScreen({
    super.key,
    required this.language,
    this.onPlaceTap,
    this.onOpenSearch,
    this.selectedCity = kDefaultCity,
    this.onCityChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // На главной показываем только "витрину" из нескольких мест — весь
  // остальной список (с постраничной подгрузкой) открывается по "Все"
  // на PlaceListScreen, у неё своя независимая пагинация.
  static const _trendingPreviewCount = 3;

  bool _isLoading = true;
  bool _hasError = false;
  List<PlaceCardData> _trending = const [];
  List<PlaceReviewData> _recentReviews = const [];
  List<CollectionData> _collections = const [];
  Map<String, int> _categoryCounts = const {};

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
      final results = await Future.wait([
        SupabaseService.fetchTrendingPlaces(limit: _trendingPreviewCount),
        SupabaseService.fetchRecentReviews(language: widget.language),
        SupabaseService.fetchCollections(language: widget.language),
        SupabaseService.fetchCategoryCounts(),
      ]);
      if (!mounted) return;
      setState(() {
        _trending = results[0] as List<PlaceCardData>;
        _recentReviews = results[1] as List<PlaceReviewData>;
        _collections = results[2] as List<CollectionData>;
        _categoryCounts = results[3] as Map<String, int>;
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

  void _openCategory(String key) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlaceListScreen(
        title: s(context).categoryPlural(key),
        fetcher: ({required offset, required limit}) =>
            SupabaseService.searchPlaces(
                category: key, offset: offset, limit: limit),
        onPlaceTap: (p) => widget.onPlaceTap?.call(p),
      ),
    ));
  }

  void _openAllTrending() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlaceListScreen(
        title: s(context).trendingTitle,
        fetcher: ({required offset, required limit}) =>
            SupabaseService.fetchTrendingPlaces(offset: offset, limit: limit),
        onPlaceTap: (p) => widget.onPlaceTap?.call(p),
      ),
    ));
  }

  void _openAllReviews() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AllReviewsScreen(language: widget.language),
    ));
  }

  Future<void> _toggleReviewHelpful(PlaceReviewData review, bool like) async {
    if (!await ensureAuthenticated(context, s(context).authRequiredActionLike)) {
      return;
    }
    if (!mounted) return;
    final index = _recentReviews.indexWhere((r) => r.id == review.id);
    if (index == -1) return;
    setState(() {
      _recentReviews[index] = review.copyWith(
        isHelpfulByMe: like,
        helpfulCount: review.helpfulCount + (like ? 1 : -1),
      );
    });
    try {
      await SupabaseService.toggleReviewHelpful(review.id, like: like);
    } catch (_) {
      if (!mounted) return;
      setState(() => _recentReviews[index] = review);
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

  void _openAllCollections() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CollectionsListScreen(
        collections: _collections,
        onPlaceTap: (p) => widget.onPlaceTap?.call(p),
      ),
    ));
  }

  void _openCityPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _CityPickerSheet(
        selectedCity: widget.selectedCity,
        onSelected: (city) {
          Navigator.of(context).pop();
          if (city != widget.selectedCity) widget.onCityChanged?.call(city);
        },
      ),
    );
  }

  void _openCollection(CollectionData collection) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlaceListScreen(
        title: collection.title,
        fetcher: ({required offset, required limit}) async =>
            collection.places.skip(offset).take(limit).toList(),
        onPlaceTap: (p) => widget.onPlaceTap?.call(p),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(theme)),
          SliverToBoxAdapter(
            child: SectionHeader(
                title: s(context).trendingTitle,
                actionLabel: s(context).seeAll,
                onAction: _openAllTrending),
          ),
          SliverToBoxAdapter(child: _buildTrendingRow()),
          SliverToBoxAdapter(child: _buildCategoryFilterHeader(theme)),
          if (!_isLoading && _collections.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionHeader(
                  title: s(context).collectionsTitle,
                  actionLabel: s(context).seeAll,
                  onAction: _openAllCollections),
            ),
            SliverToBoxAdapter(child: _buildCollectionsCarousel(theme)),
          ],
          if (!_isLoading && _recentReviews.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionHeader(
                  title: s(context).recentReviewsTitle,
                  actionLabel: s(context).seeAll,
                  onAction: _openAllReviews),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.builder(
                itemCount: _recentReviews.length,
                itemBuilder: (context, i) => _StaggerIn(
                  index: i,
                  child: PlaceReviewCard(
                    data: _recentReviews[i],
                    onToggleHelpful: (like) =>
                        _toggleReviewHelpful(_recentReviews[i], like),
                    onSubmitReply: (text) =>
                        _submitReviewReply(_recentReviews[i], text),
                  ),
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: _openCityPicker,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s(context).cityLabel(widget.selectedCity).toUpperCase(),
                        style: GoogleFonts.jetBrainsMono(
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                            letterSpacing: 1.2,
                            color: theme.textTheme.labelSmall?.color)),
                    const SizedBox(width: 2),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 16, color: theme.textTheme.labelSmall?.color),
                  ],
                ),
              ),
            ),
          ),
          Text(s(context).homeTitle, style: theme.textTheme.headlineLarge),
          const SizedBox(height: 16),
          Material(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: widget.onOpenSearch,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor, width: 1.5),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Text('⌕',
                        style: GoogleFonts.jetBrainsMono(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: theme.textTheme.labelSmall?.color)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(s(context).searchHint,
                          style: theme.textTheme.bodyMedium),
                    ),
                    const SizedBox(width: 14),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingRow() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            PlaceListTileSkeleton(),
            PlaceListTileSkeleton(),
            PlaceListTileSkeleton(),
          ],
        ),
      );
    }
    if (_trending.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Center(
          child: Text(s(context).noPlacesYet,
              style: Theme.of(context).textTheme.bodyMedium),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: _trending.asMap().entries.map((entry) {
          final place = entry.value;
          return _StaggerIn(
            index: entry.key,
            child: PlaceListTile(
                data: place, onTap: () => widget.onPlaceTap?.call(place)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryFilterHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: s(context).categoriesTitle),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: _categories.asMap().entries.map((entry) {
              final c = entry.value;
              final count = _categoryCounts[c];
              return _StaggerIn(
                index: entry.key,
                child: CategoryFolderCard(
                  label: s(context).categoryPlural(c),
                  count: count != null ? s(context).placesCount(count) : null,
                  color: AppColors.categoryColor(c),
                  onDark: AppColors.categoryOnDark(c),
                  onTap: () => _openCategory(c),
                  centerContent: true,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCollectionsCarousel(ThemeData theme) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _collections.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final collection = _collections[i];
          final category = _categories[i % _categories.length];
          return SizedBox(
            width: 180,
            child: CategoryFolderCard(
              label: collection.title,
              color: AppColors.categoryColor(category),
              onDark: AppColors.categoryOnDark(category),
              onTap: () => _openCollection(collection),
              centerContent: true,
            ),
          );
        },
      ),
    );
  }
}

class _CityPickerSheet extends StatelessWidget {
  final String selectedCity;
  final ValueChanged<String> onSelected;
  const _CityPickerSheet(
      {required this.selectedCity, required this.onSelected});

  // Реальные данные пока только по Ташкенту — вместо переключения на
  // остальные города из списка просто извиняемся.
  void _onCityTap(BuildContext context, String key) {
    if (key != kDefaultCity) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(s(context).onlyTashkentTitle),
          content: Text(s(context).onlyTashkentMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(s(context).gotItButton),
            ),
          ],
        ),
      );
      return;
    }
    onSelected(key);
  }

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
          Text(s(context).chooseCityTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 14),
          ...kCityKeys.map((key) {
            final isActive = key == selectedCity;
            return InkWell(
              onTap: () => _onCityTap(context, key),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      isActive
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.dividerColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      s(context).cityLabel(key),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: isActive ? theme.colorScheme.primary : null,
                        fontWeight: isActive ? FontWeight.w700 : null,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Обёртка для stagger fade+slide анимации появления элементов при построении списка.
class _StaggerIn extends StatefulWidget {
  final int index;
  final Widget child;
  const _StaggerIn({required this.index, required this.child});

  @override
  State<_StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<_StaggerIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(_fade);
    Future.delayed(Duration(milliseconds: 60 * widget.index), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
