import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/sketch.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/responsive.dart';
import '../../configurator/state/design_session.dart';
import '../../dimensions/widgets/measurement_dialog.dart';
import '../state/drawing_controller.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/tool_palette.dart';

/// Asks for the design to be generated. [useDrawingExtent] is only ever true
/// because the user chose it after being told no outline was found.
typedef GenerateCallback = void Function({bool useDrawingExtent});

/// The hero screen: a sheet of paper you draw the door or window on (§61).
class DrawingScreen extends ConsumerStatefulWidget {
  final GenerateCallback onInterpret;
  final VoidCallback? onBack;

  const DrawingScreen({super.key, required this.onInterpret, this.onBack});

  @override
  ConsumerState<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends ConsumerState<DrawingScreen> {
  late final DrawingController _controller;
  final TransformationController _transformation = TransformationController();

  @override
  void initState() {
    super.initState();
    final sketch = ref.read(designSessionProvider).document?.sketch ?? const Sketch();
    _controller = DrawingController(sketch: sketch)..addListener(_syncSketch);
    // Start with the sheet centred on a comfortable working area.
    _transformation.value = Matrix4.identity()..translateByDouble(-1500.0, -1000.0, 0.0, 1.0);
  }

  void _syncSketch() {
    if (_controller.isDrawing) return;
    ref.read(designSessionProvider.notifier).updateSketch(_controller.sketch);
  }

  @override
  void dispose() {
    _controller.removeListener(_syncSketch);
    _controller.dispose();
    _transformation.dispose();
    super.dispose();
  }

  Future<double?> _askForMeasurement(Stroke stroke) {
    final existing = stroke.dimensionMm;
    return MeasurementDialog.show(
      context,
      title: existing == null ? 'How long is this?' : 'Change this measurement',
      message: existing == null
          ? 'Type the real size of the line you just drew. The first '
              'measurement also sets the scale of the whole drawing.'
          : 'Type the corrected size. Everything derived from the drawing '
              'scale updates with it.',
      initialMm: existing,
    );
  }

  Future<String?> _askForNote() => NoteDialog.show(context);

  void _zoom(double factor) {
    final matrix = _transformation.value.clone();
    matrix.scaleByDouble(factor, factor, factor, 1.0);
    _transformation.value = matrix;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(designSessionProvider);
    final document = session.document;

    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
                tooltip: 'Back',
              ),
        title: Text(document?.name ?? 'New design', overflow: TextOverflow.ellipsis),
        actions: [
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.undo),
                  tooltip: 'Undo',
                  onPressed: _controller.canUndo ? _controller.undo : null,
                ),
                IconButton(
                  icon: const Icon(Icons.redo),
                  tooltip: 'Redo',
                  onPressed: _controller.canRedo ? _controller.redo : null,
                ),
                _OverflowMenu(controller: _controller),
              ],
            ),
          ),
        ],
      ),
      body: ResponsiveLayout(
        compact: (context) => Column(
          children: [
            Expanded(child: _canvas()),
            _ProblemBanner(onRetryWithExtent: widget.onInterpret),
            _SelectionBar(controller: _controller, onEditDimension: _editDimension),
            _CompactToolbar(controller: _controller),
            _ActionBar(controller: _controller, onInterpret: widget.onInterpret),
          ],
        ),
        medium: (context) => Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  _ToolRail(controller: _controller),
                  Expanded(child: _canvas()),
                ],
              ),
            ),
            _ProblemBanner(onRetryWithExtent: widget.onInterpret),
            _SelectionBar(controller: _controller, onEditDimension: _editDimension),
            _ActionBar(controller: _controller, onInterpret: widget.onInterpret),
          ],
        ),
        expanded: (context) => Row(
          children: [
            _ToolRail(controller: _controller),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _canvas()),
                  _ProblemBanner(onRetryWithExtent: widget.onInterpret),
                ],
              ),
            ),
            SizedBox(
              width: 300,
              child: _PropertiesPanel(
                controller: _controller,
                onInterpret: widget.onInterpret,
                onEditDimension: _editDimension,
                onZoomIn: () => _zoom(1.2),
                onZoomOut: () => _zoom(1 / 1.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editDimension(Stroke stroke) async {
    final value = await _askForMeasurement(stroke);
    if (value != null && value > 0) _controller.setDimensionValue(stroke.id, value);
  }

  Widget _canvas() => DrawingCanvas(
        controller: _controller,
        transformationController: _transformation,
        onDimensionDrawn: _askForMeasurement,
        onNoteRequested: _askForNote,
      );
}

class _ToolRail extends StatelessWidget {
  final DrawingController controller;

  const _ToolRail({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ToolPalette(
          selected: controller.tool,
          onSelected: (tool) => controller.tool = tool,
        ),
      ),
    );
  }
}

class _CompactToolbar extends StatelessWidget {
  final DrawingController controller;

  const _CompactToolbar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ToolPalette(
          direction: Axis.horizontal,
          selected: controller.tool,
          onSelected: (tool) => controller.tool = tool,
        ),
      ),
    );
  }
}

class _ActionBar extends ConsumerWidget {
  final DrawingController controller;
  final GenerateCallback onInterpret;

  const _ActionBar({required this.controller, required this.onInterpret});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(designSessionProvider);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => Row(
            children: [
              Expanded(
                child: Text(
                  controller.isEmpty
                      ? 'Draw the outline first, then the divisions.'
                      : '${controller.strokes.length} strokes drawn',
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              FilledButton.icon(
                onPressed: controller.isEmpty || session.isInterpreting
                    ? null
                    : () => onInterpret(),
                icon: session.isInterpreting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Generate'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverflowMenu extends StatelessWidget {
  final DrawingController controller;

  const _OverflowMenu({required this.controller});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Canvas options',
      onSelected: (value) {
        switch (value) {
          case 'grid':
            controller.gridVisible = !controller.gridVisible;
          case 'snap':
            controller.snapEnabled = !controller.snapEnabled;
          case 'precision':
            controller.precisionMode = !controller.precisionMode;
          case 'clear':
            controller.clear();
        }
      },
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
          value: 'grid',
          checked: controller.gridVisible,
          child: const Text('Show grid'),
        ),
        CheckedPopupMenuItem(
          value: 'snap',
          checked: controller.snapEnabled,
          child: const Text('Snapping'),
        ),
        CheckedPopupMenuItem(
          value: 'precision',
          checked: controller.precisionMode,
          child: const Text('Precision mode (no straightening)'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'clear', child: Text('Clear the sheet')),
      ],
    );
  }
}

class _PropertiesPanel extends StatelessWidget {
  final DrawingController controller;
  final GenerateCallback onInterpret;
  final Future<void> Function(Stroke stroke) onEditDimension;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const _PropertiesPanel({
    required this.controller,
    required this.onInterpret,
    required this.onEditDimension,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: Border(left: BorderSide(color: Theme.of(context).dividerColor)),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final selected = controller.selectedStroke;
          return Column(
            children: [
              Expanded(
                child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              const SectionHeader(
                title: 'Drawing',
                subtitle: 'One finger draws. Two fingers pan and zoom.',
              ),
              Text('Pen weight', style: Theme.of(context).textTheme.labelLarge),
              Slider(
                value: controller.penWidth,
                min: 1,
                max: 8,
                divisions: 14,
                label: controller.penWidth.toStringAsFixed(1),
                onChanged: (value) => controller.penWidth = value,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: controller.gridVisible,
                onChanged: (value) => controller.gridVisible = value,
                title: const Text('Grid'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: controller.snapEnabled,
                onChanged: (value) => controller.snapEnabled = value,
                title: const Text('Snapping'),
                subtitle: const Text('Edges, centres, equal spacing'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: controller.precisionMode,
                onChanged: (value) => controller.precisionMode = value,
                title: const Text('Precision mode'),
                subtitle: const Text('Keep every line exactly as drawn'),
              ),
              const Divider(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onZoomOut,
                      icon: const Icon(Icons.zoom_out, size: 18),
                      label: const Text('Out'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onZoomIn,
                      icon: const Icon(Icons.zoom_in, size: 18),
                      label: const Text('In'),
                    ),
                  ),
                ],
              ),
              if (selected != null) ...[
                const Divider(height: AppSpacing.lg),
                const SectionHeader(title: 'Selection'),
                Text(selected.tool.label, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    if (selected.tool == SketchTool.dimension)
                      OutlinedButton.icon(
                        onPressed: () => onEditDimension(selected),
                        icon: const Icon(Icons.straighten, size: 16),
                        label: Text(
                          selected.dimensionMm == null
                              ? 'Set size'
                              : '${selected.dimensionMm!.round()} mm',
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: controller.deleteSelected,
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Delete'),
                    ),
                    OutlinedButton.icon(
                      onPressed: controller.duplicateSelected,
                      icon: const Icon(Icons.copy_all_outlined, size: 16),
                      label: const Text('Duplicate'),
                    ),
                    OutlinedButton.icon(
                      onPressed: controller.rotateSelected,
                      icon: const Icon(Icons.rotate_90_degrees_cw, size: 16),
                      label: const Text('Rotate'),
                    ),
                  ],
                ),
              ],
              const Divider(height: AppSpacing.lg),
              _WhatWeSee(controller: controller),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
              // Pinned: the primary action must never be somewhere the user
              // has to scroll a side panel to find.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: controller.isEmpty ? null : () => onInterpret(),
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Generate the design'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A live, honest read-back of what the recogniser can see so far.
class _WhatWeSee extends StatelessWidget {
  final DrawingController controller;

  const _WhatWeSee({required this.controller});

  @override
  Widget build(BuildContext context) {
    final primitives = controller.primitives;
    final counts = <String, int>{};
    for (final p in primitives) {
      final key = p.runtimeType.toString().replaceAll('Primitive', '');
      counts.update(key, (v) => v + 1, ifAbsent: () => 1);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'What the app can see',
          subtitle: 'Updated as you draw',
        ),
        if (counts.isEmpty)
          Text(
            'Nothing yet.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          )
        else
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: counts.entries
                .map((e) => StatusChip(
                      label: '${e.value} ${e.key.toLowerCase()}',
                      color: AppColors.brandDarkGreen,
                      icon: Icons.check_circle_outline,
                    ))
                .toList(),
          ),
      ],
    );
  }
}


/// Selection actions for phones and tablets, which have no properties panel.
/// Without this the select tool would be able to pick a stroke and then do
/// nothing with it.
class _SelectionBar extends StatelessWidget {
  final DrawingController controller;
  final Future<void> Function(Stroke stroke) onEditDimension;

  const _SelectionBar({required this.controller, required this.onEditDimension});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final stroke = controller.selectedStroke;
        if (stroke == null) return const SizedBox.shrink();

        return Container(
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.brandCreamSoft,
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: Text(
                    stroke.tool.label,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                if (stroke.tool == SketchTool.dimension)
                  _SelectionAction(
                    icon: Icons.straighten,
                    label: stroke.dimensionMm == null
                        ? 'Set size'
                        : '${stroke.dimensionMm!.round()} mm',
                    onPressed: () => onEditDimension(stroke),
                  ),
                _SelectionAction(
                  icon: Icons.copy_all_outlined,
                  label: 'Duplicate',
                  onPressed: controller.duplicateSelected,
                ),
                _SelectionAction(
                  icon: Icons.rotate_90_degrees_cw,
                  label: 'Rotate',
                  onPressed: controller.rotateSelected,
                ),
                _SelectionAction(
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  onPressed: controller.deleteSelected,
                ),
                _SelectionAction(
                  icon: Icons.close,
                  label: 'Done',
                  onPressed: controller.clearSelection,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SelectionAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _SelectionAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: TextButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 16),
          label: Text(label),
        ),
      );
}


/// Says why the design could not be generated, and offers a way forward.
///
/// Without this the Generate button looks broken: the pipeline knows exactly
/// what is missing, but the user is left staring at a screen that did nothing.
class _ProblemBanner extends ConsumerWidget {
  final GenerateCallback onRetryWithExtent;

  const _ProblemBanner({required this.onRetryWithExtent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(designSessionProvider);
    final message = session.error;
    if (message == null) return const SizedBox.shrink();

    final notifier = ref.read(designSessionProvider.notifier);

    return Material(
      color: AppColors.warningSurface,
      shape: Border(top: BorderSide(color: AppColors.warning.withValues(alpha: 0.45))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.xs,
          AppSpacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.info_outline, size: 18, color: AppColors.warning),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "That drawing could not be turned into a design",
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(message, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: 4,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          notifier.clearError();
                          onRetryWithExtent(useDrawingExtent: true);
                        },
                        icon: const Icon(Icons.crop_free, size: 15),
                        label: const Text('Use what I drew as the outline'),
                      ),
                      TextButton(
                        onPressed: notifier.clearError,
                        child: const Text('Keep drawing'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
