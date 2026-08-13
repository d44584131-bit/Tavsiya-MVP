import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// "Папка"-категория со сплошной заливкой и корешком сверху — как
/// CategoryFolder в бандле Ember. [count] опционален (не выдумываем цифры,
/// если реальных данных нет).
class CategoryFolderCard extends StatefulWidget {
  final String label;
  final String? count;
  final Color color;
  final bool onDark;
  final bool active;
  final VoidCallback? onTap;
  // Для карточек с коротким текстом в ряду одинаковой высоты (напр.
  // "Подборки для вас") — центрируем содержимое, а не жмём в левый верхний
  // угол как в "папках" категорий (там текст нарочно у корешка).
  final bool centerContent;

  const CategoryFolderCard({
    super.key,
    required this.label,
    required this.color,
    this.count,
    this.onDark = true,
    this.active = false,
    this.onTap,
    this.centerContent = false,
  });

  @override
  State<CategoryFolderCard> createState() => _CategoryFolderCardState();
}

class _CategoryFolderCardState extends State<CategoryFolderCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final count = widget.count;
    final color = widget.color;
    final onDark = widget.onDark;
    final active = widget.active;
    final onTap = widget.onTap;
    final centerContent = widget.centerContent;
    final strong = onDark ? Colors.white : const Color(0xFF111111);
    final quiet = onDark
        ? Colors.white.withValues(alpha: 0.8)
        : Colors.black.withValues(alpha: 0.55);
    // Лёгкий "прыжок" при нажатии — папка чуть сжимается и поворачивается,
    // как будто её тронули пальцем, а не просто плоский тап без отклика.
    return GestureDetector(
      onTapDown: onTap == null ? null : (_) => _setPressed(true),
      onTapUp: onTap == null ? null : (_) => _setPressed(false),
      onTapCancel: onTap == null ? null : () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedRotation(
          turns: _pressed ? (onDark ? -0.006 : 0.006) : 0,
          duration: const Duration(milliseconds: 120),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: LayoutBuilder(
          builder: (context, constraints) {
            final cardHeight =
                constraints.hasBoundedHeight && constraints.maxHeight.isFinite
                    ? constraints.maxHeight - 18
                    : null;
            return Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 14,
                    top: -18,
                    child: Container(
                      width: 70,
                      height: 18,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(9)),
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    height: cardHeight,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(16),
                      border: active
                          ? Border.all(color: Colors.white, width: 2.5)
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: centerContent
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.start,
                      mainAxisAlignment: centerContent
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign:
                                centerContent ? TextAlign.center : TextAlign.start,
                            style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                height: 1.15,
                                color: strong)),
                        if (count != null) ...[
                          const SizedBox(height: 3),
                          Text(count,
                              textAlign: centerContent
                                  ? TextAlign.center
                                  : TextAlign.start,
                              style: GoogleFonts.jetBrainsMono(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: quiet)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
