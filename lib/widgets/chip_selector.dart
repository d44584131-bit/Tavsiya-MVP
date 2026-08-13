import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_dimens.dart';

class ChipSelector extends StatelessWidget {
  final String label;
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  const ChipSelector({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((o) {
            final isActive = o == selected;
            return Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.tag),
              child: InkWell(
                onTap: () => onSelected(o),
                borderRadius: BorderRadius.circular(AppRadius.tag),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color:
                        isActive ? theme.colorScheme.primary : theme.cardColor,
                    borderRadius: BorderRadius.circular(AppRadius.tag),
                    border: Border.all(
                        color: isActive
                            ? theme.colorScheme.primary
                            : theme.dividerColor),
                  ),
                  child: Text(
                    o.toUpperCase(),
                    style: GoogleFonts.jetBrainsMono(
                      color: isActive
                          ? Colors.white
                          : theme.textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
