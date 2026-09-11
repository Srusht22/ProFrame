import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/geometry_structure.dart';
import '../../../shared/models/opening_model.dart';
import '../../../shared/models/sketch.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../drawing/painters/sketch_preview.dart';
import '../../geometry/design_comparator.dart';
import 'technical_drawing_view.dart';

/// Your drawing beside what the app made of it, with the differences named.
///
/// The point is verification, not decoration: the user can see at a glance
/// whether the app reproduced their design, and the checklist says so in
/// numbers rather than asking them to trust it.
class OriginalVsResult extends StatelessWidget {
  final Sketch sketch;
  final OpeningModel model;
  final GeometryStructure? structure;

  const OriginalVsResult({
    super.key,
    required this.sketch,
    required this.model,
    this.structure,
  });

  @override
  Widget build(BuildContext context) {
    final comparison = structure == null
        ? DesignComparison.none
        : const DesignComparator().compare(structure!, model);

    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = constraints.maxWidth >= 560;
        final panes = [
          _Pane(
            title: 'What you drew',
            child: SketchPreview(sketch: sketch),
          ),
          _Pane(
            title: 'What the app made',
            child: TechnicalDrawingView(
              model: model,
              interactive: false,
              showDimensions: false,
            ),
          ),
        ];

        return Column(
          children: [
            Expanded(
              child: sideBySide
                  ? Row(
                      children: [
                        Expanded(child: panes[0]),
                        const VerticalDivider(width: 1),
                        Expanded(child: panes[1]),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(child: panes[0]),
                        const Divider(height: 1),
                        Expanded(child: panes[1]),
                      ],
                    ),
            ),
            if (comparison.checks.isNotEmpty)
              _Checklist(comparison: comparison),
          ],
        );
      },
    );
  }
}

class _Pane extends StatelessWidget {
  final String title;
  final Widget child;

  const _Pane({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 6,
          ),
          color: AppColors.neutralSurface,
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge,
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _Checklist extends StatelessWidget {
  final DesignComparison comparison;

  const _Checklist({required this.comparison});

  @override
  Widget build(BuildContext context) {
    final allMatch = comparison.allMatch;
    final colour = allMatch ? AppColors.success : AppColors.warning;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 230),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    allMatch ? Icons.verified_outlined : Icons.report_problem_outlined,
                    size: 18,
                    color: colour,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      allMatch
                          ? 'Your design was reproduced exactly'
                          : '${comparison.mismatches.length} '
                              '${comparison.mismatches.length == 1 ? 'thing does' : 'things do'} '
                              'not match your drawing',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final check in comparison.checks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        check.matches ? Icons.check : Icons.priority_high,
                        size: 15,
                        color: check.matches ? AppColors.success : AppColors.warning,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              check.label,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Text(
                              'drawn ${check.drawn}  ·  built ${check.generated}'
                              '${check.note == null ? '' : '  ·  ${check.note}'}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
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

/// A compact version for the interpretation screen, where the drawing and the
/// result are already the focus.
class ComparisonSummary extends StatelessWidget {
  final GeometryStructure structure;
  final OpeningModel model;

  const ComparisonSummary({super.key, required this.structure, required this.model});

  @override
  Widget build(BuildContext context) {
    final comparison = const DesignComparator().compare(structure, model);
    if (comparison.checks.isEmpty) return const SizedBox.shrink();

    final allMatch = comparison.allMatch;
    final colour = allMatch ? AppColors.success : AppColors.warning;

    return AppCard(
      color: colour.withValues(alpha: 0.08),
      border: Border.all(color: colour.withValues(alpha: 0.3)),
      child: Row(
        children: [
          Icon(
            allMatch ? Icons.verified_outlined : Icons.report_problem_outlined,
            color: colour,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allMatch
                      ? 'Matches your drawing'
                      : '${comparison.mismatches.length} '
                          '${comparison.mismatches.length == 1 ? 'difference' : 'differences'} '
                          'from your drawing',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '${structure.sectionCount} sections, '
                  '${structure.dividerCount} divisions, '
                  '${structure.openingCount} openings — '
                  '${allMatch ? 'all reproduced' : comparison.mismatches.map((c) => c.label.toLowerCase()).join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
