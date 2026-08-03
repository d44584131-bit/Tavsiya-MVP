import 'package:flutter/material.dart';
import '../../supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/place_card.dart';
import '../../widgets/review_list_item.dart';

class _CategoryItem {
  final String label;
  final String key;
  final IconData icon;
  const _CategoryItem(this.label, this.key, this.icon);
}

const _categories = [
  _CategoryItem('Рестораны', 'restaurant', Icons.restaurant_rounded),
  _CategoryItem('Кафе', 'cafe', Icons.coffee_rounded),
  _CategoryItem('Парки', 'park', Icons.park_rounded),
  _CategoryItem('ТЦ', 'mall', Icons.storefront_rounded),
];

class HomeScreen extends StatefulWidget {
  final void Function(PlaceCardData place)? onPlaceTap;
  const HomeScreen({super.key, this.onPlaceTap});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  List<PlaceCardData> _trending = const [];
  List<ReviewListItemData> _recentReviews = const [];

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
        SupabaseService.fetchRecentReviews(),
      ]);
      if (!mounted) return;
      setState(() {
        _trending = results[0] as List<PlaceCardData>;
        _recentReviews = results[1] as List<ReviewListItemData>;
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
              Text('Не удалось загрузить данные', style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Повторить')),
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
          SliverToBoxAdapter(child: _buildCategoryRow(theme)),
          SliverToBoxAdapter(
            child: _SectionTitle(title: 'Сейчас обсуждают', onSeeAll: () {}),
          ),
          SliverToBoxAdapter(child: _buildTrendingRow()),
          if (!_isLoading && _recentReviews.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionTitle(title: 'Новые отзывы', onSeeAll: () {}),
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
          SliverToBoxAdapter(
            child: _SectionTitle(title: 'Подборки для вас', onSeeAll: () {}),
          ),
          SliverToBoxAdapter(child: _buildCollectionsCarousel(theme)),
          const SliverToBoxAdapter(child: SizedBox(height: 90)),
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
                Text('Ташкент', style: theme.textTheme.titleMedium),
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
                  child: Text('Найти место…', style: theme.textTheme.bodyMedium),
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

  Widget _buildCategoryRow(ThemeData theme) {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final c = _categories[i];
          return _StaggerIn(
            index: i,
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Icon(c.icon, color: theme.colorScheme.primary),
                ),
                const SizedBox(height: 6),
                Text(c.label, style: theme.textTheme.labelSmall),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrendingRow() {
    return SizedBox(
      height: 190,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _isLoading ? 3 : _trending.length,
        itemBuilder: (context, i) {
          if (_isLoading) return const PlaceCardSkeleton();
          final place = _trending[i];
          return _StaggerIn(
            index: i,
            child: PlaceCard(data: place, onTap: () => widget.onPlaceTap?.call(place)),
          );
        },
      ),
    );
  }

  Widget _buildCollectionsCarousel(ThemeData theme) {
    final collections = ['Романтический вечер', 'С детьми', 'Бюджетно', 'Новинки района'];
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: collections.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: AppColors.headerGradient(_categories[i % 4].key, isDark: theme.brightness == Brightness.dark)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(collections[i], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
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
          TextButton(onPressed: onSeeAll, child: const Text('Все')),
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
