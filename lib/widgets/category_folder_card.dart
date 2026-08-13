import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// "Папка"-категория со сплошной заливкой и корешком сверху — как
/// CategoryFolder в бандле Ember. [count] опционален (не выдумываем цифры,
/// если реальных данных нет).
class CategoryFolderCard extends StatelessWidget {
  final String label;
  final String? count;
  final Color color;
  final bool onDark;
  final bool active;
  final VoidCallback? onTap;

  const CategoryFolderCard({
    super.key,
    required this.label,
    required this.color,
    this.count,
    this.onDark = true,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final strong = onDark ? Colors.white : const Color(0xFF111111);
    final quiet = onDark
        ? Colors.white.withValues(alpha: 0.8)
        : Colors.black.withValues(alpha: 0.55);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 12,
                top: -16,
                child: Container(
                  width: 64,
                  height: 16,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(13, 12, 13, 11),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                  border: active
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label,
                        style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: strong)),
                    if (count != null) ...[
                      const SizedBox(height: 2),
                      Text(count!,
                          style: GoogleFonts.jetBrainsMono(
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                              color: quiet)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
