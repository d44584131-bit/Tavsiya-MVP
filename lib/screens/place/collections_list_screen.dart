import 'package:flutter/material.dart';
import '../../l10n/strings.dart';
import '../../theme/app_colors.dart';
import '../../widgets/place_card.dart';
import '../home/home_screen.dart' show CollectionData;
import 'place_list_screen.dart';

/// Список всех подборок ("Все" у "Подборки для вас"). Выбор подборки
/// открывает список её мест той же карточкой, что и остальные списки мест.
class CollectionsListScreen extends StatelessWidget {
  final List<CollectionData> collections;
  final void Function(PlaceCardData place)? onPlaceTap;

  const CollectionsListScreen({super.key, required this.collections, this.onPlaceTap});

  void _openCollection(BuildContext context, CollectionData collection) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlaceListScreen(
        title: collection.title,
        fetcher: () async => collection.places,
        onPlaceTap: (p) => onPlaceTap?.call(p),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s(context).collectionsTitle)),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: collections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final collection = collections[i];
          return _CollectionCard(data: collection, onTap: () => _openCollection(context, collection));
        },
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final CollectionData data;
  final VoidCallback onTap;
  const _CollectionCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradientKey = data.places.isNotEmpty ? data.places.first.category : 'restaurant';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 90,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.headerGradient(gradientKey, isDark: theme.brightness == Brightness.dark),
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(data.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(s(context).placesCount(data.places.length), style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
