import 'package:flutter/material.dart';
import '../../l10n/strings.dart';
import '../../supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/place_card.dart';
import '../../widgets/place_list_tile.dart';
import '../../widgets/review_list_item.dart';
import '../place/collections_list_screen.dart';
import '../place/place_list_screen.dart';
import '../profile/profile_screen.dart' show AppLanguage;

class _CategoryItem {
  final String key;
  final IconData icon;
  const _CategoryItem(this.key, this.icon);
}

const _categories = [
  _CategoryItem('restaurant', Icons.restaurant_rounded),
  _CategoryItem('cafe', Icons.coffee_rounded),
  _CategoryItem('park', Icons.park_rounded),
  _CategoryItem('mall', Icons.storefront_rounded),
];

class CollectionData {
  final String id;
  final String title;
  final List<PlaceCardData> places;
  const CollectionData({required this.id, required this.title, required this.places});
}

class HomeScreen extends StatefulWidget {
  final AppLanguage language;
  final void Function(PlaceCardData place)? onPlaceTap;
  const HomeScreen({super.key, required this.language, this.onPlaceTap});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  List<PlaceCardData> _trending = const [];
  List<ReviewListItemData> _recentReviews = const [];
  List<CollectionData> _collections = const [];

  String? _selectedCategory;
  bool _isFilterLoading = false;
  List<PlaceCardData> _filteredPlaces = const [];

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
        SupabaseService.fetchTrendingPlaces(),
        SupabaseService.fetchRecentReviews(language: widget.language),
        SupabaseService.fetchCollections(),
      ]);
      if (!mounted) return;
      setState(() {
        _trending = results[0] as List<PlaceCardData>;
        _recentReviews = results[1] as List<ReviewListItemData>;
        _collections = results[2] as List<CollectionData>;
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

  Future<void> _onCategoryTap(String key) async {
    final next = _selectedCategory == key ? null : key;
    setState(() => _selectedCategory = next);
    if (next == null) {
      setState(() => _filteredPlaces = const []);
      return;
    }
    setState(() => _isFilterLoading = true);
    try {
      final results = await SupabaseService.searchPlaces(category: next);
      if (!mounted) return;
      setState(() {
        _filteredPlaces = results;
        _isFilterLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFilterLoading = false);
    }
  }

  void _openAllTrending() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlaceListScreen(
        title: 'Сейчас популярно',
        fetcher: () => SupabaseService.fetchTrendingPlaces(limit: 50),
        onPlaceTap: (p) => widget.onPlaceTap?.call(p),
      ),
    ));
  }

  void _openAllCollections() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CollectionsListScreen(
        collections: _collections,
        onPlaceTap: (p) => widget.onPlaceTap?.call(p),
      ),
    ));
  }

  void _openCollection(CollectionData collection) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlaceListScreen(
        title: collection.title,
        fetcher: () async => collection.places,
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
              Text(s(context).loadErrorGeneric, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
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
            child: _SectionTitle(title: s(context).trendingTitle, onSeeAll: _openAllTrending),
          ),
          SliverToBoxAdapter(child: _buildTrendingRow()),
          SliverToBoxAdapter(child: _buildCategoryFilterHeader(theme)),
          if (_selectedCategory != null) _buildFilterResultsSliver(theme),
          if (!_isLoading && _recentReviews.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionTitle(title: s(context).recentReviewsTitle, onSeeAll: () {}),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.builder(
                itemCount: _recentReviews.length,
                itemBuilder: (context, i) => _StaggerIn(
                  index: i,
                  child: ReviewListItem(data: _recentReviews[i]),
                ),
              ),
            ),
          ],
          if (!_isLoading && _collections.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionTitle(title: s(context).collectionsTitle, onSeeAll: _openAllCollections),
            ),
            SliverToBoxAdapter(child: _buildCollectionsCarousel(theme)),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {}, // TODO: выбор города, когда появится мультигород
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on_rounded, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Text(s(context).cityName, style: theme.textTheme.titleMedium),
                const SizedBox(width: 2),
                Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: theme.textTheme.bodyMedium?.color),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(Icons.search_rounded, color: theme.textTheme.bodyMedium?.color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(s(context).searchHint, style: theme.textTheme.bodyMedium),
                ),
                Icon(Icons.mic_none_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingRow() {
    return SizedBox(
      height: 190,
      child: _isLoading
          ? ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 3,
              itemBuilder: (context, i) => const PlaceCardSkeleton(),
            )
          : _trending.isEmpty
              ? Center(
                  child: Text(s(context).noPlacesYet, style: Theme.of(context).textTheme.bodyMedium),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _trending.length,
                  itemBuilder: (context, i) {
                    final place = _trending[i];
                    return _StaggerIn(
                      index: i,
                      child: PlaceCard(data: place, onTap: () => widget.onPlaceTap?.call(place)),
                    );
                  },
                ),
    );
  }

  Widget _buildCategoryFilterHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Text(s(context).categoriesTitle, style: theme.textTheme.headlineMedium),
        ),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final c = _categories[i];
              final isActive = _selectedCategory == c.key;
              return GestureDetector(
                onTap: () => _onCategoryTap(c.key),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isActive ? theme.colorScheme.primary.withValues(alpha: 0.15) : theme.cardColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: isActive ? theme.colorScheme.primary : theme.dividerColor, width: isActive ? 1.5 : 1),
                      ),
                      child: Icon(c.icon, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s(context).categoryPlural(c.key),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isActive ? theme.colorScheme.primary : null,
                        fontWeight: isActive ? FontWeight.w700 : null,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterResultsSliver(ThemeData theme) {
    if (_isFilterLoading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_filteredPlaces.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(child: Text(s(context).categoryEmpty, style: theme.textTheme.bodyMedium)),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList.builder(
        itemCount: _filteredPlaces.length,
        itemBuilder: (context, i) {
          final place = _filteredPlaces[i];
          return PlaceListTile(data: place, onTap: () => widget.onPlaceTap?.call(place));
        },
      ),
    );
  }

  Widget _buildCollectionsCarousel(ThemeData theme) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _collections.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final collection = _collections[i];
          return GestureDetector(
            onTap: () => _openCollection(collection),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: AppColors.headerGradient(_categories[i % 4].key, isDark: theme.brightness == Brightness.dark)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(collection.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final VoidCallback onSeeAll;
  const _SectionTitle({required this.title, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: theme.textTheme.headlineMedium),
          TextButton(onPressed: onSeeAll, child: Text(s(context).seeAll)),
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

class _StaggerInState extends State<_StaggerIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(_fade);
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
