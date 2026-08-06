import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ReviewListItemData {
  final String authorName;
  final String placeName;
  final int stars;
  final String text;

  const ReviewListItemData({
    required this.authorName,
    required this.placeName,
    required this.stars,
    required this.text,
  });
}

class ReviewListItem extends StatelessWidget {
  final ReviewListItemData data;
  const ReviewListItem({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
            child: Text(
              data.authorName.isNotEmpty
                  ? data.authorName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(data.authorName,
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis),
                    ),
                    ...List.generate(
                      5,
                      (i) => Icon(
                        Icons.star_rounded,
                        size: 13,
                        color: i < data.stars
                            ? AppColors.accentOrange
                            : theme.dividerColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(data.placeName, style: theme.textTheme.labelSmall),
                const SizedBox(height: 6),
                Text(
                  data.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
