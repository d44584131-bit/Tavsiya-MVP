import 'dart:async';

import 'package:flutter/material.dart';
import '../../l10n/strings.dart';
import '../../supabase_service.dart';
import '../../widgets/place_card.dart';
import '../../widgets/place_list_tile.dart';
import '../../widgets/empty_state.dart';

class SearchScreen extends StatefulWidget {
  final void Function(PlaceCardData place)? onPlaceTap;
  const SearchScreen({super.key, this.onPlaceTap});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _pageSize = 10;

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  String? _categoryFilter; // null = все категории

  Timer? _debounce;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _hasError = false;
  List<PlaceCardData> _results = const [];

  static const _categoryKeys = [null, 'restaurant', 'cafe', 'park', 'mall'];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _search);
    setState(() {}); // обновить очищаемую иконку и т.п. без ожидания дебаунса
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore || _isLoading) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _search() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final results = await SupabaseService.searchPlaces(
        query: _controller.text,
        category: _categoryFilter,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _hasMore = results.length == _pageSize;
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

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final more = await SupabaseService.searchPlaces(
        query: _controller.text,
        category: _categoryFilter,
        limit: _pageSize,
        offset: _results.length,
      );
      if (!mounted) return;
      setState(() {
        _results = [..._results, ...more];
        _hasMore = more.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s(context).searchTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
              ),
              child: TextField(
                controller: _controller,
                onChanged: (_) => _onQueryChanged(),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: s(context).searchHint,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _categoryKeys.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final key = _categoryKeys[i];
                final label = key == null
                    ? s(context).allCategories
                    : s(context).categoryPlural(key);
                final isActive = _categoryFilter == key;
                return Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: () => setState(() {
                      _categoryFilter = key;
                      _search();
                    }),
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isActive
                            ? theme.colorScheme.primary
                            : theme.cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: isActive
                                ? theme.colorScheme.primary
                                : theme.dividerColor),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isActive
                              ? Colors.white
                              : theme.textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildResults(theme)),
        ],
      ),
    );
  }

  Widget _buildResults(ThemeData theme) {
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
              Text(s(context).searchLoadError,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _search, child: Text(s(context).retry)),
            ],
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: s(context).nothingFound,
        subtitle: s(context).nothingFoundHint,
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: _results.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= _results.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final p = _results[i];
        return PlaceListTile(data: p, onTap: () => widget.onPlaceTap?.call(p));
      },
    );
  }
}
