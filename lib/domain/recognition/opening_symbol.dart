import 'dart:math' as math;

import '../geometry/tolerances.dart';
import '../geometry/vec2.dart';
import '../model/elements.dart';
import '../sketch/stroke.dart';
import 'stroke_fit.dart';

/// Which way the symbol points.
enum SymbolDirection {
  /// `<` — the apex is on the left.
  pointsLeft('<'),

  /// `>` — the apex is on the right.
  pointsRight('>');

  const SymbolDirection(this.glyph);
  final String glyph;
}

/// A `<` or a `>` the user drew to say that a section opens.
///
/// This is the only thing in the application that creates an opening. There
/// is no rule anywhere that decides a section ought to open, no door leaf
/// chosen because it is the lower one or the wider one, and no template.
/// The user marks the section; the application reads the mark.
class OpeningSymbol {
  final String strokeId;

  /// The point of the chevron.
  final Vec2 apex;

  /// The two open ends.
  final Vec2 armA;
  final Vec2 armB;

  final SymbolDirection direction;

  const OpeningSymbol({
    required this.strokeId,
    required this.apex,
    required this.armA,
    required this.armB,
    required this.direction,
  });

  String get glyph => direction.glyph;

  Vec2 get centre => Vec2(
        (apex.x + armA.x + armB.x) / 3,
        (apex.y + armA.y + armB.y) / 3,
      );

  /// Every point that has to be inside a section for the mark to belong to
  /// it beyond doubt.
  List<Vec2> get points => [apex, armA, armB, centre];

  double get sizeMm => math.max(
        apex.distanceTo(armA),
        apex.distanceTo(armB),
      );

  /// What the mark means.
  ///
  /// A chevron pointing right is the standard elevation symbol for a leaf
  /// hinged on the left and opening from the right — the point is at the
  /// edge that moves. Pointing left is its mirror. Both readings of `>`
  /// agree: it hinges left, and it opens rightward.
  OpeningMechanism get mechanism => direction == SymbolDirection.pointsRight
      ? OpeningMechanism.hingedLeft
      : OpeningMechanism.hingedRight;

  String get meaning => direction == SymbolDirection.pointsRight
      ? 'hinged on the left, opening from the right'
      : 'hinged on the right, opening from the left';
}

/// Reads `<` and `>` out of the user's strokes.
///
/// It recognises those two marks and nothing else. A stroke that is nearly a
/// chevron but not clearly one is left alone to be a line, and a chevron
/// pointing up or down is not one of the two documented symbols, so it is
/// not treated as one.
abstract final class OpeningSymbolReader {
  /// The mark [stroke] is, or null when it is not one.
  static OpeningSymbol? read(Stroke stroke) {
    final fit = StrokeFitter.fit(stroke);
    if (fit.kind != FitKind.polyline || fit.isClosed) return null;
    if (fit.vertices.length != 3) return null;

    final start = fit.vertices[0];
    final apex = fit.vertices[1];
    final finish = fit.vertices[2];

    final armA = apex.distanceTo(start);
    final armB = apex.distanceTo(finish);
    if (armA < Tol.minLineMm || armB < Tol.minLineMm) return null;

    // Two arms of roughly the same length. A short flick off the end of a
    // long line is not a chevron.
    final shorter = math.min(armA, armB);
    final longer = math.max(armA, armB);
    if (shorter / longer < 0.4) return null;

    // An apex you could call a point: not a straight line, not folded flat.
    final angle = _angleAt(apex, start, finish);
    if (angle < 15 || angle > 150) return null;

    final toStart = start - apex;
    final toFinish = finish - apex;

    // Both ends the same side of the apex across, and opposite sides down.
    // That is what makes a chevron a chevron rather than a hook or a vee.
    if (toStart.x.sign != toFinish.x.sign) return null;
    if (toStart.y.sign == toFinish.y.sign) return null;
    if (toStart.x.abs() < longer * 0.3) return null;
    if (toFinish.x.abs() < longer * 0.3) return null;
    if (toStart.y.abs() < longer * 0.15) return null;
    if (toFinish.y.abs() < longer * 0.15) return null;

    // A mark that is wider than it is tall is pointing up or down, which is
    // neither of the two symbols the user was given.
    final width = math.max(start.x, math.max(apex.x, finish.x)) -
        math.min(start.x, math.min(apex.x, finish.x));
    final height = math.max(start.y, math.max(apex.y, finish.y)) -
        math.min(start.y, math.min(apex.y, finish.y));
    if (height <= 0 || width / height > 2.2) return null;

    return OpeningSymbol(
      strokeId: stroke.id,
      apex: apex,
      armA: start,
      armB: finish,
      // The ends sit to the left of the apex, so the apex points right.
      direction: toStart.x < 0
          ? SymbolDirection.pointsRight
          : SymbolDirection.pointsLeft,
    );
  }

  static double _angleAt(Vec2 apex, Vec2 a, Vec2 b) {
    final u = (a - apex).normalised;
    final v = (b - apex).normalised;
    final dot = u.dot(v).clamp(-1.0, 1.0);
    return math.acos(dot) * 180 / math.pi;
  }
}
