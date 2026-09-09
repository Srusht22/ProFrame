import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utilities/geometry_math.dart';
import '../../../shared/models/design_region.dart';
import '../../../shared/models/opening_model.dart';
import '../../geometry/region_solver.dart';
import '../painters/technical_drawing_painter.dart';

/// A boundary the user can grab.
typedef EdgeTarget = ({String regionId, RegionEdge edge, double positionMm});

/// The 2D technical drawing, with direct manipulation.
///
/// Tapping selects the section under the finger. Dragging an internal boundary
/// moves it, carrying every section that shares it, so the totals still add up.
/// Both routes end in the same edit the numeric fields make.
class TechnicalDrawingView extends StatefulWidget {
  final OpeningModel model;
  final bool showDimensions;
  final bool showLabels;
  final String? selectedRegionId;
  final bool interactive;

  final ValueChanged<String?>? onSelect;
  final void Function(EdgeTarget target)? onDragStart;
  final void Function(EdgeTarget target, double positionMm)? onDragUpdate;
  final VoidCallback? onDragEnd;

  const TechnicalDrawingView({
    super.key,
    required this.model,
    this.showDimensions = true,
    this.showLabels = true,
    this.selectedRegionId,
    this.interactive = true,
    this.onSelect,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
  });

  @override
  State<TechnicalDrawingView> createState() => _TechnicalDrawingViewState();
}

class _TechnicalDrawingViewState extends State<TechnicalDrawingView> {
  final TransformationController _transformation = TransformationController();
  EdgeTarget? _dragging;
  Offset? _hover;

  /// How close a touch has to be to a boundary to grab it, in pixels.
  static const double grabTolerance = 14;

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  bool get _canEdit => widget.interactive && widget.onDragUpdate != null;

  DrawingProjection _projection(Size size) => TechnicalDrawingPainter(
        model: widget.model,
        showDimensions: widget.showDimensions,
        showLabels: widget.showLabels,
      ).projectionFor(size);

  /// The nearest internal boundary to a point, or null when there is none
  /// within reach.
  EdgeTarget? _edgeAt(Vec2 point, double toleranceMm) {
    EdgeTarget? best;
    var bestDistance = double.infinity;
    final outer = widget.model.outerRect;

    for (final region in RegionTree.all(widget.model.regions)) {
      final rect = region.rect;
      final candidates = <(RegionEdge, double, bool)>[
        (RegionEdge.left, rect.left, true),
        (RegionEdge.right, rect.right, true),
        (RegionEdge.top, rect.top, false),
        (RegionEdge.bottom, rect.bottom, false),
      ];

      for (final (edge, position, vertical) in candidates) {
        // The outside of the product is the frame, not a movable boundary.
        if (vertical &&
            (position <= outer.left + 0.5 || position >= outer.right - 0.5)) {
          continue;
        }
        if (!vertical &&
            (position <= outer.top + 0.5 || position >= outer.bottom - 0.5)) {
          continue;
        }

        final along = vertical ? point.y : point.x;
        final spanStart = vertical ? rect.top : rect.left;
        final spanEnd = vertical ? rect.bottom : rect.right;
        if (along < spanStart - toleranceMm || along > spanEnd + toleranceMm) continue;

        final distance = ((vertical ? point.x : point.y) - position).abs();
        if (distance <= toleranceMm && distance < bestDistance) {
          bestDistance = distance;
          best = (regionId: region.id, edge: edge, positionMm: position);
        }
      }
    }
    return best;
  }

  void _handleTap(Offset local, Size size) {
    if (widget.onSelect == null) return;
    final projection = _projection(size);
    final point = projection.toModel(local);
    final solved = RegionSolver.solve(widget.model);
    widget.onSelect!(solved.regionAt(point)?.id);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final projection = _projection(size);
        final toleranceMm = projection.toMm(grabTolerance);

        final painter = CustomPaint(
          size: size,
          painter: TechnicalDrawingPainter(
            model: widget.model,
            showDimensions: widget.showDimensions,
            showLabels: widget.showLabels,
            highlightRegionId: widget.selectedRegionId,
            showHandles: _canEdit,
          ),
        );

        if (!widget.interactive) {
          return ColoredBox(color: AppColors.neutralOffWhite, child: painter);
        }

        return ColoredBox(
          color: AppColors.neutralOffWhite,
          child: MouseRegion(
            cursor: _cursorFor(),
            onHover: !_canEdit
                ? null
                : (event) {
                    final edge = _edgeAt(
                      projection.toModel(event.localPosition),
                      toleranceMm,
                    );
                    final next = edge == null
                        ? null
                        : Offset(edge.positionMm, edge.edge.isVerticalEdge ? 1 : 0);
                    if (next != _hover) setState(() => _hover = next);
                  },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => _handleTap(details.localPosition, size),
              onPanStart: !_canEdit
                  ? null
                  : (details) {
                      final edge = _edgeAt(
                        projection.toModel(details.localPosition),
                        toleranceMm,
                      );
                      if (edge == null) return;
                      setState(() => _dragging = edge);
                      widget.onDragStart?.call(edge);
                    },
              onPanUpdate: !_canEdit
                  ? null
                  : (details) {
                      final target = _dragging;
                      if (target == null) return;
                      final point = projection.toModel(details.localPosition);
                      final position =
                          target.edge.isVerticalEdge ? point.x : point.y;
                      widget.onDragUpdate?.call(target, position);
                    },
              onPanEnd: !_canEdit
                  ? null
                  : (_) {
                      if (_dragging == null) return;
                      setState(() => _dragging = null);
                      widget.onDragEnd?.call();
                    },
              child: painter,
            ),
          ),
        );
      },
    );
  }

  MouseCursor _cursorFor() {
    final hover = _hover;
    if (hover == null) return SystemMouseCursors.basic;
    return hover.dy == 1
        ? SystemMouseCursors.resizeLeftRight
        : SystemMouseCursors.resizeUpDown;
  }
}

/// Small preview used on design cards. Never a stored image — it is redrawn
/// from the model, so a card can never show a stale design.
class DesignThumbnail extends StatelessWidget {
  final OpeningModel model;

  const DesignThumbnail({super.key, required this.model});

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: AppColors.neutralOffWhite,
        child: CustomPaint(
          painter: TechnicalDrawingPainter(
            model: model,
            showDimensions: false,
            showLabels: false,
            margin: 10,
          ),
          child: const SizedBox.expand(),
        ),
      );
}
