import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// The visual-selection card used throughout the configurator (spec §39:
/// "visual selection cards" rather than raw dropdowns for the choices that
/// benefit from it). Selected state uses the brand cream fill on a dark
/// green border, matching the "cream = selected configuration state"
/// guidance.
class OptionCard extends StatelessWidget {
  final IconData? icon;
  final Color? colorSwatch;
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const OptionCard({
    super.key,
    this.icon,
    this.colorSwatch,
    required this.label,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 132,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandCream.withValues(alpha: 0.35) : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: selected ? AppColors.brandDarkGreen : theme.colorScheme.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (colorSwatch != null)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colorSwatch,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
              )
            else if (icon != null)
              Icon(icon, size: 22, color: selected ? AppColors.brandDarkGreen : theme.colorScheme.onSurface),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: selected ? AppColors.brandDarkGreenDeep : theme.colorScheme.onSurface,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }
}
