import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/design_document.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/responsive.dart';
import '../../export/export_service.dart';
import '../../geometry/region_editor.dart';
import '../../pricing/pricing_engine.dart';
import '../../pricing/widgets/price_breakdown_view.dart';
import '../../../core/services/providers.dart';
import '../../rendering/widgets/model_3d_panel.dart';
import '../../rendering/widgets/technical_drawing_view.dart';
import '../state/design_session.dart';
import '../widgets/region_properties_panel.dart';
import '../widgets/version_history_sheet.dart';

enum _ViewMode { drawing, model }

/// Where the generated product lives: the technical drawing, the real 3D
/// model, the structure you can edit, and what it costs.
class DesignScreen extends ConsumerStatefulWidget {
  final VoidCallback onEditDrawing;
  final VoidCallback onExit;

  const DesignScreen({super.key, required this.onEditDrawing, required this.onExit});

  @override
  ConsumerState<DesignScreen> createState() => _DesignScreenState();
}

class _DesignScreenState extends ConsumerState<DesignScreen> {
  _ViewMode _mode = _ViewMode.model;
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String failureMessage) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$failureMessage $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export(String kind, DesignDocument design) async {
    const service = ExportService();
    final rules = ref.read(pricingRulesProvider).value;
    final price = rules == null ? null : PricingEngine(rules: rules).price(design.model);
    await _run(
      () async => switch (kind) {
        'png' => service.exportPng(design),
        'pdf' => service.exportPdf(design, price: price),
        _ => service.exportProjectFile(design),
      },
      'Export failed:',
    );
  }

  Future<void> _save() async {
    await _run(
      () => ref.read(designSessionProvider.notifier).save(),
      'Could not save:',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Design saved')));
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(designSessionProvider);
    final notifier = ref.read(designSessionProvider.notifier);
    final design = session.document;
    final model = session.model;

    if (design == null || model == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Design')),
        body: EmptyState(
          icon: Icons.draw_outlined,
          title: 'No design open',
          message: 'Start by drawing a door or a window.',
          action: FilledButton(onPressed: widget.onExit, child: const Text('Back')),
        ),
      );
    }

    final viewer = _Viewer(
      mode: _mode,
      onModeChanged: (mode) => setState(() => _mode = mode),
      session: session,
    );

    final structure = RegionPropertiesPanel(model: model);
    final price = PriceBreakdownView(model: model);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: widget.onExit,
        ),
        title: Text(design.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Undo change',
            icon: const Icon(Icons.undo),
            onPressed: notifier.canUndoModel ? notifier.undoModel : null,
          ),
          IconButton(
            tooltip: 'Redo change',
            icon: const Icon(Icons.redo),
            onPressed: notifier.canRedoModel ? notifier.redoModel : null,
          ),
          IconButton(
            tooltip: 'Back to the drawing',
            icon: const Icon(Icons.edit_outlined),
            onPressed: widget.onEditDrawing,
          ),
          IconButton(
            tooltip: 'Save',
            icon: _busy
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            onPressed: _busy ? null : _save,
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (value) {
              switch (value) {
                case 'history':
                  VersionHistorySheet.show(context);
                case 'rename':
                  _rename(design);
                default:
                  _export(value, design);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'png', child: Text('Export image (PNG)')),
              PopupMenuItem(value: 'pdf', child: Text('Export drawing (PDF)')),
              PopupMenuItem(value: 'project', child: Text('Export project file')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'history', child: Text('Version history')),
              PopupMenuItem(value: 'rename', child: Text('Rename')),
            ],
          ),
        ],
      ),
      body: ResponsiveLayout(
        compact: (context) => DefaultTabController(
          length: 3,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'View'),
                  Tab(text: 'Edit'),
                  Tab(text: 'Price'),
                ],
              ),
              Expanded(
                child: TabBarView(children: [viewer, structure, price]),
              ),
            ],
          ),
        ),
        medium: (context) => Row(
          children: [
            SizedBox(width: 320, child: _Panel(child: structure)),
            Expanded(child: viewer),
          ],
        ),
        expanded: (context) => Row(
          children: [
            SizedBox(width: 340, child: _Panel(child: structure)),
            Expanded(child: viewer),
            SizedBox(width: 320, child: _Panel(left: true, child: price)),
          ],
        ),
      ),
      floatingActionButton: screenSizeOf(context) == ScreenSize.medium
          ? FloatingActionButton.extended(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (_) => SizedBox(height: 520, child: price),
              ),
              icon: const Icon(Icons.receipt_long),
              label: const Text('Price'),
            )
          : null,
    );
  }

  Future<void> _rename(DesignDocument design) async {
    final controller = TextEditingController(text: design.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename design'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty) {
      ref.read(designSessionProvider.notifier).rename(name);
    }
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  final bool left;

  const _Panel({required this.child, this.left = false});

  // A Material, not a coloured box: the panels contain list tiles, which paint
  // their background and ink on the nearest Material ancestor.
  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surface,
        shape: left
            ? Border(left: BorderSide(color: Theme.of(context).dividerColor))
            : Border(right: BorderSide(color: Theme.of(context).dividerColor)),
        child: child,
      );
}

class _Viewer extends ConsumerWidget {
  final _ViewMode mode;
  final ValueChanged<_ViewMode> onModeChanged;
  final DesignSession session;

  const _Viewer({
    required this.mode,
    required this.onModeChanged,
    required this.session,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(designSessionProvider.notifier);
    final model = session.model!;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: SegmentedButton<_ViewMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: _ViewMode.drawing,
                label: Text('Drawing'),
                icon: Icon(Icons.architecture, size: 18),
              ),
              ButtonSegment(
                value: _ViewMode.model,
                label: Text('3D model'),
                icon: Icon(Icons.view_in_ar, size: 18),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (selection) => onModeChanged(selection.first),
          ),
        ),
        Expanded(
          child: mode == _ViewMode.drawing
              ? TechnicalDrawingView(
                  model: model,
                  selectedRegionId: session.selectedRegionId,
                  onSelect: notifier.selectRegion,
                  // A drag is one undo step: history is recorded once at the
                  // start, then the moves fold into it.
                  onDragStart: (target) {
                    notifier
                      ..selectRegion(target.regionId)
                      ..beginInteraction()
                      ..updateModel(model);
                  },
                  onDragUpdate: (target, positionMm) {
                    final current = ref.read(designSessionProvider).model;
                    if (current == null) return;
                    notifier.updateModel(
                      RegionEditor.dragEdge(
                        current,
                        target.regionId,
                        target.edge,
                        positionMm,
                      ),
                      recordHistory: false,
                    );
                  },
                  onDragEnd: notifier.endInteraction,
                )
              : Model3DPanel(
                  model: model,
                  style: session.renderStyle,
                  showDimensions: session.showDimensions,
                  autoRotate: session.autoRotate,
                  highlightCellPath: session.selectedRegionId,
                  onStyleChanged: notifier.setRenderStyle,
                  onToggleDimensions: notifier.toggleDimensions,
                  onToggleAutoRotate: notifier.toggleAutoRotate,
                ),
        ),
        if (session.isDirty)
          Container(
            width: double.infinity,
            color: AppColors.warningSurface,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Text(
              'Unsaved changes — autosaved as a draft.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
