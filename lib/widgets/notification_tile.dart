import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class NotificationData {
  final String id;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  const NotificationData({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });
}

class NotificationTile extends StatelessWidget {
  final NotificationData data;
  const NotificationTile({super.key, required this.data});

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: data.isRead
            ? theme.cardColor
            : theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: data.isRead
                ? theme.dividerColor
                : theme.colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.positive.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: AppColors.positive, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(data.body, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 6),
                Text(_formatDate(data.createdAt),
                    style: theme.textTheme.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
