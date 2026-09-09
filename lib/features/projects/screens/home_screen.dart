import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/design_document.dart';
import '../../../shared/models/opening_model.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/responsive.dart';
import '../../configurator/state/design_session.dart';
import '../../rendering/widgets/technical_drawing_view.dart';
import '../design_library.dart';
import '../design_templates.dart';

/// The way in: start a new drawing, pick up an unfinished one, or open a
/// design you saved.
class HomeScreen extends ConsumerWidget {
  final void Function(DesignDocument design) onOpenDrawing;
  final void Function(DesignDocument design) onOpenDesign;

  const HomeScreen({
    super.key,
    required this.onOpenDrawing,
    required this.onOpenDesign,
  });

  Future<void> _create(BuildContext context, WidgetRef ref, OpeningKind kind) async {
    final design = await ref.read(designLibraryProvider.notifier).create(kind);
    ref.read(designSessionProvider.notifier).open(design);
    onOpenDrawing(design);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final designs = ref.watch(designLibraryProvider);
    final draft = ref.watch(recoverableDraftProvider).value;
    final size = screenSizeOf(context);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(size.isCompact ? AppSpacing.md : AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppConstants.appName,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandDarkGreen,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Draw a door or window by hand. Get the real thing in 3D.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _StartRow(
                      compact: size.isCompact,
                      onDoor: () => _create(context, ref, OpeningKind.door),
                      onWindow: () => _create(context, ref, OpeningKind.window),
                    ),
                    if (draft != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _DraftBanner(
                        draft: draft,
                        onResume: () {
                          ref.read(designSessionProvider.notifier).open(draft);
                          onOpenDrawing(draft);
                        },
                        onDiscard: () async {
                          await ref.read(designRepositoryProvider).clearDraft();
                          ref.invalidate(recoverableDraftProvider);
                        },
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    _TemplateStrip(
                      onSelected: (template) async {
                        final design = await ref
                            .read(designLibraryProvider.notifier)
                            .createFromTemplate(template);
                        ref.read(designSessionProvider.notifier).open(design);
                        onOpenDesign(design);
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const SectionHeader(title: 'Your designs'),
                  ],
                ),
              ),
            ),
            designs.when(
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.error_outline,
                  title: 'Could not load your designs',
                  message: '$error',
                ),
              ),
              data: (list) => list.isEmpty
                  ? const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.draw_outlined,
                        title: 'Nothing saved yet',
                        message: 'Start a door or a window above and draw it '
                            'the way you would on paper.',
                      ),
                    )
                  : SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        size.isCompact ? AppSpacing.md : AppSpacing.xl,
                        0,
                        size.isCompact ? AppSpacing.md : AppSpacing.xl,
                        AppSpacing.xl,
                      ),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 280,
                          mainAxisSpacing: AppSpacing.sm,
                          crossAxisSpacing: AppSpacing.sm,
                          childAspectRatio: 0.82,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _DesignCard(
                            design: list[index],
                            onOpen: () {
                              ref.read(designSessionProvider.notifier).open(list[index]);
                              onOpenDesign(list[index]);
                            },
                            onDraw: () {
                              ref.read(designSessionProvider.notifier).open(list[index]);
                              onOpenDrawing(list[index]);
                            },
                            onDuplicate: () =>
                                ref.read(designLibraryProvider.notifier).duplicate(list[index]),
                            onDelete: () =>
                                ref.read(designLibraryProvider.notifier).remove(list[index].id),
                          ),
                          childCount: list.length,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartRow extends StatelessWidget {
  final bool compact;
  final VoidCallback onDoor;
  final VoidCallback onWindow;

  const _StartRow({required this.compact, required this.onDoor, required this.onWindow});

  @override
  Widget build(BuildContext context) {
    final door = _StartTile(
      icon: Icons.sensor_door_outlined,
      title: 'New door',
      message: 'Single, double, with glass or panels',
      onTap: onDoor,
    );
    final window = _StartTile(
      icon: Icons.window_outlined,
      title: 'New window',
      message: 'Fixed, casement, sliding, combinations',
      onTap: onWindow,
    );

    if (compact) {
      return Column(
        children: [door, const SizedBox(height: AppSpacing.sm), window],
      );
    }
    return Row(
      children: [
        Expanded(child: door),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: window),
      ],
    );
  }
}

class _StartTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onTap;

  const _StartTile({
    required this.icon,
    required this.title,
    required this.message,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: AppColors.brandDarkGreen,
      border: Border.all(color: AppColors.brandDarkGreen),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, color: AppColors.brandCream, size: 30),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.brandCream,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textOnDarkMuted),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward, color: AppColors.brandCream, size: 18),
        ],
      ),
    );
  }
}

class _DraftBanner extends StatelessWidget {
  final DesignDocument draft;
  final VoidCallback onResume;
  final VoidCallback onDiscard;

  const _DraftBanner({
    required this.draft,
    required this.onResume,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.brandCreamSoft,
      border: Border.all(color: AppColors.brandCreamDeep),
      child: Row(
        children: [
          const Icon(Icons.restore, color: AppColors.brandDarkGreen),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recover unfinished design?',
                    style: Theme.of(context).textTheme.titleSmall),
                Text(
                  '${draft.name} · ${draft.sketch.strokes.length} strokes',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(onPressed: onDiscard, child: const Text('Discard')),
          FilledButton(onPressed: onResume, child: const Text('Resume')),
        ],
      ),
    );
  }
}

class _DesignCard extends StatelessWidget {
  final DesignDocument design;
  final VoidCallback onOpen;
  final VoidCallback onDraw;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _DesignCard({
    required this.design,
    required this.onOpen,
    required this.onDraw,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onOpen,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusMd)),
              child: DesignThumbnail(model: design.model),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  design.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '${design.kind.label} · ${design.sizeLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: onDraw,
                        icon: const Icon(Icons.gesture, size: 16),
                        label: const Text('Drawing'),
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'More',
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      onSelected: (value) =>
                          value == 'duplicate' ? onDuplicate() : onDelete(),
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


/// Ready-made starting points. A shortcut only — everything a template
/// produces is an ordinary editable design, and drawing from scratch still
/// supports geometry no template covers.
class _TemplateStrip extends StatelessWidget {
  final ValueChanged<DesignTemplate> onSelected;

  const _TemplateStrip({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Or start from a template',
          subtitle: 'Then edit it, or draw over it',
        ),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: designTemplates.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
            itemBuilder: (context, index) {
              final template = designTemplates[index];
              return SizedBox(
                width: 132,
                child: AppCard(
                  padding: EdgeInsets.zero,
                  onTap: () => onSelected(template),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(AppSpacing.radiusMd),
                          ),
                          child: DesignThumbnail(model: template.build(template.id)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              template.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            Text(
                              template.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
              );
            },
          ),
        ),
      ],
    );
  }
}
