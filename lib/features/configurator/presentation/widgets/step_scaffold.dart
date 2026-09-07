import 'package:flutter/material.dart';
import '../../../../core/theme/app_spacing.dart';

/// Common wrapper every configurator step uses: a title, an optional
/// helper line, and a scrollable body. Keeps step widgets focused on their
/// fields instead of repeating layout boilerplate.
class StepScaffold extends StatelessWidget {
  final String title;
  final String? helperText;
  final List<Widget> children;

  const StepScaffold({super.key, required this.title, this.helperText, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(title, style: theme.textTheme.headlineSmall),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(helperText!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
        ],
        const SizedBox(height: AppSpacing.lg),
        ...children,
      ],
    );
  }
}

class FieldGroup extends StatelessWidget {
  final String label;
  final Widget child;

  const FieldGroup({super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}
