import 'package:flutter/material.dart';

class StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const StatTile({super.key, required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 20),
          const SizedBox(height: 6),
          Text(value, style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.labelSmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
