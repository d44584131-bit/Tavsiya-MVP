import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StarRatingInput extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final double size;
  const StarRatingInput({super.key, required this.value, required this.onChanged, this.size = 40});

  @override
  State<StarRatingInput> createState() => _StarRatingInputState();
}

class _StarRatingInputState extends State<StarRatingInput> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers = List.generate(
    5,
    (_) => AnimationController(vsync: this, duration: const Duration(milliseconds: 350)),
  );

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _tap(int index) {
    final newValue = index + 1;
    widget.onChanged(newValue);
    // Пружинящая анимация: звёзды до выбранной "подпрыгивают" с небольшой задержкой каждая.
    for (int i = 0; i <= index; i++) {
      Future.delayed(Duration(milliseconds: i * 40), () {
        if (mounted) _controllers[i].forward(from: 0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final filled = i < widget.value;
        return GestureDetector(
          onTap: () => _tap(i),
          child: AnimatedBuilder(
            animation: _controllers[i],
            builder: (context, child) {
              final bounce = Tween<double>(begin: 1.0, end: 1.35)
                  .chain(CurveTween(curve: Curves.elasticOut))
                  .animate(_controllers[i]);
              final scale = _controllers[i].isAnimating ? bounce.value : 1.0;
              return Transform.scale(scale: scale, child: child);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                filled ? Icons.star_rounded : Icons.star_border_rounded,
                size: widget.size,
                color: filled ? AppColors.accentOrange : theme.dividerColor,
              ),
            ),
          ),
        );
      }),
    );
  }
}
