import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../domain/design_document.dart';
import '../../domain/geometry/point2.dart';
import '../../domain/panel.dart';
import '../../domain/panel_divider.dart';
import '../state/design_controller.dart';
import 'canvas_projection.dart';
import 'design_painter.dart';
import 'dimension_labels.dart';
import 'note_labels.dart';

/// The drawing surface.
///
/// One finger draws. A long press asks about whatever is under it — a divider
/// first, then a panel — which is what keeps drawing and editing from fighting
/// each other (spec section 4: drawing gestures stay separate from the rest).
class DrawingCanvas extends StatefulWidget {
  final DesignDocument design;
  final String? selectedPanelId;
  final String? selectedDividerId;

  /// What the finger does. Drawing and navigating are separate modes so
  /// neither can happen by accident (spec section 4).
  final CanvasTool tool;

  final double zoom;
  final Offset pan;

  /// Whether note labels are drawn.
  final bool notesVisible;

  /// The view was moved by a drag or a pinch.
  final void Function(double zoom, Offset pan) onViewChanged;

  /// A finished stroke, in model millimetres.
  final ValueChanged<List<Point2>> onStroke;

  final void Function(Panel panel) onPanelLongPress;
  final void Function(PanelDivider divider) onDividerLongPress;

  /// A divider dragged to a new position, in millimetres along its axis.
  final void Function(PanelDivider divider, double toMm) onDividerMoved;

  final ValueChanged<Panel?> onPanelTap;

  /// A dimension label tapped: the user wants to type that measurement
  /// (spec Phase 2, item 4).
  final ValueChanged<DimensionLabel> onDimensionTap;

  /// A note label dragged to a new place inside its own panel. The position is
  /// fractional, so the label stays where the user put it when the panel is
  /// later resized.
  final void Function(String panelId, String noteId, Point2 at) onNoteMoved;

  /// The finger came off the glass. A drag is one change to undo, not one per
  /// frame, so the controller is told where the gesture ended.
  final VoidCallback onGestureEnd;

  const DrawingCanvas({
    required this.design,
    required this.tool,
    required this.onViewChanged,
    required this.onStroke,
    required this.onPanelLongPress,
    required this.onDividerLongPress,
    required this.onDividerMoved,
    required this.onPanelTap,
    required this.onDimensionTap,
    required this.onNoteMoved,
    required this.onGestureEnd,
    this.selectedPanelId,
    this.selectedDividerId,
    this.zoom = 1,
    this.pan = Offset.zero,
    this.notesVisible = true,
    super.key,
  });

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  final List<Point2> _wetInk = [];

  /// The divider currently being dragged. While this is set the gesture moves
  /// a divider instead of laying down ink.
  PanelDivider? _draggingDivider;

  /// The note label currently being dragged, and the gap between the finger
  /// and the label's centre when it was grabbed — so the label does not jump
  /// under the finger on the first move.
  NoteLabel? _draggingNote;
  Offset _noteGrabOffset = Offset.zero;

  CanvasProjection _projection = const CanvasProjection(
    scale: 1,
    origin: Offset.zero,
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Recomputed from the constraints on every layout, so a rotation or a
        // window resize rescales the view without touching the model
        // (spec section 8).
        _projection = CanvasProjection.view(
          constraints.biggest,
          zoom: widget.zoom,
          pan: widget.pan,
        );

        return Listener(
          // The scale recogniser does not report the touch-down — it only
          // fires once the finger has moved past the slop. Drawing from there
          // would lose the first few millimetres of every line, and would lose
          // a short flick entirely. The raw pointer gives the true landing
          // point; the recogniser below still decides what the gesture means.
          onPointerDown: (event) => _touchDownAt = event.localPosition,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: _handleTap,
            onLongPressStart: _handleLongPress,
            // A scale recogniser handles both: two fingers zoom in any mode, and
            // one finger draws or pans depending on the tool. Registering both a
            // pan and a scale recogniser would put them in the same arena and
            // make pinch unreliable.
            onScaleStart: _handleScaleStart,
            onScaleUpdate: _handleScaleUpdate,
            onScaleEnd: _handleScaleEnd,
            child: CustomPaint(
              size: constraints.biggest,
              painter: DesignPainter(
                design: widget.design,
                zoom: widget.zoom,
                pan: widget.pan,
                wetInk: _wetInk,
                selectedPanelId: widget.selectedPanelId,
                selectedDividerId: widget.selectedDividerId,
                notesVisible: widget.notesVisible,
                frameColor: AppColors.deepGreen,
                inkColor: AppColors.deepGreenHover,
                glassColor: scheme.surfaceContainerLowest,
                panelFillColor: AppColors.surface,
                selectionColor: AppColors.caution,
                labelColor: AppColors.deepGreen,
              ),
            ),
          ),
        );
      },
    );
  }

  // -- gestures -------------------------------------------------------------

  void _handleTap(TapUpDetails details) {
    // The touch-down point was recorded in case this became a drag; it did
    // not, so drop it.
    _touchDownAt = null;
    if (_wetInk.isNotEmpty) setState(_wetInk.clear);

    // A dimension label sits outside the frame, but a panel-width label sits
    // right under its panel, so labels are tested first.
    final label = DimensionLabels.at(
      DimensionLabels.of(widget.design, _projection),
      details.localPosition,
    );
    if (label != null) {
      widget.onDimensionTap(label);
      return;
    }

    widget.onPanelTap(_panelAt(_projection.toModel(details.localPosition)));
  }

  void _handleLongPress(LongPressStartDetails details) {
    final model = _projection.toModel(details.localPosition);

    // A divider sits on the edge of two panels, so it has to be asked about
    // first — otherwise it could never be grabbed.
    final divider = _dividerNear(details.localPosition);
    if (divider != null) {
      widget.onDividerLongPress(divider);
      return;
    }

    final panel = _panelAt(model);
    if (panel != null) widget.onPanelLongPress(panel);
  }

  /// Where the finger actually landed, from the raw pointer event.
  Offset? _touchDownAt;

  /// Where the gesture started, and what the view looked like then.
  Offset? _gestureStart;
  double _zoomAtStart = 1;
  Offset _panAtStart = Offset.zero;

  void _handleScaleStart(ScaleStartDetails details) {
    _zoomAtStart = widget.zoom;
    _panAtStart = widget.pan;
    // The recogniser's focal point is already past the slop; the raw
    // touch-down is where the user meant to start.
    final start = details.pointerCount > 1
        ? details.localFocalPoint
        : (_touchDownAt ?? details.localFocalPoint);
    _gestureStart = start;
    _draggingDivider = null;
    _draggingNote = null;

    if (details.pointerCount > 1) return;

    // A note label can be dragged while selecting. It is tested before
    // anything else under the finger, because it sits on top of a panel and
    // is the smaller, more deliberate target.
    if (widget.tool == CanvasTool.select && widget.notesVisible) {
      final label = NoteLabels.at(
        NoteLabels.of(widget.design, _projection),
        start,
      );
      if (label != null) {
        _draggingNote = label;
        _noteGrabOffset = label.centre - start;
        return;
      }
    }

    // A selected divider can be dragged, whatever the tool: the user has
    // already said which one they mean by long-pressing it.
    final selected = widget.selectedDividerId;
    if (selected != null) {
      final divider = _dividerNear(details.localFocalPoint);
      if (divider != null && divider.id == selected) {
        _draggingDivider = divider;
        return;
      }
    }

    if (widget.tool.drawsInk) {
      setState(() {
        _wetInk
          ..clear()
          ..add(_projection.toModel(start))
          // The point the recogniser accepted at, so a stroke short enough to
          // produce one move event still has two points to classify.
          ..add(_projection.toModel(details.localFocalPoint));
      });
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    // Two fingers always zoom, in every mode.
    if (details.pointerCount > 1) {
      if (_wetInk.isNotEmpty) setState(_wetInk.clear);
      _draggingDivider = null;
      _draggingNote = null;
      widget.onViewChanged(
        (_zoomAtStart * details.scale).clamp(
          CanvasProjection.minZoom,
          CanvasProjection.maxZoom,
        ),
        _panAtStart +
            (details.localFocalPoint - (_gestureStart ?? Offset.zero)),
      );
      return;
    }

    final note = _draggingNote;
    if (note != null) {
      widget.onNoteMoved(
        note.panelId,
        note.noteId,
        note.fractionOf(details.localFocalPoint + _noteGrabOffset),
      );
      return;
    }

    final dragging = _draggingDivider;
    if (dragging != null) {
      final model = _projection.toModel(details.localFocalPoint);
      widget.onDividerMoved(dragging, dragging.isVertical ? model.x : model.y);
      return;
    }

    if (widget.tool.drawsInk) {
      setState(() => _wetInk.add(_projection.toModel(details.localFocalPoint)));
      return;
    }

    // Select and Move both drag the sheet with one finger, so a user who has
    // stopped drawing can always get around.
    widget.onViewChanged(
      _zoomAtStart,
      _panAtStart + (details.localFocalPoint - (_gestureStart ?? Offset.zero)),
    );
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    final wasDragging = _draggingDivider != null || _draggingNote != null;
    _draggingDivider = null;
    _draggingNote = null;
    _gestureStart = null;
    _touchDownAt = null;
    if (wasDragging) widget.onGestureEnd();
    if (_wetInk.length < 2) {
      if (_wetInk.isNotEmpty) setState(_wetInk.clear);
      return;
    }
    final stroke = List<Point2>.of(_wetInk);
    setState(_wetInk.clear);
    widget.onStroke(stroke);
  }

  // -- hit testing ----------------------------------------------------------

  Panel? _panelAt(Point2 model) {
    for (final panel in widget.design.panels) {
      if (panel.boundary.contains(model)) return panel;
    }
    return null;
  }

  /// The divider within a finger's reach of [pixels].
  ///
  /// The reach is specified in pixels and converted to millimetres, because it
  /// describes a fingertip rather than a feature of the product — so it stays
  /// the same physical size however far the view is zoomed out.
  PanelDivider? _dividerNear(Offset pixels) {
    final model = _projection.toModel(pixels);
    final reach = _projection.lengthToModel(AppCanvasMetrics.dividerGrabRadius);

    PanelDivider? best;
    var bestDistance = double.infinity;
    for (final divider in widget.design.dividers) {
      final along = divider.isVertical ? model.y : model.x;
      final low = divider.isVertical ? divider.start.y : divider.start.x;
      final high = divider.isVertical ? divider.end.y : divider.end.x;
      if (along < low - reach || along > high + reach) continue;

      final across = divider.isVertical
          ? (model.x - divider.start.x).abs()
          : (model.y - divider.start.y).abs();
      if (across <= reach && across < bestDistance) {
        best = divider;
        bestDistance = across;
      }
    }
    return best;
  }
}
