import 'dart:math' as math;

import '../geometry/polygon.dart';
import '../geometry/vec2.dart';
import '../model/design.dart';
import '../model/elements.dart';
import '../model/opening_leaf.dart';
import '../solid/mesh.dart';
import '../solid/turned.dart';
import 'opening_hardware.dart';

/// A piece of ironmongery on a leaf, seen square on: where each of its parts
/// is and how big, in the design's own millimetres.
///
/// **One description, read by every view.** The solid stands these shapes
/// off the leaf and gives them depth; the technical drawing and the drawing
/// draw them flat. They used to be sized twice — the solid from the leaf, the
/// drawings from the whole design — so a lever on a narrow sash was one size
/// in the model and another on the sheet. Now there is one size, and it is
/// the leaf's.
///
/// Every figure is taken from the leaf through [scale], so a garden gate and
/// a front door each get ironmongery in proportion to themselves.
class Furniture {
  final HardwareElement piece;

  /// The edge the leaf hangs on — or, for a sliding panel, the edge it leads
  /// with, which stands where hinges would, opposite its handle.
  final OpeningEdge hinge;

  /// How big the ironmongery is for this leaf: see [scaleFor].
  final double scale;

  /// A sash stile's width, which a pull is centred on.
  final double stile;

  /// How long a sliding panel's pull is: [OpeningHardware.pullLengthOf].
  final double pullLength;

  const Furniture._(
    this.piece,
    this.hinge,
    this.scale,
    this.stile,
    this.pullLength,
  );

  /// The kinds that are built as the pieces they are. Anything else on a
  /// leaf is a plain plate: [plainPlate].
  static const built = {
    HardwareKind.hinge,
    HardwareKind.lock,
    HardwareKind.lever,
    HardwareKind.handle,
    HardwareKind.knob,
    HardwareKind.pull,
  };

  /// The piece as it is built on its leaf, or null when it is not on a leaf
  /// or not one of the [built] kinds.
  static Furniture? of(Design design, HardwareElement piece) {
    if (!built.contains(piece.kind)) return null;
    final opening = design.openingHolding(piece.parentId);
    if (opening == null) return null;
    final hinge = opening.mechanism.hingeEdge ?? opening.mechanism.slideEdge;
    final section = design.sectionById(opening.sectionId);
    if (section == null || hinge == null) return null;
    final frame = design.frame;
    return Furniture._(
      piece,
      hinge,
      scaleFor(section.outline),
      frame == null ? 0.0 : OpeningLeaf.profileFor(frame),
      OpeningHardware.pullLengthOf(design, piece),
    );
  }

  /// Ironmongery in proportion to its leaf: a 900 mm leaf's is the size the
  /// figures below are written for, and nothing is made smaller than a
  /// hand can work or larger than a heavy door takes.
  static double scaleFor(Polygon leaf) =>
      (math.min(leaf.width, leaf.height) / 900).clamp(0.55, 1.6);

  Vec2 get at => piece.at;

  bool get sideHung => hinge == OpeningEdge.left || hinge == OpeningEdge.right;

  /// Along the stile the piece is fixed to: up the leaf on a side-hung one,
  /// across it on a top or bottom hung one.
  Vec2 get alongStile => sideHung ? const Vec2(0, 1) : const Vec2(1, 0);

  /// Back across the leaf, from the stile the handle is on towards the stile
  /// it hangs on — the way a hand closes on a lever.
  Vec2 get inward => switch (hinge) {
    OpeningEdge.left => const Vec2(-1, 0),
    OpeningEdge.right => const Vec2(1, 0),
    OpeningEdge.top => const Vec2(0, -1),
    OpeningEdge.bottom => const Vec2(0, 1),
  };

  // ---------------------------------------------------------------- a lever

  /// A lever's backplate, long enough to cover a lock case.
  Polygon get leverPlate =>
      Polygon.stadium(at, alongStile, 235 * scale, 48 * scale);

  /// The rose the lever turns in.
  double get leverRose => 27 * scale;

  /// The lever's own thickness, half of it: it is round.
  double get leverRadius => 11 * scale;

  /// How far the lever reaches back across the leaf.
  double get leverReach => 108 * scale;

  // ----------------------------------------------------- a window's handle

  /// A window handle's short base, nothing like a lock's long plate.
  Polygon get handleBase =>
      Polygon.stadium(at, alongStile, 104 * scale, 30 * scale);

  /// The boss the spindle turns in.
  double get handleBoss => 15 * scale;

  /// The way the arm hangs: down a side-hung sash, and back across a top or
  /// bottom hung one.
  Vec2 get handleHangs =>
      sideHung ? const Vec2(0, 1) : Vec2(-inward.x, -inward.y);

  double get handleReach => 86 * scale;

  /// How far the arm stands out of the face at its furthest.
  double get handleStand => 26 * scale;

  /// How many pieces the arm's curve is built of.
  static const handleSteps = 7;

  /// How far along the arm is at [t], from 0 at the boss to 1 at its end:
  /// out of the face first, then over and along the leaf.
  static double handleAlong(double t) => 1 - math.cos(t * math.pi / 2);

  /// How far out of the face the arm is at [t].
  static double handleOut(double t) => math.sin(t * math.pi / 2);

  /// The arm's thickness at [t], half of it: slim at the boss, swelling
  /// towards the end a hand takes.
  double handleRadius(double t) => (7.5 + 2.6 * t) * scale;

  /// The arm's path from the boss, and its thickness at each point, for a
  /// leaf whose face is at [face]: a quarter turn out of the face and then
  /// over and along the leaf, so it leaves the boss square and finishes
  /// lying down it.
  (List<Vec3>, List<double>) handleArm(double face) {
    final path = <Vec3>[];
    final radii = <double>[];
    for (var i = 0; i <= handleSteps; i++) {
      final t = i / handleSteps;
      final outOf = handleOut(t);
      final along = handleAlong(t);
      path.add(
        Vec3(
          piece.at.x + handleHangs.x * handleReach * along,
          piece.at.y + handleHangs.y * handleReach * along,
          face + 11 * scale + handleStand * outOf,
        ),
      );
      radii.add(handleRadius(t));
    }
    return (path, radii);
  }

  // ----------------------------------------------------------------- a knob

  Polygon get knobRose =>
      Polygon.stadium(at, const Vec2(0, 1), 58 * scale, 52 * scale);

  static const knobSteps = 8;

  /// The knob's radius [t] of the way out from the rose: a stem, then a
  /// ball swelling and closing again.
  double knobRadius(double t) => t < 0.45
      ? 9 * scale
      : (9 + 17 * math.sin((t - 0.45) / 0.55 * math.pi)) * scale;

  // ------------------------------------------------------------ a lock

  Polygon get escutcheon =>
      Polygon.stadium(at, const Vec2(0, 1), 62 * scale, 48 * scale);

  Vec2 get keyholeAt => Vec2(at.x, at.y - 6 * scale);

  double get keyholeRadius => 7 * scale;

  Polygon get keyWard => Polygon.stadium(
    Vec2(at.x, at.y + 5 * scale),
    const Vec2(0, 1),
    20 * scale,
    7 * scale,
  );

  // ----------------------------------------------------------------- a hinge

  double get knuckleLength => 88 * scale;

  double get knuckleRadius => 9 * scale;

  /// The hinge's leaf, screwed to the stile.
  Polygon get hingeLeaf =>
      Polygon.stadium(at, alongStile, knuckleLength, 34 * scale);

  // ----------------------------------------------------------------- a pull

  /// A pull is centred on its stile rather than on the stile's outer edge,
  /// so it is on the panel's own material and not over the frame.
  Vec2 get pullAt => Vec2(at.x + inward.x * stile / 2, at.y);

  double get pullRadius => 12 * scale;

  double get postRadius => 8 * scale;

  /// Where each post stands, from the pull's middle.
  double get postFromMiddle => pullLength / 2 - 28 * scale;

  // --------------------------------------------------------------- outline

  /// Everything the piece covers, seen square on — the shapes the drawings
  /// draw, and the solid seen from in front.
  List<Polygon> get outline {
    switch (piece.kind) {
      case HardwareKind.lever:
        final tip = at + inward * leverReach;
        final side = inward.perpendicular * leverRadius;
        return [
          leverPlate,
          Polygon.circle(at, leverRose),
          Polygon([at + side, tip + side, tip - side, at - side]),
          Polygon.circle(tip, leverRadius),
        ];
      case HardwareKind.handle:
        // The arm is what its rings cover, seen square on.
        final (path, radii) = handleArm(0);
        return [
          handleBase,
          Polygon.circle(at, handleBoss),
          Polygon.hullOf([
            for (final ring in tubeRings(path, radii))
              for (final p in ring) Vec2(p.x, p.y),
          ]),
        ];
      case HardwareKind.knob:
        var ball = 0.0;
        for (var i = 0; i <= knobSteps; i++) {
          ball = math.max(ball, knobRadius(i / knobSteps));
        }
        return [knobRose, Polygon.circle(at, ball)];
      case HardwareKind.lock:
        return [escutcheon, Polygon.circle(keyholeAt, keyholeRadius), keyWard];
      case HardwareKind.hinge:
        final along = alongStile * (knuckleLength / 2);
        final across = alongStile.perpendicular * knuckleRadius;
        return [
          hingeLeaf,
          Polygon([
            at - along + across,
            at + along + across,
            at + along - across,
            at - along - across,
          ]),
        ];
      case HardwareKind.pull:
        final c = pullAt;
        return [
          Polygon.rect(
            c.x - pullRadius,
            c.y - pullLength / 2,
            c.x + pullRadius,
            c.y + pullLength / 2,
          ),
          for (final end in [-1.0, 1.0])
            Polygon.circle(Vec2(c.x, c.y + end * postFromMiddle), postRadius),
        ];
      default:
        return const [];
    }
  }

  /// A piece with no built form — one the user placed by hand, or a kind
  /// nothing is built for — as a plain plate at the point it was put,
  /// turned to its own angle, sized from the design.
  static Polygon plainPlate(Design design, HardwareElement piece) {
    final scale = math.max(design.widthMm, design.heightMm);
    final length = switch (piece.kind) {
      HardwareKind.lever => scale * 0.07,
      HardwareKind.handle => scale * 0.09,
      HardwareKind.letterplate => scale * 0.22,
      HardwareKind.closer => scale * 0.12,
      _ => scale * 0.035,
    }.clamp(24.0, 420.0);
    final width = (length * 0.26).clamp(14.0, 90.0);
    final along = Vec2(
      math.cos(piece.rotation * math.pi / 180),
      math.sin(piece.rotation * math.pi / 180),
    );
    final across = along.perpendicular;
    final centre = piece.at;
    return Polygon([
      centre + along * (length / 2) + across * (width / 2),
      centre + along * (length / 2) - across * (width / 2),
      centre - along * (length / 2) - across * (width / 2),
      centre - along * (length / 2) + across * (width / 2),
    ]);
  }

  /// Every shape [piece] covers seen square on, whatever it is: a frame
  /// piece's footprint, a leaf's ironmongery as it is built, or a plain
  /// plate.
  static List<Polygon> outlineOf(Design design, HardwareElement piece) {
    final footprint = OpeningHardware.footprintOf(design, piece);
    if (footprint != null) return [footprint];
    final built = Furniture.of(design, piece);
    if (built != null) return built.outline;
    return [plainPlate(design, piece)];
  }
}
