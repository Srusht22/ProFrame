import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';

/// A large, unmissable choice — the Door/Window and PVC/Aluminium decisions
/// that open the workflow (spec section 3A).
///
/// Selection is shown three ways at once: a filled background, a border, and a
/// tick with the word "Selected" in the semantics. Colour is never the only
/// signal (spec section 7).
class ChoiceCard extends StatelessWidget {
  final String label;
  final String? description;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  const ChoiceCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
    this.description,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected ? AppColors.cream : AppColors.deepGreen;

    return Semantics(
      button: true,
      selected: selected,
      label: selected ? '$label, selected' : label,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? AppColors.deepGreen : AppColors.canvasSurface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              constraints: const BoxConstraints(
                minHeight: AppSizing.primaryChoiceMinHeight,
                minWidth: AppSizing.minTouchTarget,
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: selected ? AppColors.deepGreen : AppColors.outline,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: foreground, size: 28),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          label,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (selected) Icon(Icons.check, color: foreground),
                    ],
                  ),
                  if (description != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: selected ? AppColors.cream : AppColors.mutedText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
