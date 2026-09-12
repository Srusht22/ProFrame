import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import '../../core/i18n/strings.dart';
import '../../core/layout/responsive.dart';
import '../../domain/design_document.dart';
import '../../infrastructure/project_repository.dart';
import '../i18n/labels.dart';
import '../state/project_controller.dart';
import '../widgets/dimension_input.dart';
import '../widgets/notice.dart';

/// The list of saved projects — the app's front door (spec section 3).
///
/// Every destructive action asks first, and nothing is removed without the
/// user naming what they are removing.
class ProjectsScreen extends ConsumerWidget {
  /// Starts the new-design flow.
  final VoidCallback onNew;

  /// Opens a saved project for editing.
  final void Function(DesignDocument design) onOpen;

  /// Reads a `.proframe` file the user picked.
  final VoidCallback onImport;

  /// Opens the factory settings.
  final VoidCallback onSettings;

  const ProjectsScreen({
    required this.onNew,
    required this.onOpen,
    required this.onImport,
    required this.onSettings,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectListProvider);
    final s = context.s;

    return Scaffold(
      appBar: AppBar(
        title: Text(s(T.appName)),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_open_outlined),
            tooltip: s(T.openProjectFile),
            onPressed: onImport,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: s(T.factorySettings),
            onPressed: onSettings,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onNew,
        icon: const Icon(Icons.add),
        label: Text(s(T.newDesign)),
      ),
      body: SafeArea(
        child: ResponsiveBuilder(
          builder: (context, size) => projects.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            // Scrollable, and the detail is trimmed: an error object can
            // carry a whole stack trace, and rendering that raw would push an
            // unbounded column down the screen.
            error: (error, _) => SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Notice(
                tone: NoticeTone.problem,
                title: s(T.projectsUnreadable),
                message: _shorten('$error'),
              ),
            ),
            data: (list) => list.isEmpty
                ? const _EmptyState()
                : _ProjectList(
                    projects: list,
                    columns: size.width >= 900 ? 2 : 1,
                    onOpen: (summary) => _open(context, ref, summary),
                    onRename: (summary) => _rename(context, ref, summary),
                    onDuplicate: (summary) => _duplicate(context, ref, summary),
                    onDelete: (summary) => _delete(context, ref, summary),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    ProjectSummary summary,
  ) async {
    final repository = ref.read(projectRepositoryProvider);
    try {
      final design = await repository.load(summary.id);
      if (design == null) {
        if (context.mounted) _say(context, context.s(T.projectGone));
        return;
      }
      onOpen(design);
    } on Object catch (error) {
      if (context.mounted) _say(context, '$error');
    }
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    ProjectSummary summary,
  ) async {
    final name = await askForNote(
      context,
      title: context.s(T.renameProject),
      helper: context.s(T.whatShouldItBeCalled),
      current: summary.name,
    );
    if (name == null || name.trim().isEmpty) return;

    final repository = ref.read(projectRepositoryProvider);
    final design = await repository.load(summary.id);
    if (design == null) return;
    await repository.save(
      design.copyWith(name: name.trim(), updatedAt: DateTime.now()),
    );
    ref.invalidate(projectListProvider);
  }

  Future<void> _duplicate(
    BuildContext context,
    WidgetRef ref,
    ProjectSummary summary,
  ) async {
    final repository = ref.read(projectRepositoryProvider);
    final design = await repository.load(summary.id);
    if (design == null) return;
    await repository.duplicate(
      design,
      newId: 'p${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
    );
    ref.invalidate(projectListProvider);
    if (context.mounted) {
      _say(context, context.s(T.projectCopied, {'name': summary.name}));
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ProjectSummary summary,
  ) async {
    // Deleting is the one thing that cannot be undone, so it asks — and the
    // dialogue names the project, so nobody deletes the wrong one
    // (spec section 3).
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.s(T.deleteProjectTitle)),
        content: Text(
          context.s(T.deleteProjectBody, {'name': summary.name}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.s(T.keepIt)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.s(T.delete)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(projectRepositoryProvider).delete(summary.id);
    ref.invalidate(projectListProvider);
    if (context.mounted) {
      _say(context, context.s(T.projectDeleted, {'name': summary.name}));
    }
  }

  /// Keeps a message to something a person will actually read.
  static String _shorten(String text, {int limit = 300}) {
    final firstLine = text.split('\n').first.trim();
    return firstLine.length <= limit
        ? firstLine
        : '${firstLine.substring(0, limit)}…';
  }

  static void _say(BuildContext context, String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.draw_outlined,
                size: 56,
                color: AppColors.deepGreen,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                context.s(T.noSavedDesigns),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                context.s(T.noSavedDesignsHelp),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.mutedText),
              ),
            ],
          ),
        ),
      );
}

class _ProjectList extends StatelessWidget {
  final List<ProjectSummary> projects;
  final int columns;
  final void Function(ProjectSummary) onOpen;
  final void Function(ProjectSummary) onRename;
  final void Function(ProjectSummary) onDuplicate;
  final void Function(ProjectSummary) onDelete;

  const _ProjectList({
    required this.projects,
    required this.columns,
    required this.onOpen,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          // Room for the floating button not to sit on the last card.
          AppSpacing.xxl * 2,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: AppSpacing.xs,
          crossAxisSpacing: AppSpacing.xs,
          mainAxisExtent: 108,
        ),
        itemCount: projects.length,
        itemBuilder: (context, index) => _ProjectCard(
          project: projects[index],
          onOpen: () => onOpen(projects[index]),
          onRename: () => onRename(projects[index]),
          onDuplicate: () => onDuplicate(projects[index]),
          onDelete: () => onDelete(projects[index]),
        ),
      );
}

/// What a project is, in a few words, in the app's language.
///
/// Built here rather than stored with the project, so changing language
/// changes the card — and so a saved file never carries an English sentence
/// that cannot be translated later.
String _describe(BuildContext context, ProjectSummary project) {
  final s = context.s;
  if (project.isDamaged) return s(T.projectDamaged);

  final size = project.isMeasured
      ? '${s.number(project.widthMm!)} × ${s.number(project.heightMm!)} '
          '${s(T.unitMillimetre)}'
      : s(T.notMeasured);
  final category = project.category;
  final material = project.material;

  return [
    if (category != null) s.product(category),
    if (material != null) s.frameMaterial(material),
    size,
    s(T.panelCount, {'count': s.number(project.panelCount)}),
  ].join(' · ');
}

class _ProjectCard extends StatelessWidget {
  final ProjectSummary project;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _ProjectCard({
    required this.project,
    required this.onOpen,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        // A damaged project cannot be opened, but it can still be deleted —
        // which is why it is listed at all.
        onTap: project.isDamaged ? null : onOpen,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        if (project.isDamaged) ...[
                          const Icon(
                            Icons.error_outline,
                            size: 18,
                            color: AppColors.danger,
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                        ],
                        Expanded(
                          child: Text(
                            project.isDamaged
                                ? context.s(T.damagedProject)
                                : project.name,
                            style: theme.textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      _describe(context, project),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.mutedText),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: context.s(T.moreForProject, {'name': project.name}),
                onSelected: (choice) => switch (choice) {
                  'rename' => onRename(),
                  'duplicate' => onDuplicate(),
                  _ => onDelete(),
                },
                itemBuilder: (context) => [
                  if (!project.isDamaged) ...[
                    PopupMenuItem(
                      value: 'rename',
                      child: Text(context.s(T.rename)),
                    ),
                    PopupMenuItem(
                      value: 'duplicate',
                      child: Text(context.s(T.duplicate)),
                    ),
                  ],
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(context.s(T.delete)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
