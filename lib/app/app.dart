import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/app_theme.dart';
import '../core/layout/responsive.dart';
import '../domain/design_document.dart';
import 'screens/canvas_screen.dart';
import 'screens/export_sheet.dart';
import 'screens/new_design_screen.dart';
import 'screens/projects_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/viewer_screen.dart';
import 'state/design_controller.dart';
import 'state/project_controller.dart';
import 'state/viewer_controller.dart';
import 'widgets/import_dialog.dart';

/// The application root.
///
/// The whole agreed workflow is here: projects → choose → draw → measure and
/// assign → 2.5D → notes → save and export.
class ProFrameApp extends StatelessWidget {
  /// Supplies project ids. Injected so a test can make them deterministic.
  final String Function() idFactory;

  const ProFrameApp({required this.idFactory, super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ProFrame',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        builder: (context, child) =>
            BoundedTextScale(child: child ?? const SizedBox.shrink()),
        home: _Flow(idFactory: idFactory),
      );
}

/// Where the user is.
enum _Step { projects, choosing, drawing, previewing, settings }

class _Flow extends ConsumerStatefulWidget {
  final String Function() idFactory;

  const _Flow({required this.idFactory});

  @override
  ConsumerState<_Flow> createState() => _FlowState();
}

class _FlowState extends ConsumerState<_Flow> {
  _Step _step = _Step.projects;

  /// True once the unfinished-work prompt has been answered, so it is offered
  /// once rather than every time the list is shown.
  bool _draftOffered = false;

  /// Opens [design] for editing and puts the app on the canvas.
  void _open(DesignDocument design) {
    ref.read(designControllerProvider.notifier).open(design);
    ref.read(viewerControllerProvider.notifier).closeAll();
    ref.read(saveControllerProvider.notifier).reset();
    setState(() => _step = _Step.drawing);
  }

  /// Leaves the editor, checking first that nothing unsaved is being dropped.
  Future<void> _leaveEditor() async {
    final save = ref.read(saveControllerProvider);
    if (!save.isDirty) {
      setState(() => _step = _Step.projects);
      return;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save before leaving?'),
        content: const Text(
          'This design has changes that are not saved yet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('discard'),
            child: const Text('Leave without saving'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (!mounted || choice == null || choice == 'cancel') return;
    if (choice == 'save') {
      final design = ref.read(designControllerProvider).design;
      final saved =
          await ref.read(saveControllerProvider.notifier).save(design);
      if (!mounted || !saved) return;
    }
    setState(() => _step = _Step.projects);
  }

  Future<void> _import() async {
    final design = await showImportDialog(context);
    if (design == null || !mounted) return;
    // An imported project is saved straight away, so it appears in the list
    // even if the user backs out without editing.
    await ref.read(projectRepositoryProvider).save(design);
    ref.invalidate(projectListProvider);
    if (!mounted) return;
    _open(design);
  }

  /// Offers to recover an unfinished design from a previous run.
  void _offerDraft(DesignDocument draft) {
    _draftOffered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final recover = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Recover unfinished design?'),
          content: Text(
            '"${draft.name}" was being worked on when the app last closed. '
            'It has not been saved as a project yet.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Discard it'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Recover'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (recover == true) {
        _open(draft);
      } else {
        await ref.read(projectRepositoryProvider).clearDraft();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Autosave: every change to the design schedules a draft write.
    ref.listen(designControllerProvider, (previous, next) {
      if (previous?.design == next.design) return;
      ref.read(saveControllerProvider.notifier).markChanged(next.design);
    });

    if (_step == _Step.projects && !_draftOffered) {
      final draft = ref.watch(recoverableDraftProvider).value;
      if (draft != null) _offerDraft(draft);
    }

    return switch (_step) {
      _Step.projects => ProjectsScreen(
          onNew: () => setState(() => _step = _Step.choosing),
          onOpen: _open,
          onImport: _import,
          onSettings: () => setState(() => _step = _Step.settings),
        ),
      _Step.settings => SettingsScreen(
          onBack: () => setState(() => _step = _Step.projects),
        ),
      _Step.choosing => NewDesignScreen(
          idFactory: widget.idFactory,
          onCreated: _open,
          onBack: () => setState(() => _step = _Step.projects),
        ),
      _Step.drawing => CanvasScreen(
          onBack: _leaveEditor,
          onPreview: () {
            // A divider moved on the canvas can merge two panels into a new
            // one; the viewer must not keep holding the old ids open.
            ref.read(viewerControllerProvider.notifier).retainOnly(
                  ref
                      .read(designControllerProvider)
                      .design
                      .panels
                      .map((panel) => panel.id),
                );
            setState(() => _step = _Step.previewing);
          },
          onExport: () => showExportSheet(
            context,
            ref.read(designControllerProvider).design,
          ),
        ),
      _Step.previewing => ViewerScreen(
          onBack: () => setState(() => _step = _Step.drawing),
        ),
    };
  }
}
