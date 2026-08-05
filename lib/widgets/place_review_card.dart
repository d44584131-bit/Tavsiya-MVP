import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../theme/app_colors.dart';

class PlaceReviewData {
  final String authorName;
  final int stars;
  final String text;
  final List<String> photoUrls; // публичные URL фото, приложенных к отзыву
  final String? pros;
  final String? cons;
  final String? moderationStatus; // 'pending' | 'rejected' | null (= approved)

  const PlaceReviewData({
    required this.authorName,
    required this.stars,
    required this.text,
    this.photoUrls = const [],
    this.pros,
    this.cons,
    this.moderationStatus,
  });
}

class PlaceReviewCard extends StatelessWidget {
  final PlaceReviewData data;
  const PlaceReviewCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                child: Text(
                  data.authorName.isNotEmpty ? data.authorName[0].toUpperCase() : '?',
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.authorName, style: theme.textTheme.titleMedium),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          Icons.star_rounded,
                          size: 13,
                          color: i < data.stars ? AppColors.accentOrange : theme.dividerColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (data.moderationStatus == 'pending')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(s(context).pendingBadge, style: const TextStyle(fontSize: 11, color: AppColors.accentOrange, fontWeight: FontWeight.w600)),
                ),
              if (data.moderationStatus == 'rejected')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.negative.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(s(context).rejectedBadge, style: const TextStyle(fontSize: 11, color: AppColors.negative, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(data.text, style: theme.textTheme.bodyMedium),
          if (data.pros != null || data.cons != null) ...[
            const SizedBox(height: 10),
            if (data.pros != null) _ProsConsLine(icon: Icons.add_circle_outline, color: AppColors.positive, text: data.pros!),
            if (data.cons != null) _ProsConsLine(icon: Icons.remove_circle_outline, color: AppColors.negative, text: data.cons!),
          ],
          if (data.photoUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: data.photoUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    data.photoUrls[i],
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) => progress == null
                        ? child
                        : Container(width: 64, height: 64, color: theme.dividerColor),
                    errorBuilder: (context, error, stack) => Container(
                      width: 64,
                      height: 64,
                      color: theme.dividerColor,
                      child: Icon(Icons.broken_image_rounded, color: theme.textTheme.bodyMedium?.color, size: 20),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProsConsLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _ProsConsLine({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
