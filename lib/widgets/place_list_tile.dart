import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import 'place_card.dart';

/// Карточка места в вертикальном списке — тот же визуальный язык, что и
/// PlaceCard в горизонтальной ленте (сплошная заливка цветом категории,
/// тёмная плашка рейтинга, светлый блок с числом отзывов), но на всю
/// ширину. Используется на экранах со списками мест (полный список
/// "Сейчас популярно", подборка, фильтр по категории).
class PlaceListTile extends StatelessWidget {
  final PlaceCardData data;
  final VoidCallback? onTap;
  const PlaceListTile({super.key, required this.data, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.categoryColor(data.category);
    final onDark = AppColors.categoryOnDark(data.category);
    final strong = onDark ? Colors.white : const Color(0xFF111111);
    final quiet = onDark
        ? Colors.white.withValues(alpha: 0.8)
        : Colors.black.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.venue),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(data.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: strong)),
                          const SizedBox(height: 4),
                          Text(data.district,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: quiet)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111010),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('★ ${data.rating.toStringAsFixed(1)}',
                          style: GoogleFonts.jetBrainsMono(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    data.reviewsCount > 0
                        ? s(context).reviewsCount(data.reviewsCount)
                        : s(context).noReviewsTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: const Color(0xFF111111)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
