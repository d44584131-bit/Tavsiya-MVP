import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/strings.dart';
import '../services/reviewer_level.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// Компактный значок уровня автора отзыва (Эксперт/Гуру) — та же логика,
/// что и бейдж в профиле (reviewer_level.dart), но без "Вы", т.к. речь о
/// другом пользователе. Для новичков ничего не показывает — бейдж нужен,
/// чтобы выделить опытных авторов, а не пометить всех подряд.
class ReviewerLevelBadge extends StatelessWidget {
  final int reviewsCount;
  const ReviewerLevelBadge({super.key, required this.reviewsCount});

  @override
  Widget build(BuildContext context) {
    final level = reviewerLevelFor(reviewsCount);
    if (level == ReviewerLevel.novice) return const SizedBox.shrink();
    final label = level == ReviewerLevel.guru
        ? s(context).levelGuru
        : s(context).levelExpert;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accentOrange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.tag),
      ),
      child: Text(label.toUpperCase(),
          style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w600,
              color: AppColors.accentOrange)),
    );
  }
}
