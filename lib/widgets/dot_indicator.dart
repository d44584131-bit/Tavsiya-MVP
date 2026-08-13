import 'package:flutter/material.dart';

/// Индикатор шагов (ProgressDots из бандла Ember): активная точка
/// растягивается в капсулу, остальные — маленькие кружки.
class DotIndicator extends StatelessWidget {
  final int count;
  final int activeIndex;
  const DotIndicator(
      {super.key, required this.count, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = theme.colorScheme.primary;
    final idle = theme.dividerColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final isActive = i == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3.5),
          width: isActive ? 26 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? active : idle,
            borderRadius: BorderRadius.circular(isActive ? 5 : 999),
          ),
        );
      }),
    );
  }
}
