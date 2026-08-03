import 'package:flutter/material.dart';

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
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 88,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
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
                  _NavIcon(icon: Icons.home_rounded, label: 'Главная', index: 0, current: currentIndex, onTap: onTabSelected),
                  _NavIcon(icon: Icons.search_rounded, label: 'Поиск', index: 1, current: currentIndex, onTap: onTabSelected),
                  const SizedBox(width: 56), // место под центральную кнопку
                  _NavIcon(icon: Icons.bookmark_border_rounded, label: 'Сохранено', index: 2, current: currentIndex, onTap: onTabSelected),
                  _NavIcon(icon: Icons.person_outline_rounded, label: 'Профиль', index: 3, current: currentIndex, onTap: onTabSelected),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: GestureDetector(
              onTap: onAddReview,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary,
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: isDark ? 0.55 : 0.35),
                      blurRadius: isDark ? 20 : 14,
                      spreadRadius: isDark ? 1 : 0,
                    ),
                  ],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int current;
  final ValueChanged<int> onTap;

  const _NavIcon({
    required this.icon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = index == current;
    final color = isActive ? theme.colorScheme.primary : theme.textTheme.bodyMedium?.color;
    return InkWell(
      onTap: () => onTap(index),
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
