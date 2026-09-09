import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/design_document.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../rendering/widgets/technical_drawing_view.dart';
import '../state/design_session.dart';

/// Every save is a restore point. The list shows what each version was, so a
/// change can be compared and rolled back (§47).
class VersionHistorySheet extends ConsumerWidget {
  const VersionHistorySheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => const FractionallySizedBox(
          heightFactor: 0.85,
          child: VersionHistorySheet(),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(designSessionProvider);
    final design = session.document;
    final versions = design?.versions ?? const <DesignVersion>[];

    if (design == null || versions.isEmpty) {
      return const EmptyState(
        icon: Icons.history,
        title: 'No versions yet',
        message: 'A restore point is created every time you save the design.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: versions.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        if (index == 0) {
          return const SectionHeader(
            title: 'Version history',
            subtitle: 'Tap a version to compare it, then restore it',
          );
        }
        final version = versions[index - 1];
        final current = design.model;
        final changed = version.model.widthMm != current.widthMm ||
            version.model.heightMm != current.heightMm ||
            version.model.leafRegions.length != current.leafRegions.length;

        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: DesignThumbnail(model: version.model),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(version.label, style: Theme.of(context).textTheme.titleSmall),
                    Text(
                      '${version.model.widthMm.round()} × '
                      '${version.model.heightMm.round()} mm · '
                      '${version.model.leafRegions.length} sections',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      _formatTime(version.createdAt),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textMuted),
                    ),
                    if (changed)
                      Text(
                        'Differs from the current design',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.warning),
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  ref.read(designSessionProvider.notifier).restoreVersion(version.id);
                  Navigator.of(context).pop();
                },
                child: const Text('Restore'),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _formatTime(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} '
        '${two(time.hour)}:${two(time.minute)}';
  }
}
