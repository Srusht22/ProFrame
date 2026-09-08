import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';

/// A section title with trailing actions that lays out as a single row on
/// wide screens and stacks the actions underneath the title on narrow ones.
///
/// Plain `Row(mainAxisAlignment: spaceBetween)` silently pushes buttons off
/// the right edge on phone widths (making them unreachable), which is what
/// this widget exists to prevent.
class ResponsiveHeaderRow extends StatelessWidget {
  final String title;
  final List<Widget> actions;

  /// Below this width the actions wrap onto their own line.
  final double stackBelowWidth;

  const ResponsiveHeaderRow({
    super.key,
    required this.title,
    this.actions = const [],
    this.stackBelowWidth = 520,
  });

  @override
  Widget build(BuildContext context) {
    final titleWidget = Text(title, style: Theme.of(context).textTheme.titleMedium);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (actions.isEmpty) return titleWidget;

        if (constraints.maxWidth < stackBelowWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleWidget,
              const SizedBox(height: AppSpacing.sm),
              Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: actions),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: titleWidget),
            Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: actions),
          ],
        );
      },
    );
  }
}
