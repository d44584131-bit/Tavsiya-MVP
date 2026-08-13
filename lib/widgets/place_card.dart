import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

class PlaceCardData {
  final String id;
  final String name;
  final String category; // 'restaurant' | 'cafe' | 'park' | 'mall'
  final double rating;
  final int reviewsCount;
  final String district;
  final String? status; // 'pending' | 'rejected' | null (= approved)
  final bool isChain; // сеть заведений — несколько филиалов у одного профиля
  final List<String> branches; // адреса филиалов, заполнено только у сетей

  const PlaceCardData({
    required this.id,
    required this.name,
    required this.category,
    required this.rating,
    required this.reviewsCount,
    required this.district,
    this.status,
    this.isChain = false,
    this.branches = const [],
  });
}

/// Карточка места в стиле VenueBubble из бандла Ember: сплошная заливка
/// цветом категории, один "срезанный" угол снизу (хвостик пузыря),
/// рейтинг — тёмная плашка в углу. Используется в горизонтальной ленте
/// "Сейчас популярно" — ширина фиксирована.
class PlaceCard extends StatelessWidget {
  final PlaceCardData data;
  final VoidCallback? onTap;
  final bool tailRight;
  const PlaceCard(
      {super.key, required this.data, this.onTap, this.tailRight = false});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.categoryColor(data.category);
    final onDark = AppColors.categoryOnDark(data.category);
    final strong = onDark ? Colors.white : const Color(0xFF111111);
    final quiet = onDark
        ? Colors.white.withValues(alpha: 0.8)
        : Colors.black.withValues(alpha: 0.6);

    return Container(
      width: 208,
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: color,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(AppRadius.venue),
          topRight: const Radius.circular(AppRadius.venue),
          bottomLeft: Radius.circular(
              tailRight ? AppRadius.venue : AppRadius.venueTail),
          bottomRight: Radius.circular(
              tailRight ? AppRadius.venueTail : AppRadius.venue),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(data.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              height: 1.15,
                              color: strong)),
                      const SizedBox(height: 4),
                      Text(data.district,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                              color: quiet)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111010),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('★ ${data.rating.toStringAsFixed(1)}',
                      style: GoogleFonts.jetBrainsMono(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: Colors.white)),
                ),
              ],
            ),
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
          width: 208,
          height: 82,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: shimmer,
            borderRadius: BorderRadius.circular(AppRadius.venue),
          ),
        );
      },
    );
  }
}
