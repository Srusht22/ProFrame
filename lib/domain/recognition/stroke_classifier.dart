import 'dart:math' as math;

import '../geometry/point2.dart';
import '../geometry/polygon.dart';
import '../geometry/tolerances.dart';
import '../panel.dart';
import '../product/opening.dart';
import '../sketch.dart';
import 'stroke_intent.dart';
import 'stroke_simplifier.dart';

/// Reads one stroke and decides what the user meant by it.
///
/// Deterministic and rule-based: the same stroke always produces the same
/// intent, there is no model, no network call and no randomness. That is a
/// requirement, not a shortcut — these users explicitly do not want to
/// interact with an AI, and a wrong guess here changes a product somebody is
/// going to build (spec sections 1 and 4).
///
/// The grammar is exactly five outcomes, checked in this order:
///
/// 1. a closed-ish loop with about four corners → the frame
/// 2. a chevron inside a panel → that panel opens, hinged at the point
/// 3. a mostly-vertical stroke inside the frame → a mullion
/// 4. a mostly-horizontal stroke inside the frame → a transom
/// 5. anything else → discarded silently
///
/// The chevron is tested before the straight lines because a `<` is two
/// segments and a divider is one; checking the line first would match a
/// chevron's first leg.
class StrokeClassifier {
  /// The frame already recognised, or null before one has been drawn.
  final Polygon? frame;

  /// The panels the design currently has, used to decide which one a mark
  /// landed in.
  final List<Panel> panels;

  const StrokeClassifier({this.frame, this.panels = const []});

  /// Classifies [stroke] against the current state of the design.
  StrokeIntent classify(Stroke stroke) {
    final cleaned = StrokeSimplifier.dropClusteredPoints(stroke.points);
    if (cleaned.length < 2) {
      return DiscardedIntent(stroke.id, 'A tap, not a stroke.');
    }

    final corners = StrokeSimplifier.simplify(
      cleaned,
      toleranceMm: Tolerances.cornerToleranceMm,
    );
    final bounds = _boundsOf(cleaned);

    // 1. The frame. Only recognised when there is not one already: a second
    //    loop is a correction the user makes by undoing, not by drawing over.
    if (frame == null) {
      final loop = _asFrame(stroke, cleaned, corners, bounds);
      if (loop != null) return loop;
      return DiscardedIntent(
        stroke.id,
        'Nothing can be drawn until a frame has been.',
      );
    }

    // Everything after this point has to be inside the frame.
    if (!_isInsideFrame(cleaned)) {
      return DiscardedIntent(stroke.id, 'Drawn outside the frame.');
    }

    // 2. A chevron marking a panel as opening.
    final chevron = _asChevron(stroke, corners);
    if (chevron != null) return chevron;

    // 3 and 4. A divider.
    final divider = _asDivider(stroke, corners, bounds);
    if (divider != null) return divider;

    return DiscardedIntent(stroke.id, 'Not a frame, a divider or a chevron.');
  }

  // -- frame ----------------------------------------------------------------

  StrokeIntent? _asFrame(
    Stroke stroke,
    List<Point2> cleaned,
    List<Point2> corners,
    _Bounds bounds,
  ) {
    if (bounds.width < Tolerances.minimumFrameSideMm ||
        bounds.height < Tolerances.minimumFrameSideMm) {
      return null;
    }

    // Closed-ish: the ends meet within a quarter of the loop's own diagonal.
    final diagonal = math.sqrt(
      bounds.width * bounds.width + bounds.height * bounds.height,
    );
    final gap = cleaned.first.distanceTo(cleaned.last);
    if (gap > diagonal * Tolerances.loopClosureFraction) return null;

    // About four corners. The simplifier returns the first point twice when a
    // loop closes exactly, so 4 to 6 all describe a quadrilateral drawn by
    // hand; fewer is a line or a curve, more is a scribble.
    final cornerCount = _distinctCornerCount(corners);
    if (cornerCount < 4 || cornerCount > 6) return null;

    // A deliberate slope across the top is kept exactly as drawn; a shaky
    // level line is straightened. The 5-degree tolerance is what separates
    // them (spec section 4, and Tolerances.axisAlignmentDegrees).
    final slope = _slopingTopOf(cleaned, bounds);
    if (slope != null) {
      return FrameIntent(stroke.id, slope, hasSlopingTop: true);
    }

    return FrameIntent(
      stroke.id,
      Polygon.rectangle(
        width: bounds.width,
        height: bounds.height,
        topLeft: Point2(bounds.left, bounds.top),
      ),
    );
  }

  /// A sloping-top outline, or null when the top was drawn level.
  ///
  /// The two side heights are measured from the ink itself: the highest point
  /// the stroke reaches near the left edge, and near the right. If they differ
  /// by enough to clear the axis tolerance across the frame's width, the user
  /// meant a slope and it is kept — never averaged into a level head, which is
  /// the thing the spec forbids most plainly (section 2).
  Polygon? _slopingTopOf(List<Point2> points, _Bounds bounds) {
    // A narrow band at each side. Narrow on purpose: a wide band samples
    // points partway along the slope, which are higher than the corner, and
    // would report a taller side than the user drew. Eight per cent is wide
    // enough to catch a roughly-drawn corner and narrow enough that the
    // slope across it is negligible.
    final band = bounds.width * 0.08;
    var leftTop = double.infinity;
    var rightTop = double.infinity;
    for (final point in points) {
      if (point.x <= bounds.left + band) {
        leftTop = math.min(leftTop, point.y);
      }
      if (point.x >= bounds.right - band) {
        rightTop = math.min(rightTop, point.y);
      }
    }
    if (!leftTop.isFinite || !rightTop.isFinite) return null;

    final rise = (leftTop - rightTop).abs();
    // The angle the two corners actually make across the frame.
    final degrees = math.atan2(rise, bounds.width) * 180 / math.pi;
    if (degrees <= Tolerances.axisAlignmentDegrees) return null;

    return Polygon([
      Point2(bounds.left, leftTop),
      Point2(bounds.right, rightTop),
      Point2(bounds.right, bounds.bottom),
      Point2(bounds.left, bounds.bottom),
    ]);
  }

  /// Corner count ignoring a closing point that lands back on the first.
  static int _distinctCornerCount(List<Point2> corners) {
    if (corners.length > 1 && corners.first.coincidesWith(corners.last)) {
      return corners.length - 1;
    }
    return corners.length;
  }

  // -- chevron --------------------------------------------------------------

  StrokeIntent? _asChevron(Stroke stroke, List<Point2> corners) {
    // Exactly two segments: down-and-back, or up-and-back.
    if (corners.length != 3) return null;

    final start = corners[0];
    final apex = corners[1];
    final end = corners[2];

    // Both arms need real length, or this is a line with a kink in it.
    final armA = start.distanceTo(apex);
    final armB = apex.distanceTo(end);
    if (armA < Tolerances.minimumPanelSideMm / 2 ||
        armB < Tolerances.minimumPanelSideMm / 2) {
      return null;
    }

    // The apex has to stick out sideways past both ends; that is what makes it
    // a `<` or a `>` rather than a `v` or a `^`.
    final pointsLeft = apex.x < start.x && apex.x < end.x;
    final pointsRight = apex.x > start.x && apex.x > end.x;
    if (!pointsLeft && !pointsRight) return null;

    // And it has to stick out far enough to be a point rather than a kink in
    // a line the user meant to draw straight.
    final sidewaysReach = pointsLeft
        ? math.min(start.x, end.x) - apex.x
        : apex.x - math.max(start.x, end.x);
    final armLength = (armA + armB) / 2;
    if (sidewaysReach < armLength * Tolerances.chevronReachFraction) {
      return null;
    }

    final panel = _panelContaining(apex) ?? _panelContaining(_centroid(corners));
    if (panel == null) return null;

    return ChevronIntent(
      stroke.id,
      panelId: panel.id,
      // The point of the chevron is the hinge edge — the factory's own
      // convention, stated in the spec rather than inferred here.
      hingeSide: pointsLeft ? HingeSide.left : HingeSide.right,
      apex: apex,
    );
  }

  // -- dividers -------------------------------------------------------------

  StrokeIntent? _asDivider(Stroke stroke, List<Point2> corners, _Bounds bounds) {
    // One segment. A stroke with corners in it is not a divider.
    if (corners.length != 2) return null;

    final width = bounds.width;
    final height = bounds.height;

    final isVertical = height >= width * Tolerances.dividerAxisDominance;
    final isHorizontal = width >= height * Tolerances.dividerAxisDominance;
    // A stroke that leans diagonally is neither, and is dropped rather than
    // snapped to whichever axis it happens to favour.
    if (!isVertical && !isHorizontal) return null;

    if (isVertical) {
      // Snapped: the line becomes exactly vertical at the stroke's mid-x.
      final atX = (bounds.left + bounds.right) / 2;
      final panel = _panelSpanning(atX, vertical: true, bounds: bounds);
      if (panel == null) return null;
      if (!_leavesRoomInside(panel, atX, vertical: true)) return null;
      return VerticalDividerIntent(stroke.id, atX, panel.id);
    }

    final atY = (bounds.top + bounds.bottom) / 2;
    final panel = _panelSpanning(atY, vertical: false, bounds: bounds);
    if (panel == null) return null;
    if (!_leavesRoomInside(panel, atY, vertical: false)) return null;
    return HorizontalDividerIntent(stroke.id, atY, panel.id);
  }

  /// A divider must leave a buildable panel on both sides, otherwise it is a
  /// stray mark along an edge rather than a division.
  bool _leavesRoomInside(Panel panel, double at, {required bool vertical}) {
    final low = vertical ? panel.boundary.left : panel.boundary.top;
    final high = vertical ? panel.boundary.right : panel.boundary.bottom;
    return at - low >= Tolerances.minimumPanelSideMm &&
        high - at >= Tolerances.minimumPanelSideMm;
  }

  // -- lookups --------------------------------------------------------------

  Panel? _panelContaining(Point2 point) {
    for (final panel in panels) {
      if (panel.boundary.contains(point)) return panel;
    }
    return null;
  }

  /// The panel a divider at [at] should split: the one it crosses, judged by
  /// the midpoint of the stroke along its own long axis.
  Panel? _panelSpanning(double at, {required bool vertical, required _Bounds bounds}) {
    final along = vertical
        ? Point2(at, (bounds.top + bounds.bottom) / 2)
        : Point2((bounds.left + bounds.right) / 2, at);
    return _panelContaining(along);
  }

  bool _isInsideFrame(List<Point2> points) {
    final outline = frame;
    if (outline == null) return false;
    // Every sample has to be in the frame: a stroke that starts outside and
    // wanders in is not a division of anything.
    return points.every(outline.contains);
  }

  static Point2 _centroid(List<Point2> points) {
    var x = 0.0;
    var y = 0.0;
    for (final point in points) {
      x += point.x;
      y += point.y;
    }
    return Point2(x / points.length, y / points.length);
  }

  static _Bounds _boundsOf(List<Point2> points) {
    var left = points.first.x;
    var right = points.first.x;
    var top = points.first.y;
    var bottom = points.first.y;
    for (final point in points) {
      left = math.min(left, point.x);
      right = math.max(right, point.x);
      top = math.min(top, point.y);
      bottom = math.max(bottom, point.y);
    }
    return _Bounds(left, top, right, bottom);
  }
}

class _Bounds {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const _Bounds(this.left, this.top, this.right, this.bottom);

  double get width => right - left;
  double get height => bottom - top;
}
