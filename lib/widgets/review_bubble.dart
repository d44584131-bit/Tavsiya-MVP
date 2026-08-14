import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

enum BubbleTilt { left, leftSoft, right, rightSoft, none }

double _tiltRadians(BubbleTilt tilt) {
  final deg = switch (tilt) {
    BubbleTilt.left => -3.5,
    BubbleTilt.leftSoft => -1.5,
    BubbleTilt.right => 2.5,
    BubbleTilt.rightSoft => 1.5,
    BubbleTilt.none => 0.0,
  };
  return deg * 3.1415926535 / 180;
}

/// Наклонённый "пузырь"-цитата с жирной коралловой обводкой и жёсткой
/// (не размытой) тенью-сдвигом — фирменный мотив Ember для отзывов и
/// коротких акцентов на онбординге.
class ReviewBubble extends StatelessWidget {
  final Widget child;
  final bool hero;
  final BubbleTilt tilt;
  final EdgeInsetsGeometry? padding;

  const ReviewBubble({
    super.key,
    required this.child,
    this.hero = false,
    this.tilt = BubbleTilt.left,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = theme.colorScheme.primary;
    final bg = hero
        ? (isDark ? const Color(0xFF242120) : Colors.white)
        : (isDark ? const Color(0xFF1A1817) : const Color(0xFFF3F1EE));
    final shadowColor = isDark
        ? const Color(0xFF928A80).withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.06);

    return Transform.rotate(
      angle: _tiltRadians(tilt),
      child: Container(
        padding: padding ??
            (hero
                ? const EdgeInsets.symmetric(horizontal: 18, vertical: 16)
                : const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(
              hero ? AppRadius.bubbleHero : AppRadius.bubble),
          border: Border.all(
              color: borderColor, width: hero ? 4.5 : 3.5),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              offset: Offset(hero ? 8 : 6, hero ? 10 : 8),
              blurRadius: 0,
            ),
          ],
        ),
        child: DefaultTextStyle.merge(
          style: GoogleFonts.montserrat(
            fontWeight: hero ? FontWeight.w800 : FontWeight.w600,
            fontSize: hero ? 19 : 13,
            height: hero ? 1.3 : 1.35,
            color: theme.textTheme.bodyLarge?.color,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Компактный бейдж рейтинга поверх пузыря — тёмная плашка со звездой,
/// как в компоненте VenueBubble бандла.
class BubbleRatingBadge extends StatelessWidget {
  final int stars;
  const BubbleRatingBadge({super.key, required this.stars});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.darkChip(isDark),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('★ $stars',
          style: GoogleFonts.jetBrainsMono(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: Colors.white)),
    );
  }
}
