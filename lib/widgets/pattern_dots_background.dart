import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Точечная "бумага" — фирменный фон Ember (18px сетка, точка 1.4px).
/// Единственный фоновый мотив бренда: без фото, без градиентов.
class PatternDotsBackground extends StatelessWidget {
  final Widget child;
  const PatternDotsBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
      child: CustomPaint(
        painter: _DotsPainter(
          dotColor:
              isDark ? const Color(0xFF2E2B28) : const Color(0xFFE2DED6),
        ),
        child: child,
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  final Color dotColor;
  const _DotsPainter({required this.dotColor});

  static const double _grid = 18;
  static const double _radius = 1.4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = dotColor;
    for (double y = _grid / 2; y < size.height; y += _grid) {
      for (double x = _grid / 2; x < size.width; x += _grid) {
        canvas.drawCircle(Offset(x, y), _radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter oldDelegate) =>
      oldDelegate.dotColor != dotColor;
}

/// Мелкий рукописный акцент-глиф (стенд-ин фирменных "завитков" из
/// референса) — чисто декоративный элемент, не несёт смысла.
class Doodle extends StatelessWidget {
  final double size;
  final double rotateDeg;
  final String glyph;
  const Doodle(
      {super.key, this.size = 26, this.rotateDeg = -14, this.glyph = 'e'});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return IgnorePointer(
      child: Opacity(
        opacity: isDark ? 0.65 : 0.5,
        child: Transform.rotate(
          angle: rotateDeg * 3.1415926535 / 180,
          child: Text(
            glyph,
            style: GoogleFonts.jetBrainsMono(
              fontSize: size,
              height: 1,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
