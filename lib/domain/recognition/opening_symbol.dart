import 'dart:math' as math;

import '../geometry/segment.dart';
import '../geometry/tolerances.dart';
import '../geometry/vec2.dart';
import '../model/elements.dart';
import '../sketch/stroke.dart';
import 'stroke_fit.dart';

/// Which way the symbol points.
///
/// The point is always at the edge that moves, which is the edge opposite
/// the hinge. That one rule covers all four marks.
enum SymbolDirection {
  /// `<` — the apex is on the left, so the left edge opens.
  pointsLeft('<', OpeningMechanism.hingedRight,
      'hinged on the right, opening from the left'),

  /// `>` — the apex is on the right, so the right edge opens.
  pointsRight('>', OpeningMechanism.hingedLeft,
      'hinged on the left, opening from the right'),

  /// `^` — the apex is at the top, so the top edge opens.
  pointsUp('^', OpeningMechanism.bottomHung,
      'hinged at the bottom, opening at the top'),

  /// `v` — the apex is at the bottom, so the bottom edge opens.
  pointsDown('v', OpeningMechanism.topHung,
      'hinged at the top, opening at the bottom');

  const SymbolDirection(this.glyph, this.mechanism, this.meaning);

  final String glyph;
  final OpeningMechanism mechanism;
  final String meaning;

  /// The mark that says this mechanism, where one of the four does.
  static SymbolDirection? forMechanism(OpeningMechanism mechanism) {
    for (final direction in values) {
      if (direction.mechanism == mechanism) return direction;
    }
    return null;
  }
}

/// A `<`, `>`, `^` or `v` the user drew to say that a section opens.
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
  /// The point is at the edge that moves and the hinge is opposite it, which
  /// is how these are read on an elevation. Both readings of `>` agree: it
  /// hinges left, and it opens rightward.
  OpeningMechanism get mechanism => direction.mechanism;

  String get meaning => direction.meaning;
}

/// Reads `<`, `>`, `^` and `v` out of the user's strokes.
///
/// It recognises those four marks and nothing else. A stroke that is nearly
/// a chevron but not clearly one is left alone to be a line.
///
/// A mark made by a hand is not two clean segments. It is read with a corner
/// or two of wobble along each arm, and a wobble is not a second point — so
/// the shape is judged by where its point is and whether its arms are arms,
/// not by how many corners the fitting happened to find. Getting this wrong
/// is expensive: a mark that is not read as a mark becomes two bars that cut
/// the design in half, and the section the user said opens does not open.
abstract final class OpeningSymbolReader {
  /// How far a corner along an arm may sit off the straight run of that arm,
  /// as a fraction of the arm's length, before the shape is a zigzag rather
  /// than a chevron drawn by hand.
  static const double armWanderFraction = 0.2;

  /// The mark [stroke] is, or null when it is not one.
  static OpeningSymbol? read(Stroke stroke) {
    final fit = StrokeFitter.fit(stroke);
    if (fit.kind != FitKind.polyline || fit.isClosed) return null;

    final corners = fit.vertices;
    if (corners.length < 3) return null;

    final start = corners.first;
    final finish = corners.last;

    // The point of the chevron is the corner furthest from the line joining
    // the two ends. On a clean mark that is the middle one; on a shaky one
    // it is still the one the mark turns about.
    final chord = Segment(start, finish);
    var apexAt = 1;
    var furthest = -1.0;
    for (var i = 1; i < corners.length - 1; i++) {
      final away = chord.distanceTo(corners[i]);
      if (away > furthest) {
        furthest = away;
        apexAt = i;
      }
    }
    final apex = corners[apexAt];

    // Both arms have to be arms. Every corner along one lies near the
    // straight run from its end to the point, or this is a zigzag, a
    // staircase or part of a frame drawn in pieces — none of which is a
    // mark, and each of which must be built exactly as it was drawn.
    if (!_isArm(corners.sublist(0, apexAt + 1))) return null;
    if (!_isArm(corners.sublist(apexAt))) return null;

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

    // A chevron has both arms leaving the point on the same side of one axis
    // and opposite sides of the other. Which axis that is decides which of
    // the four marks it is. A corner — part of a frame drawn in pieces —
    // has its arms on perpendicular axes and matches neither pattern.
    bool sameSide(double a, double b) =>
        a.abs() >= longer * 0.3 && b.abs() >= longer * 0.3 && a * b > 0;
    bool eitherSide(double a, double b) =>
        a.abs() >= longer * 0.15 && b.abs() >= longer * 0.15 && a * b < 0;

    final SymbolDirection direction;
    if (sameSide(toStart.x, toFinish.x) && eitherSide(toStart.y, toFinish.y)) {
      // The ends sit to the left of the apex, so the apex points right.
      direction = toStart.x < 0
          ? SymbolDirection.pointsRight
          : SymbolDirection.pointsLeft;
    } else if (sameSide(toStart.y, toFinish.y) &&
        eitherSide(toStart.x, toFinish.x)) {
      // The ends sit below the apex, so the apex points up.
      direction = toStart.y > 0
          ? SymbolDirection.pointsUp
          : SymbolDirection.pointsDown;
    } else {
      return null;
    }

    return OpeningSymbol(
      strokeId: stroke.id,
      apex: apex,
      armA: start,
      armB: finish,
      direction: direction,
    );
  }

  /// True when [along] is one straight run with a hand's wobble on it.
  static bool _isArm(List<Vec2> along) {
    if (along.length <= 2) return true;
    final run = Segment(along.first, along.last);
    if (run.length < Tol.minLineMm) return false;
    final allowed = run.length * armWanderFraction;
    for (var i = 1; i < along.length - 1; i++) {
      if (run.distanceTo(along[i]) > allowed) return false;
    }
    return true;
  }

  static double _angleAt(Vec2 apex, Vec2 a, Vec2 b) {
    final u = (a - apex).normalised;
    final v = (b - apex).normalised;
    final dot = u.dot(v).clamp(-1.0, 1.0);
    return math.acos(dot) * 180 / math.pi;
  }
}
