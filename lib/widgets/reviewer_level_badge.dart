import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../services/reviewer_level.dart';
import '../theme/app_colors.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accentOrange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.accentOrange)),
    );
  }
}
