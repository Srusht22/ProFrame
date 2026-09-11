import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/interpretation.dart';
import '../../../shared/models/sketch.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/responsive.dart';
import '../../rendering/widgets/original_vs_result.dart';
import '../state/design_session.dart';

/// "Understanding your design" — the app says exactly what it read from the
/// sketch, ticks off what it is sure about and asks about the rest (§16).
class InterpretationScreen extends ConsumerWidget {
  final VoidCallback onEditDrawing;
  final VoidCallback onConfirm;

  const InterpretationScreen({
    super.key,
    required this.onEditDrawing,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(designSessionProvider);
    final report = session.report;
    final model = session.model;

    if (session.isInterpreting) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (session.error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Understanding your design')),
        body: EmptyState(
          icon: Icons.help_outline,
          title: 'The drawing could not be read',
          message: session.error!,
          action: FilledButton.icon(
            onPressed: onEditDrawing,
            icon: const Icon(Icons.edit),
            label: const Text('Back to the drawing'),
          ),
        ),
      );
    }

    if (model == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Understanding your design')),
        body: EmptyState(
          icon: Icons.draw_outlined,
          title: 'Nothing to read yet',
          message: 'Draw the outline of the door or window first.',
          action: FilledButton(onPressed: onEditDrawing, child: const Text('Start drawing')),
        ),
      );
    }

    final structure = session.interpretation?.structure;
    final sketch = session.document?.sketch;

    // The drawing and the result side by side: the user checks the app's work
    // rather than being asked to trust it.
    final preview = DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: OriginalVsResult(
          sketch: sketch ?? const Sketch(),
          model: model,
          structure: structure,
        ),
      ),
    );

    final details = _Details(report: report);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Understanding your design'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to the drawing',
          onPressed: onEditDrawing,
        ),
      ),
      body: ResponsiveLayout(
        compact: (context) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _ConfidenceBanner(report: report),
            if (structure != null) ...[
              const SizedBox(height: AppSpacing.xs),
              ComparisonSummary(structure: structure, model: model),
            ],
            const SizedBox(height: AppSpacing.md),
            SizedBox(height: 420, child: preview),
            const SizedBox(height: AppSpacing.md),
            details,
          ],
        ),
        expanded: (context) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    _ConfidenceBanner(report: report),
                    if (structure != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      ComparisonSummary(structure: structure, model: model),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Expanded(child: preview),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 420,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [details],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEditDrawing,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit drawing'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onConfirm,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Confirm design'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfidenceBanner extends StatelessWidget {
  final InterpretationReport report;

  const _ConfidenceBanner({required this.report});

  @override
  Widget build(BuildContext context) {
    final percent = (report.confidence * 100).round();
    final questions = report.uncertain.length;
    final color = questions == 0 ? AppColors.success : AppColors.warning;
    return AppCard(
      color: color.withValues(alpha: 0.08),
      border: Border.all(color: color.withValues(alpha: 0.3)),
      child: Row(
        children: [
          Icon(questions == 0 ? Icons.verified_outlined : Icons.help_outline, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  questions == 0
                      ? 'Everything was read clearly'
                      : '$questions ${questions == 1 ? 'thing needs' : 'things need'} your confirmation',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'Overall confidence $percent%. Nothing is changed until you choose.',
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

class _Details extends ConsumerWidget {
  final InterpretationReport report;

  const _Details({required this.report});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uncertain = report.uncertain;
    final recognised = report.recognised;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (uncertain.isNotEmpty) ...[
          const SectionHeader(
            title: 'Needs your answer',
            subtitle: 'These are guesses. Pick the right one.',
          ),
          for (final item in uncertain) ...[
            _ItemCard(item: item),
            const SizedBox(height: AppSpacing.xs),
          ],
          const SizedBox(height: AppSpacing.md),
        ],
        const SectionHeader(title: 'Read from your drawing'),
        for (final item in recognised) ...[
          _ItemCard(item: item),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _ItemCard extends ConsumerWidget {
  final InterpretationItem item;

  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (color, icon, label) = switch (item.level) {
      InterpretationLevel.recognised => (AppColors.success, Icons.check_circle_outline, 'Read'),
      InterpretationLevel.uncertain => (AppColors.warning, Icons.help_outline, 'Unsure'),
      InterpretationLevel.missing => (AppColors.error, Icons.error_outline, 'Missing'),
    };

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(item.title, style: Theme.of(context).textTheme.titleSmall),
              ),
              StatusChip(label: label, color: color, icon: icon),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(
              item.detail,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          if (item.choices.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: item.choices
                    .map((choice) => ActionChip(
                          avatar: choice.isSuggested
                              ? const Icon(Icons.star, size: 14)
                              : null,
                          label: Text(choice.label),
                          onPressed: () =>
                              ref.read(designSessionProvider.notifier).applyChoice(choice),
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
