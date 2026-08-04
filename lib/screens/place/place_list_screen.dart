import 'package:flutter/material.dart';
import '../../l10n/strings.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/place_card.dart';
import '../../widgets/place_list_tile.dart';

/// Отдельная страница со списком мест (карточка: фото + название + адрес + рейтинг).
/// Используется и для "Все" у "Сейчас популярно", и для открытия подборки.
class PlaceListScreen extends StatefulWidget {
  final String title;
  final Future<List<PlaceCardData>> Function() fetcher;
  final void Function(PlaceCardData place) onPlaceTap;

  const PlaceListScreen({super.key, required this.title, required this.fetcher, required this.onPlaceTap});

  @override
  State<PlaceListScreen> createState() => _PlaceListScreenState();
}

class _PlaceListScreenState extends State<PlaceListScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  List<PlaceCardData> _places = const [];

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
      final places = await widget.fetcher();
      if (!mounted) return;
      setState(() {
        _places = places;
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
      padding: const EdgeInsets.all(20),
      itemCount: _places.length,
      itemBuilder: (context, i) => PlaceListTile(data: _places[i], onTap: () => widget.onPlaceTap(_places[i])),
    );
  }
}
