import 'package:flutter/material.dart';
import '../../l10n/strings.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/place_card.dart';
import '../../widgets/place_list_tile.dart';

/// Отдельная страница со списком мест (карточка: фото + название + адрес + рейтинг).
/// Используется и для "Все" у "Сейчас популярно", и для открытия подборки.
/// Подгружает данные страницами (по [_pageSize]) по мере прокрутки вниз —
/// список места может быть большим, грузить всё разом не нужно.
class PlaceListScreen extends StatefulWidget {
  final String title;
  final Future<List<PlaceCardData>> Function({required int offset, required int limit}) fetcher;
  final void Function(PlaceCardData place) onPlaceTap;

  const PlaceListScreen({super.key, required this.title, required this.fetcher, required this.onPlaceTap});

  @override
  State<PlaceListScreen> createState() => _PlaceListScreenState();
}

class _PlaceListScreenState extends State<PlaceListScreen> {
  static const _pageSize = 10;
  final _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _hasError = false;
  List<PlaceCardData> _places = const [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore || _isLoading) return;
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final places = await widget.fetcher(offset: 0, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _places = places;
        _hasMore = places.length == _pageSize;
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
      final more = await widget.fetcher(offset: _places.length, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _places = [..._places, ...more];
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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
              Text(s(context).placesLoadError, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: Text(s(context).retry)),
            ],
          ),
        ),
      );
    }
    if (_places.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: s(context).emptyListTitle,
        subtitle: s(context).emptyListSubtitle,
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      itemCount: _places.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= _places.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return PlaceListTile(data: _places[i], onTap: () => widget.onPlaceTap(_places[i]));
      },
    );
  }
}
