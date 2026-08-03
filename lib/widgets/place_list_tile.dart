import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'place_card.dart';

IconData _categoryIcon(String category) => switch (category) {
      'restaurant' => Icons.restaurant_rounded,
      'cafe' => Icons.coffee_rounded,
      'park' => Icons.park_rounded,
      'mall' => Icons.storefront_rounded,
      _ => Icons.place_rounded,
    };

/// Карточка места в вертикальном списке: фото занимает ~1/3 ширины слева,
/// остальное — название, адрес и рейтинг. Используется на экранах со
/// списками мест (полный список "Сейчас популярно", подборка, фильтр).
class PlaceListTile extends StatelessWidget {
  final PlaceCardData data;
  final VoidCallback? onTap;
  const PlaceListTile({super.key, required this.data, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                child: Container(
                  width: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: AppColors.headerGradient(data.category, isDark: isDark),
                    ),
                  ),
                  child: Icon(_categoryIcon(data.category), color: Colors.white.withValues(alpha: 0.9), size: 32),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(data.name, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(data.district, style: theme.textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 15, color: AppColors.accentOrange),
                          const SizedBox(width: 3),
                          Text(data.rating.toStringAsFixed(1), style: theme.textTheme.labelSmall),
                          const SizedBox(width: 4),
                          Text('(${data.reviewsCount})', style: theme.textTheme.labelSmall),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
