import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../core/design/tokens.dart';
import '../../core/i18n/product_labels.dart';
import '../../core/i18n/strings.dart';
import '../../core/layout/responsive.dart';
import '../../core/units/length_unit.dart';
import '../../domain/design_document.dart';
import '../../domain/layout/design_validator.dart';
import '../../domain/panel.dart';
import '../../domain/panel_divider.dart';
import '../canvas/canvas_projection.dart';
import '../canvas/dimension_labels.dart';
import '../canvas/drawing_canvas.dart';
import '../state/design_controller.dart';
import '../state/project_controller.dart';
import '../widgets/dimension_input.dart';
import '../widgets/notice.dart';
import '../widgets/panel_sheet.dart';

/// The drawing screen: canvas, dimensions, and the live summary.
///
/// Compact puts the summary behind a button; expanded and tablet-landscape put
/// it beside the canvas, so the user watches the questions disappear as they
/// draw (spec section 8 and Phase 2, items 9 and 10).
/// Lets the screen read the canvas's laid-out size for "fit to view".
final _canvasKey = GlobalKey();

class CanvasScreen extends ConsumerWidget {
  final VoidCallback onBack;

  /// Opens the 2.5D preview. Null before a frame exists, because there is
  /// nothing to look at yet.
  final VoidCallback onPreview;

  /// Opens the export sheet.
  final VoidCallback onExport;

  const CanvasScreen({
    required this.onBack,
    required this.onPreview,
    required this.onExport,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(designControllerProvider);
    final controller = ref.read(designControllerProvider.notifier);
    final save = ref.watch(saveControllerProvider);

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
              tooltip: context.s(T.back),
              onPressed: onBack,
            ),
            title: InkWell(
              // Tapping the name renames the project — the shortest path to
              // the thing a user most often wants to change.
              onTap: () => _rename(context, ref),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      state.design.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (save.isDirty)
                    const Padding(
                      padding: EdgeInsets.only(left: AppSpacing.xxs),
                      child: Text('•', style: TextStyle(fontSize: 22)),
                    ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.undo),
                tooltip: context.s(T.undo),
                onPressed: state.canUndo ? controller.undo : null,
              ),
              IconButton(
                icon: const Icon(Icons.redo),
                tooltip: context.s(T.redo),
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
                tooltip: context.s(T.designNoteTooltip),
                onPressed: () => _editDesignNote(context, ref),
              ),
              IconButton(
                icon: save.isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                tooltip: context.s(T.saveThisProject),
                onPressed: save.isSaving ? null : () => _save(context, ref),
              ),
              IconButton(
                icon: const Icon(Icons.ios_share),
                tooltip: context.s(T.export),
                onPressed: onExport,
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (save.error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm,
                      AppSpacing.sm,
                      AppSpacing.sm,
                      0,
                    ),
                    child: Notice(
                      tone: NoticeTone.problem,
                      title: context.s(T.notSaved),
                      message: save.error!,
                    ),
                  ),
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
                _ToolPalette(
                  tool: state.tool,
                  notesVisible: state.notesVisible,
                  hasSelection: state.selectedPanelId != null ||
                      state.selectedDividerId != null,
                  onTool: (tool) =>
                      ref.read(designControllerProvider.notifier).selectTool(tool),
                  onFit: () => _fitToView(ref),
                  onResetView: () =>
                      ref.read(designControllerProvider.notifier).resetView(),
                  onDelete: () => ref
                      .read(designControllerProvider.notifier)
                      .deleteSelection(),
                  onToggleNotes: (visible) => ref
                      .read(designControllerProvider.notifier)
                      .setNotesVisible(visible),
                ),
                const Divider(height: 1),
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
          key: _canvasKey,
          design: state.design,
          tool: state.tool,
          zoom: state.zoom,
          pan: state.pan,
          notesVisible: state.notesVisible,
          selectedPanelId: state.selectedPanelId,
          selectedDividerId: state.selectedDividerId,
          onViewChanged: (zoom, pan) =>
              ref.read(designControllerProvider.notifier).setView(zoom, pan),
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
          onNoteMoved: (panelId, noteId, at) => ref
              .read(designControllerProvider.notifier)
              .movePanelNote(panelId, noteId, at),
          onGestureEnd: () =>
              ref.read(designControllerProvider.notifier).endGesture(),
        ),
      );

  // -- actions --------------------------------------------------------------

  /// Zooms and pans so the whole drawing fills the canvas.
  void _fitToView(WidgetRef ref) {
    final controller = ref.read(designControllerProvider.notifier);
    final outline = ref.read(designControllerProvider).design.outline;
    // The canvas's own laid-out size, read from its render box: the same box
    // the projection was built against, so the fit lands exactly.
    final size = _canvasKey.currentContext?.size;
    if (outline == null || size == null || size.isEmpty) {
      controller.resetView();
      return;
    }
    final (zoom, pan) = CanvasProjection.fitTo(
      size,
      outline.left,
      outline.top,
      outline.right,
      outline.bottom,
    );
    controller.setView(zoom, pan);
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(designControllerProvider.notifier)..touch();
    final saved = await ref
        .read(saveControllerProvider.notifier)
        .save(ref.read(designControllerProvider).design);
    if (!context.mounted) return;
    if (saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.s(T.projectSaved, {
              'name': ref.read(designControllerProvider).design.name,
            }),
          ),
        ),
      );
    }
    // A failure is already on screen as a banner; no need to say it twice.
    controller.clearMessage();
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final design = ref.read(designControllerProvider).design;
    final name = await askForNote(
      context,
      title: context.s(T.renameProject),
      helper: context.s(T.whatShouldItBeCalled),
      current: design.name,
    );
    if (name == null || name.trim().isEmpty) return;
    ref.read(designControllerProvider.notifier).rename(name);
  }

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
      title: context.s(T.panelWidth),
      helper: context.s(T.panelWidthHelp),
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
      title: context.s(T.totalWidth),
      helper: context.s.dimensionReferenceHelp(design.dimensionReference),
      currentMm: design.overallWidth?.millimetres,
    );
    if (millimetres == null) return;
    ref.read(designControllerProvider.notifier).setOverallWidth(millimetres);
  }

  Future<void> _editOverallHeight(BuildContext context, WidgetRef ref) async {
    final design = ref.read(designControllerProvider).design;
    final millimetres = await askForLengthMm(
      context,
      title: context.s(T.totalHeight),
      helper: context.s.dimensionReferenceHelp(design.dimensionReference),
      currentMm: design.overallHeight?.millimetres,
    );
    if (millimetres == null) return;
    ref.read(designControllerProvider.notifier).setOverallHeight(millimetres);
  }

  Future<void> _editDesignNote(BuildContext context, WidgetRef ref) async {
    final design = ref.read(designControllerProvider).design;
    final note = await askForNote(
      context,
      title: context.s(T.noteForThisDesign),
      helper: context.s(T.noteForThisDesignHelp),
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
      case EditNote(:final noteId):
        if (!context.mounted) return;
        final existing = noteId == null ? null : panel.noteById(noteId);
        final text = await askForNote(
          context,
          title: context.s(existing == null ? T.addNote : T.editNote),
          helper: context.s(T.noteExample),
          current: existing?.text ?? '',
        );
        if (text == null) return;
        if (existing == null) {
          controller.addPanelNote(panel.id, text);
        } else {
          controller.editPanelNote(panel.id, existing.id, text);
        }
      case DeleteNote(:final noteId):
        controller.removePanelNote(panel.id, noteId);
      case ToggleNoteVisible(:final noteId, :final visible):
        controller.setNoteVisible(panel.id, noteId, visible);
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
              title: Text(context.s(T.moveThisDivider)),
              subtitle: Text(context.s(T.dragItOnTheDrawing)),
              onTap: () => Navigator.of(context).pop('move'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(context.s(T.deleteThisDivider)),
              subtitle: Text(context.s(T.twoPanelsBecomeOne)),
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
    final s = context.s;
    final questions = design.outstandingQuestions;
    // Reported, never corrected: the app does not silently change a confirmed
    // dimension to make a layout fit (spec section 6).
    final conflicts =
        DesignValidator.check(design).where((f) => f.isConflict).toList();

    return ColoredBox(
      color: AppColors.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s(T.thisDesign), style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            _Fact(s(T.panels), s.number(design.panels.length)),
            _Fact(s(T.fixedCount), s.number(design.fixedPanelCount)),
            _Fact(s(T.openingCount), s.number(design.openingPanelCount)),
            _Fact(s(T.dividers), s.number(design.dividers.length)),
            const SizedBox(height: AppSpacing.md),
            // Contradictions first: an unfinished design is normal, a
            // contradictory one has to be resolved (spec section 6).
            if (conflicts.isNotEmpty) ...[
              Text(s(T.problems), style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              for (final finding in conflicts)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Notice(
                    tone: NoticeTone.problem,
                    title: s.findingMessage(finding),
                    message: s.findingRemedy(finding),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
            ],
            Text(
              s(questions.isEmpty ? T.nothingLeftToConfirm : T.stillToConfirm),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            if (questions.isEmpty)
              Notice(message: s(T.everythingConfirmed))
            else
              for (final question in questions)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(child: Text(s.question(question))),
                    ],
                  ),
                ),
            if (design.allNotes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(s(T.notes), style: theme.textTheme.titleMedium),
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
    const unit = LengthUnit.centimetre;
    final s = context.s;
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
                        ? s(T.width)
                        : '${s(T.width)} '
                            '${s.length(width.millimetres, unit)}'
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
                        ? s(T.height)
                        : '${s(T.height)} '
                            '${s.length(height.millimetres, unit)}'
                            '${height.isConfirmed ? '' : ' ?'}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (showSummaryButton) ...[
                const SizedBox(width: AppSpacing.xs),
                IconButton.filled(
                  icon: const Icon(Icons.checklist),
                  tooltip: s(T.whatIsStillToConfirm),
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
                s(onPreview == null ? T.drawFrameToPreview : T.preview3d),
              ),
              onPressed: onPreview,
            ),
          ),
        ],
      ),
    );
  }
}

/// The drawing tools (spec section 4).
///
/// Scrollable, so the row cannot push the canvas off a narrow phone, and every
/// button carries a label as well as an icon.
class _ToolPalette extends StatelessWidget {
  final CanvasTool tool;
  final bool notesVisible;
  final bool hasSelection;
  final ValueChanged<CanvasTool> onTool;
  final VoidCallback onFit;
  final VoidCallback onResetView;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleNotes;

  const _ToolPalette({
    required this.tool,
    required this.notesVisible,
    required this.hasSelection,
    required this.onTool,
    required this.onFit,
    required this.onResetView,
    required this.onDelete,
    required this.onToggleNotes,
  });

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: AppColors.surface,
        child: SizedBox(
          height: AppSizing.minTouchTarget + AppSpacing.xs * 2,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            children: [
              for (final option in CanvasTool.values)
                _ToolButton(
                  icon: switch (option) {
                    CanvasTool.draw => Icons.edit_outlined,
                    CanvasTool.pan => Icons.open_with,
                    CanvasTool.select => Icons.touch_app_outlined,
                  },
                  label: context.s(switch (option) {
                    CanvasTool.draw => T.toolDraw,
                    CanvasTool.pan => T.toolMove,
                    CanvasTool.select => T.toolSelect,
                  }),
                  tooltip: context.s(switch (option) {
                    CanvasTool.draw => T.toolDrawHelp,
                    CanvasTool.pan => T.toolMoveHelp,
                    CanvasTool.select => T.toolSelectHelp,
                  }),
                  selected: tool == option,
                  onPressed: () => onTool(option),
                ),
              const VerticalDivider(width: AppSpacing.sm),
              _ToolButton(
                icon: Icons.fit_screen_outlined,
                label: context.s(T.fit),
                tooltip: context.s(T.fitHelp),
                onPressed: onFit,
              ),
              _ToolButton(
                icon: Icons.zoom_out_map,
                label: context.s(T.wholeSheet),
                tooltip: context.s(T.wholeSheetHelp),
                onPressed: onResetView,
              ),
              _ToolButton(
                icon: notesVisible
                    ? Icons.speaker_notes_outlined
                    : Icons.speaker_notes_off_outlined,
                label: context.s(notesVisible ? T.notesOn : T.notesOff),
                tooltip: context
                    .s(notesVisible ? T.hideNoteLabels : T.showNoteLabels),
                onPressed: () => onToggleNotes(!notesVisible),
              ),
              _ToolButton(
                icon: Icons.delete_outline,
                label: context.s(T.delete),
                tooltip: context
                    .s(hasSelection ? T.deleteSelected : T.selectSomethingFirst),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      );
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final bool selected;
  final VoidCallback onPressed;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.cream : AppColors.deepGreen;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxs,
        vertical: AppSpacing.xs,
      ),
      child: Semantics(
        button: true,
        selected: selected,
        label: selected ? '$label, ${context.s(T.selected)}' : label,
        child: ExcludeSemantics(
          child: Tooltip(
            message: tooltip,
            child: Material(
              color: selected ? AppColors.deepGreen : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: AppSizing.minTouchTarget,
                    minHeight: AppSizing.minTouchTarget,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 20, color: foreground),
                      const SizedBox(width: AppSpacing.xxs),
                      // The word as well as the icon, so nothing depends on
                      // recognising a glyph (spec section 12).
                      Text(label, style: TextStyle(color: foreground)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
