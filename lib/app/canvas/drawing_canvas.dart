import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../domain/design_document.dart';
import '../../domain/geometry/point2.dart';
import '../../domain/panel.dart';
import '../../domain/panel_divider.dart';
import 'canvas_projection.dart';
import 'design_painter.dart';
import 'dimension_labels.dart';

/// The drawing surface.
///
/// One finger draws. A long press asks about whatever is under it — a divider
/// first, then a panel — which is what keeps drawing and editing from fighting
/// each other (spec section 4: drawing gestures stay separate from the rest).
class DrawingCanvas extends StatefulWidget {
  final DesignDocument design;
  final String? selectedPanelId;
  final String? selectedDividerId;

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

  const DrawingCanvas({
    required this.design,
    required this.onStroke,
    required this.onPanelLongPress,
    required this.onDividerLongPress,
    required this.onDividerMoved,
    required this.onPanelTap,
    required this.onDimensionTap,
    this.selectedPanelId,
    this.selectedDividerId,
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

  CanvasProjection _projection = const CanvasProjection(scale: 1, origin: Offset.zero);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Recomputed from the constraints on every layout, so a rotation or a
        // window resize rescales the view without touching the model
        // (spec section 8).
        _projection = CanvasProjection.fit(constraints.biggest);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: _handleTap,
          onLongPressStart: _handleLongPress,
          onPanDown: _handlePanDown,
          onPanStart: _handlePanStart,
          onPanUpdate: _handlePanUpdate,
          onPanEnd: _handlePanEnd,
          onPanCancel: _handlePanCancel,
          child: CustomPaint(
            size: constraints.biggest,
            painter: DesignPainter(
              design: widget.design,
              wetInk: _wetInk,
              selectedPanelId: widget.selectedPanelId,
              selectedDividerId: widget.selectedDividerId,
              frameColor: AppColors.deepGreen,
              inkColor: AppColors.deepGreenHover,
              glassColor: scheme.surfaceContainerLowest,
              panelFillColor: AppColors.surface,
              selectionColor: AppColors.caution,
              labelColor: AppColors.deepGreen,
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

  /// Records where the finger actually landed.
  ///
  /// [GestureDetector.onPanStart] does not fire until the touch slop has been
  /// exceeded, so starting the stroke there would lose the first few
  /// millimetres of every line — and would lose the whole stroke for a short
  /// flick that produces only one move event. Capturing on pan-down fixes
  /// both; a gesture that turns out to be a tap clears it again.
  void _handlePanDown(DragDownDetails details) {
    _wetInk
      ..clear()
      ..add(_projection.toModel(details.localPosition));
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

  void _handlePanStart(DragStartDetails details) {
    // Dragging a divider only happens once it has been long-pressed and is
    // showing as selected; otherwise a drag across one would move it by
    // accident while the user was drawing.
    final selected = widget.selectedDividerId;
    if (selected != null) {
      final divider = _dividerNear(details.localPosition);
      if (divider != null && divider.id == selected) {
        _draggingDivider = divider;
        _wetInk.clear();
        return;
      }
    }
    setState(() => _wetInk.add(_projection.toModel(details.localPosition)));
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final dragging = _draggingDivider;
    if (dragging != null) {
      final model = _projection.toModel(details.localPosition);
      widget.onDividerMoved(dragging, dragging.isVertical ? model.x : model.y);
      return;
    }
    setState(() => _wetInk.add(_projection.toModel(details.localPosition)));
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_draggingDivider != null) {
      _draggingDivider = null;
      return;
    }
    if (_wetInk.length < 2) {
      setState(_wetInk.clear);
      return;
    }
    final stroke = List<Point2>.of(_wetInk);
    setState(_wetInk.clear);
    widget.onStroke(stroke);
  }

  void _handlePanCancel() {
    _draggingDivider = null;
    if (_wetInk.isNotEmpty) setState(_wetInk.clear);
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
