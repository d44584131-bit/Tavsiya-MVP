import 'package:flutter/material.dart';
import '../l10n/strings.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onAddReview;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onAddReview,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MenuItem(icon: Icons.home_rounded, label: s(context).navHome, active: currentIndex == 0, onTap: () => onTabSelected(0)),
          _MenuItem(icon: Icons.search_rounded, label: s(context).navSearch, active: currentIndex == 1, onTap: () => onTabSelected(1)),
          _MenuItem(icon: Icons.rate_review_rounded, label: s(context).navReview, active: false, onTap: onAddReview),
          _MenuItem(icon: Icons.person_outline_rounded, label: s(context).navProfile, active: currentIndex == 2, onTap: () => onTabSelected(2)),
        ],
      ),
    );
  }
}

/// Единый стиль пункта меню — все пункты одного (нейтрального) цвета,
/// кроме активной вкладки, которая подсвечивается основным цветом темы.
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _MenuItem({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = active ? theme.colorScheme.primary : theme.textTheme.bodyMedium?.color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }
}
