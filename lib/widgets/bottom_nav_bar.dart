import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../theme/app_colors.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final bool reviewActive;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onAddReview;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onAddReview,
    this.reviewActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Красим весь безопасный отступ снизу (жестовая панель Android) в цвет
    // меню, а сами пункты держим в фиксированных 68px над ней через SafeArea —
    // иначе меню перекрывается системной навигацией на телефонах с жестами.
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
              color: AppColors.tintedShadow(
                  isDark: isDark, opacity: isDark ? 0.3 : 0.1),
              blurRadius: 16,
              offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MenuItem(
                  icon: Icons.home_rounded,
                  label: s(context).navHome,
                  active: !reviewActive && currentIndex == 0,
                  onTap: () => onTabSelected(0)),
              _MenuItem(
                  icon: Icons.search_rounded,
                  label: s(context).navSearch,
                  active: !reviewActive && currentIndex == 1,
                  onTap: () => onTabSelected(1)),
              _MenuItem(
                  icon: Icons.rate_review_rounded,
                  label: s(context).navReview,
                  active: reviewActive,
                  onTap: onAddReview),
              _MenuItem(
                  icon: Icons.person_outline_rounded,
                  label: s(context).navProfile,
                  active: !reviewActive && currentIndex == 2,
                  onTap: () => onTabSelected(2)),
            ],
          ),
        ),
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

  const _MenuItem(
      {required this.icon,
      required this.label,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        active ? theme.colorScheme.primary : theme.textTheme.bodyMedium?.color;
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
