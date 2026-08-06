import 'package:flutter/material.dart';

class DotIndicator extends StatelessWidget {
  final int count;
  final int activeIndex;
  const DotIndicator(
      {super.key, required this.count, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final inactive = Theme.of(context).dividerColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final isActive = i == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? primary : inactive,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
