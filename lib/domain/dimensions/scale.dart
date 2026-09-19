import 'dart:math' as math;

import '../geometry/polygon.dart';
import '../geometry/vec2.dart';
import '../model/design.dart';
import '../model/elements.dart';
import '../sketch/stroke.dart';
import 'units.dart';

/// Puts a design into real millimetres.
///
/// A typed dimension is the truth, and everything else moves to agree with
/// it — in proportion, all together. A 48/52 split that is scaled to a real
/// width is still 48/52 afterwards, because every point is multiplied by the
/// same number about the same origin. Nothing is redistributed, rounded to a
/// nicer figure, or made equal on the way.
abstract final class DesignScale {
  /// The design resized so that its overall width reads [widthMm].
  static Design toWidth(Design design, double widthMm) {
    final current = design.widthMm;
    if (current <= 0 || widthMm <= 0) return design;
    return by(design, widthMm / current);
  }

  /// The design resized so that its overall height reads [heightMm].
  static Design toHeight(Design design, double heightMm) {
    final current = design.heightMm;
    if (current <= 0 || heightMm <= 0) return design;
    return by(design, heightMm / current);
  }

  /// The design resized so that [dimension] reads [valueMm].
  ///
  /// Scaling from any dimension, not only the overall one, is what lets a
  /// user measure the one part they know — a leaf width, a bottom rail — and
  /// have the rest follow from it.
  static Design toDimension(
    Design design,
    DimensionElement dimension,
    double valueMm,
  ) {
    final measured = dimension.measuredMm;
    if (measured <= 0 || valueMm <= 0) return design;
    final scaled = by(design, valueMm / measured);
    return scaled.withElement(
      (scaled.elementById(dimension.id)! as DimensionElement)
          .copyWith(statedMm: valueMm),
    );
  }

  /// Every point multiplied by [factor] about the top-left of the design.
  ///
  /// Profiles and bar widths scale too. They have to: a 60 mm frame on a
  /// drawing twice too small is a 120 mm frame on the real thing, and
  /// leaving it behind would change the proportions the user drew.
  static Design by(Design design, double factor) {
    if (!factor.isFinite || factor <= 0) return design;
    if ((factor - 1).abs() < 1e-9) return design;

    final origin = design.bounds?.topLeft ?? Vec2.zero;
    Vec2 point(Vec2 p) => Vec2(
          origin.x + (p.x - origin.x) * factor,
          origin.y + (p.y - origin.y) * factor,
        );
    Polygon shape(Polygon p) =>
        Polygon([for (final c in p.corners) point(c)]);

    return design.copyWith(
      frame: design.frame?.copyWith(
        outline: shape(design.frame!.outline),
        profileMm: design.frame!.profileMm * factor,
      ),
      dividers: [
        for (final d in design.dividers)
          d.copyWith(a: point(d.a), b: point(d.b), widthMm: d.widthMm * factor),
      ],
      sections: [
        for (final s in design.sections) s.copyWith(outline: shape(s.outline)),
      ],
      hardware: [for (final h in design.hardware) h.copyWith(at: point(h.at))],
      dimensions: [
        for (final d in design.dimensions)
          d.copyWith(
            a: point(d.a),
            b: point(d.b),
            offsetMm: d.offsetMm * factor,
            statedMm: d.isStated ? d.statedMm! * factor : null,
          ),
      ],
      texts: [
        for (final t in design.texts)
          t.copyWith(at: point(t.at), sizeMm: t.sizeMm * factor),
      ],
      arrows: [
        for (final a in design.arrows)
          a.copyWith(from: point(a.from), to: point(a.to)),
      ],
      depthMm: design.depthMm * factor,
      // The user's own marks are scaled with everything else, so the ink
      // still sits on the lines it produced.
      sketch: Sketch(strokes: [
        for (final stroke in design.sketch.strokes)
          stroke.copyWith(samples: [
            for (final s in stroke.samples) s.movedTo(point(s.at)),
          ]),
      ]),
    );
  }

  /// How far the design is from the sizes the user typed, as a fraction.
  ///
  /// Zero means every stated dimension is exactly right. Anything else is
  /// shown to the user rather than quietly corrected, because which
  /// dimension is the one to believe is their decision, not the
  /// application's.
  static List<DimensionConflict> conflicts(Design design) {
    final conflicts = <DimensionConflict>[];
    for (final dimension in design.dimensions) {
      if (!dimension.isStated) continue;
      final measured = dimension.measuredMm;
      if (measured <= 0) continue;
      final off = (measured - dimension.statedMm!).abs();
      if (off <= math.max(1.0, dimension.statedMm! * 0.002)) continue;
      conflicts.add(DimensionConflict(
        dimension: dimension,
        measuredMm: measured,
        statedMm: dimension.statedMm!,
      ));
    }
    return conflicts;
  }
}

/// A dimension the user typed that the geometry no longer agrees with.
class DimensionConflict {
  final DimensionElement dimension;
  final double measuredMm;
  final double statedMm;

  const DimensionConflict({
    required this.dimension,
    required this.measuredMm,
    required this.statedMm,
  });

  double get differenceMm => measuredMm - statedMm;

  String get message => 'This reads ${Units.label(measuredMm)} but you typed '
      '${Units.label(statedMm)}.';
}
