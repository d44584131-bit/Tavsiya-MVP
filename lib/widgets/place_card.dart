import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../theme/app_colors.dart';

class PlaceCardData {
  final String id;
  final String name;
  final String category; // 'restaurant' | 'cafe' | 'park' | 'mall'
  final double rating;
  final int reviewsCount;
  final String district;

  const PlaceCardData({
    required this.id,
    required this.name,
    required this.category,
    required this.rating,
    required this.reviewsCount,
    required this.district,
  });
}

IconData _categoryIcon(String category) => switch (category) {
      'restaurant' => Icons.restaurant_rounded,
      'cafe' => Icons.coffee_rounded,
      'park' => Icons.park_rounded,
      'mall' => Icons.storefront_rounded,
      _ => Icons.place_rounded,
    };

/// Горизонтальная карточка места с градиентной "шапкой"-иллюстрацией.
/// Ширина фиксирована — используется внутри горизонтального ListView.
class PlaceCard extends StatelessWidget {
  final PlaceCardData data;
  final VoidCallback? onTap;
  const PlaceCard({super.key, required this.data, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 168,
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppColors.tintedShadow(isDark: false, opacity: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    height: 96,
                    decoration: BoxDecoration(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: AppColors.headerGradient(data.category,
                            isDark: isDark),
                      ),
                    ),
                    child: Stack(
                      children: [
                        // едва заметная текстура поверх градиента
                        Positioned.fill(
                          child: Opacity(
                            opacity: 0.08,
                            child: CustomPaint(painter: _NoisePainter()),
                          ),
                        ),
                        Center(
                          child: Icon(_categoryIcon(data.category),
                              size: 40,
                              color: Colors.white.withValues(alpha: 0.9)),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        s(context).categoryLabel(data.category),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 14, color: AppColors.accentOrange),
                        const SizedBox(width: 2),
                        Text(data.rating.toStringAsFixed(1),
                            style: theme.textTheme.labelSmall),
                        const SizedBox(width: 4),
                        Text('(${data.reviewsCount})',
                            style: theme.textTheme.labelSmall),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(data.district,
                        style: theme.textTheme.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton-версия карточки — используется, пока идёт загрузка данных.
class PlaceCardSkeleton extends StatefulWidget {
  const PlaceCardSkeleton({super.key});

  @override
  State<PlaceCardSkeleton> createState() => _PlaceCardSkeletonState();
}

class _PlaceCardSkeletonState extends State<PlaceCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final base = theme.dividerColor;
        final shimmer = Color.lerp(base, theme.cardColor, _c.value)!;
        return Container(
          width: 168,
          margin: const EdgeInsets.only(right: 14),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 96,
                decoration: BoxDecoration(
                  color: shimmer,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 14, width: 110, color: shimmer),
                    const SizedBox(height: 8),
                    Container(height: 10, width: 70, color: shimmer),
                    const SizedBox(height: 6),
                    Container(height: 10, width: 90, color: shimmer),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Едва заметная зернистая текстура поверх градиента (не плоская заливка).
class _NoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final rnd = _seededRandomPoints(size);
    for (final p in rnd) {
      canvas.drawCircle(p, 0.6, paint);
    }
  }

  List<Offset> _seededRandomPoints(Size size) {
    final points = <Offset>[];
    var seed = 42;
    int next() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed;
    }

    for (int i = 0; i < 140; i++) {
      final x = (next() % size.width.toInt()).toDouble();
      final y = (next() % size.height.toInt()).toDouble();
      points.add(Offset(x, y));
    }
    return points;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
