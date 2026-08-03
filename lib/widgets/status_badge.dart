import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String statusLabel; // напр. "Вы эксперт"
  final int currentPoints;
  final int nextLevelPoints;
  final String nextLevelLabel; // напр. "До уровня «Гуру» — 30 отзывов"

  const StatusBadge({
    super.key,
    required this.statusLabel,
    required this.currentPoints,
    required this.nextLevelPoints,
    required this.nextLevelLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (currentPoints / nextLevelPoints).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.workspace_premium_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(statusLabel, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Spacer(),
              Text('$currentPoints / $nextLevelPoints', style: theme.textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: theme.dividerColor,
                valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(nextLevelLabel, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}
