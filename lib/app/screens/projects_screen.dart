import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import '../../core/layout/responsive.dart';
import '../../domain/design_document.dart';
import '../../infrastructure/project_repository.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('ProFrame'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_open_outlined),
            tooltip: 'Open a project file',
            onPressed: onImport,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Factory settings',
            onPressed: onSettings,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onNew,
        icon: const Icon(Icons.add),
        label: const Text('New design'),
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
                title: 'Saved projects could not be read',
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
        if (context.mounted) _say(context, 'That project is no longer there.');
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
      title: 'Rename project',
      helper: 'What should this design be called?',
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
    if (context.mounted) _say(context, 'Copied "${summary.name}".');
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
        title: const Text('Delete this project?'),
        content: Text(
          '"${summary.name}" will be removed from this device. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(projectRepositoryProvider).delete(summary.id);
    ref.invalidate(projectListProvider);
    if (context.mounted) _say(context, 'Deleted "${summary.name}".');
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
                'No saved designs yet',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Tap New design, choose a door or a window, and draw it the '
                'way you would on paper.',
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
                            project.name,
                            style: theme.textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      project.description,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.mutedText),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'More for ${project.name}',
                onSelected: (choice) => switch (choice) {
                  'rename' => onRename(),
                  'duplicate' => onDuplicate(),
                  _ => onDelete(),
                },
                itemBuilder: (context) => [
                  if (!project.isDamaged) ...const [
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                  ],
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
