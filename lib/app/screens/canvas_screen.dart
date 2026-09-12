import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import '../../core/layout/responsive.dart';
import '../../core/units/length_unit.dart';
import '../../domain/design_document.dart';
import '../../domain/panel.dart';
import '../../domain/panel_divider.dart';
import '../canvas/dimension_labels.dart';
import '../canvas/drawing_canvas.dart';
import '../state/design_controller.dart';
import '../widgets/dimension_input.dart';
import '../widgets/notice.dart';
import '../widgets/panel_sheet.dart';

/// The drawing screen: canvas, dimensions, and the live summary.
///
/// Compact puts the summary behind a button; expanded and tablet-landscape put
/// it beside the canvas, so the user watches the questions disappear as they
/// draw (spec section 8 and Phase 2, items 9 and 10).
class CanvasScreen extends ConsumerWidget {
  final VoidCallback onBack;

  /// Opens the 2.5D preview. Null before a frame exists, because there is
  /// nothing to look at yet.
  final VoidCallback onPreview;

  const CanvasScreen({
    required this.onBack,
    required this.onPreview,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(designControllerProvider);
    final controller = ref.read(designControllerProvider.notifier);

    return ResponsiveBuilder(
      builder: (context, size) {
        // Canvas and summary side by side wherever there is room — which
        // includes a tablet in landscape, not only a desktop window.
        final sideBySide =
            size.widthClass.hasRoomForSidePanel &&
            (size.isLandscape || size.widthClass.isExpanded);

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
              onPressed: onBack,
            ),
            title: Text(state.design.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.undo),
                tooltip: 'Undo',
                onPressed: state.canUndo ? controller.undo : null,
              ),
              IconButton(
                icon: const Icon(Icons.redo),
                tooltip: 'Redo',
                onPressed: state.canRedo ? controller.redo : null,
              ),
              IconButton(
                // A filled icon when a note exists, so the state is visible
                // without opening it.
                icon: Icon(
                  state.design.hasDesignNote
                      ? Icons.sticky_note_2
                      : Icons.sticky_note_2_outlined,
                ),
                tooltip: 'Note for the whole design',
                onPressed: () => _editDesignNote(context, ref),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (state.message != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm,
                      AppSpacing.sm,
                      AppSpacing.sm,
                      0,
                    ),
                    child: Notice(
                      tone: NoticeTone.caution,
                      message: state.message!,
                    ),
                  ),
                Expanded(
                  child: sideBySide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _canvas(context, ref, state)),
                            const VerticalDivider(width: 1),
                            SizedBox(
                              width: AppSizing.propertiesPanelWidth,
                              child: _Summary(design: state.design),
                            ),
                          ],
                        )
                      : _canvas(context, ref, state),
                ),
                _Toolbar(
                  design: state.design,
                  showSummaryButton: !sideBySide,
                  onWidth: () => _editOverallWidth(context, ref),
                  onHeight: () => _editOverallHeight(context, ref),
                  onSummary: () => _showSummary(context, state.design),
                  onPreview: state.design.hasLayout ? onPreview : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _canvas(BuildContext context, WidgetRef ref, DesignState state) =>
      ColoredBox(
        // Cream, from the theme — the paper the user draws on.
        color: AppColors.cream,
        child: DrawingCanvas(
          design: state.design,
          selectedPanelId: state.selectedPanelId,
          selectedDividerId: state.selectedDividerId,
          onStroke: (points) =>
              ref.read(designControllerProvider.notifier).addStroke(points),
          onPanelTap: (panel) => ref
              .read(designControllerProvider.notifier)
              .selectPanel(panel?.id),
          onDimensionTap: (label) => _editDimension(context, ref, label),
          onPanelLongPress: (panel) => _openPanelSheet(context, ref, panel),
          onDividerLongPress: (divider) =>
              _openDividerSheet(context, ref, divider),
          onDividerMoved: (divider, toMm) => ref
              .read(designControllerProvider.notifier)
              .moveDivider(divider.id, toMm),
        ),
      );

  // -- actions --------------------------------------------------------------

  /// Tapping a dimension on the drawing asks for that measurement.
  Future<void> _editDimension(
    BuildContext context,
    WidgetRef ref,
    DimensionLabel label,
  ) async {
    switch (label.target) {
      case DimensionTarget.overallWidth:
        await _editOverallWidth(context, ref);
      case DimensionTarget.overallHeight:
        await _editOverallHeight(context, ref);
      case DimensionTarget.panelWidth:
        await _editPanelWidth(context, ref, label);
    }
  }

  Future<void> _editPanelWidth(
    BuildContext context,
    WidgetRef ref,
    DimensionLabel label,
  ) async {
    final panelId = label.panelId;
    if (panelId == null) return;

    final millimetres = await askForLengthMm(
      context,
      title: 'Panel width',
      helper: 'The panel beside it changes to keep the total the same.',
      currentMm: label.valueMm,
    );
    if (millimetres == null) return;
    ref
        .read(designControllerProvider.notifier)
        .setPanelWidth(panelId, millimetres);
  }

  Future<void> _editOverallWidth(BuildContext context, WidgetRef ref) async {
    final design = ref.read(designControllerProvider).design;
    final millimetres = await askForLengthMm(
      context,
      title: 'Total width',
      helper: design.dimensionReference.description,
      currentMm: design.overallWidth?.millimetres,
    );
    if (millimetres == null) return;
    ref.read(designControllerProvider.notifier).setOverallWidth(millimetres);
  }

  Future<void> _editOverallHeight(BuildContext context, WidgetRef ref) async {
    final design = ref.read(designControllerProvider).design;
    final millimetres = await askForLengthMm(
      context,
      title: 'Total height',
      helper: design.dimensionReference.description,
      currentMm: design.overallHeight?.millimetres,
    );
    if (millimetres == null) return;
    ref.read(designControllerProvider.notifier).setOverallHeight(millimetres);
  }

  Future<void> _editDesignNote(BuildContext context, WidgetRef ref) async {
    final design = ref.read(designControllerProvider).design;
    final note = await askForNote(
      context,
      title: 'Note for this design',
      helper: 'General remarks or anything the customer asked for.',
      current: design.designNote,
    );
    if (note == null) return;
    ref.read(designControllerProvider.notifier).setDesignNote(note);
  }

  Future<void> _openPanelSheet(
    BuildContext context,
    WidgetRef ref,
    Panel panel,
  ) async {
    final controller = ref.read(designControllerProvider.notifier);
    controller.selectPanel(panel.id);

    final edit = await showPanelSheet(
      context,
      panel: panel,
      viewedFrom: ref.read(designControllerProvider).design.viewedFrom,
    );
    if (edit == null) return;

    switch (edit) {
      case MakeFixed():
        controller.makeFixed(panel.id);
      case SetOpening(:final spec):
        controller.setOpening(panel.id, spec);
      case SetMesh(:final value):
        controller.setMesh(panel.id, value);
      case SetEmpty(:final value):
        controller.setEmpty(panel.id, value);
      case EditNote():
        if (!context.mounted) return;
        final note = await askForNote(
          context,
          title: 'Note for this panel',
          helper: 'For example: توري, فارغ, frosted glass.',
          current: panel.note,
        );
        if (note != null) controller.setPanelNote(panel.id, note);
    }
  }

  Future<void> _openDividerSheet(
    BuildContext context,
    WidgetRef ref,
    PanelDivider divider,
  ) async {
    final controller = ref.read(designControllerProvider.notifier);
    controller.selectDivider(divider.id);

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_with),
              title: const Text('Move this divider'),
              subtitle: const Text('Drag it on the drawing'),
              onTap: () => Navigator.of(context).pop('move'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete this divider'),
              subtitle: const Text('The two panels become one'),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );

    switch (action) {
      case 'delete':
        controller.deleteDivider(divider.id);
      case 'move':
        // Stays selected; the canvas now drags it rather than drawing.
        break;
      default:
        controller.selectDivider(null);
    }
  }

  void _showSummary(BuildContext context, DesignDocument design) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        builder: (context) => SafeArea(child: _Summary(design: design)),
      );
}

/// The live "still to confirm" list (spec Phase 2, item 9).
class _Summary extends StatelessWidget {
  final DesignDocument design;

  const _Summary({required this.design});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final questions = design.outstandingQuestions;

    return ColoredBox(
      color: AppColors.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This design', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            _Fact('Panels', '${design.panels.length}'),
            _Fact('Fixed (CH)', '${design.fixedPanelCount}'),
            _Fact('Opening (Z)', '${design.openingPanelCount}'),
            _Fact('Dividers', '${design.dividers.length}'),
            const SizedBox(height: AppSpacing.md),
            Text(
              questions.isEmpty
                  ? 'Nothing left to confirm'
                  : 'Still to confirm',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            if (questions.isEmpty)
              const Notice(
                message:
                    'Every dimension and opening has been confirmed. The '
                    'profiles are still generic previews, so this is a design, '
                    'not production data.',
              )
            else
              for (final question in questions)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(child: Text(question)),
                    ],
                  ),
                ),
            if (design.allNotes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text('Notes', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              for (final note in design.allNotes)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Notice(title: note.source, message: note.text),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final String label;
  final String value;

  const _Fact(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.mutedText),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

/// The actions the spec wants always reachable: measurements, and the summary
/// on layouts where it is not already on screen (spec section 7).
class _Toolbar extends StatelessWidget {
  final DesignDocument design;
  final bool showSummaryButton;
  final VoidCallback onWidth;
  final VoidCallback onHeight;
  final VoidCallback onSummary;

  /// Null until there is something to preview.
  final VoidCallback? onPreview;

  const _Toolbar({
    required this.design,
    required this.showSummaryButton,
    required this.onWidth,
    required this.onHeight,
    required this.onSummary,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final unit = LengthUnit.centimetre;
    final width = design.overallWidth;
    final height = design.overallHeight;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onWidth,
                  child: Text(
                    width == null
                        ? 'Width'
                        : 'Width ${unit.format(width.millimetres)}'
                              '${width.isConfirmed ? '' : ' ?'}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: OutlinedButton(
                  onPressed: onHeight,
                  child: Text(
                    height == null
                        ? 'Height'
                        : 'Height ${unit.format(height.millimetres)}'
                              '${height.isConfirmed ? '' : ' ?'}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (showSummaryButton) ...[
                const SizedBox(width: AppSpacing.xs),
                IconButton.filled(
                  icon: const Icon(Icons.checklist),
                  tooltip: 'What is still to confirm',
                  onPressed: onSummary,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.view_in_ar_outlined),
              label: Text(
                onPreview == null ? 'Draw a frame to preview' : '3D Preview',
              ),
              onPressed: onPreview,
            ),
          ),
        ],
      ),
    );
  }
}
