import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/editing/cad_snap.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/segment.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/geometry_feedback.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

import 'an_under_stair_design_test.dart' as under;
import 'angled_dimensions_test.dart' as angled;
import 'geometry_normalizer_test.dart' show pen;
import 'openings_inside_an_angled_design_test.dart' as gable;

// CAD snapping that reads the geometry as it is. An angled design's slopes
// are meant, so a drag on its technical drawing snaps to its own points and
// its own lines — a raking side as much as a level head — measured square to
// each line, at whatever angle the user drew it. Nothing is forced to 45°,
// level or upright; a drag well clear of everything is left where it is; a
// line inside an opening snaps inside that opening; and the snapped edit is
// the design's, through Read, a save, the solid and an undo. The standard
// categories keep the snapping they had.

/// How far a drag reaches to snap, as the CAD view works it out: eleven
/// pixels at the drawing's scale — here, a hand's 20 mm.
const within = 20.0;

Segment slopeOf(Design d) =>
    d.frame!.outline.edges.singleWhere((e) => e.a.x != e.b.x && e.a.y != e.b.y);

/// [line]'s point at [t], pushed [off] mm off it square to it.
Vec2 nearLine(Segment line, double t, double off) =>
    line.pointAt(t) + line.unit.perpendicular * off;

/// The snapping the CAD view did for every design before this: x and y
/// snapped on their own, to the values `snapCandidates` gives.
Vec2 axisSnapped(Design d, Vec2 raw, {String? ignoreId}) => Vec2(
  DesignEdits.snapTo(
        DesignEdits.snapCandidates(d, horizontal: true, ignoreId: ignoreId),
        raw.x,
        withinMm: within,
      ) ??
      raw.x,
  DesignEdits.snapTo(
        DesignEdits.snapCandidates(d, horizontal: false, ignoreId: ignoreId),
        raw.y,
        withinMm: within,
      ) ??
      raw.y,
);

double degrees(Segment s) =>
    math.atan2(s.b.y - s.a.y, s.b.x - s.a.x) * 180 / math.pi;

/// An outline whose head slopes at [angle] degrees, 1 m across and 4 m high
/// at the left.
Design slopedAt(double angle) {
  final rise = 1000 * math.tan(angle * math.pi / 180);
  return SketchInterpreter.interpret(
    Design.empty(id: 'slope-$angle', kind: DesignKind.angled).copyWith(
      sketch: Sketch(
        strokes: [
          // A side a stroke, so the 17° turn at 73° is a corner drawn.
          pen('left', [Vec2(0, rise + 2500), const Vec2(0, 0)]),
          pen('slope', [const Vec2(0, 0), Vec2(1000, rise)]),
          pen('right', [Vec2(1000, rise), Vec2(1000, rise + 2500)]),
          pen('sill', [Vec2(1000, rise + 2500), Vec2(0, rise + 2500)]),
        ],
      ),
    ),
  ).design;
}

/// A trapezoid: the head 80 cm, the foot 140, both sides raking in.
Design trapezoid() => SketchInterpreter.interpret(
  Design.empty(id: 'trap', kind: DesignKind.angled).copyWith(
    sketch: Sketch(
      strokes: [
        pen('outline', const [
          Vec2(300, 0),
          Vec2(1100, 0),
          Vec2(1400, 1800),
          Vec2(0, 1800),
          Vec2(300, 0),
        ]),
      ],
    ),
  ),
).design;

WorkspaceController opened(Design d) {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  c.read(workspaceProvider.notifier).openDesign(d);
  return c.read(workspaceProvider.notifier);
}

DividerElement mullionOf(Design d) =>
    d.dividers.singleWhere((b) => b.fromStrokeId == 'mullion');

/// The mullion's end that meets the slope.
bool upperIsA(DividerElement bar) => bar.a.y < bar.b.y;

void main() {
  group('the original fault, reproduced', () {
    test('an end dragged near the slope: the axis snaps leave it off the '
        'slope; snapping by the geometry lands it on the slope', () {
      final d = angled.drawn();
      final slope = slopeOf(d);
      final raw = nearLine(slope, 0.73, 8);
      final mullion = mullionOf(d);

      final before = axisSnapped(d, raw, ignoreId: mullion.id);
      expect(slope.distanceTo(before), greaterThan(5), reason: 'off the slope');

      final now = CadSnap.point(
        d,
        raw,
        withinMm: within,
        ignoreId: mullion.id,
      )!;
      expect(now.kind, SnapKind.line);
      expect(slope.distanceTo(now.at), lessThan(1e-6));
      expect(now.line, slope);
    });

    test('a raked light\'s box was a snap target with no geometry at it', () {
      final d = angled.drawn();
      final raked = d.topLevelSections.firstWhere(
        (s) => s.outline.edges.any((e) => e.a.x != e.b.x && e.a.y != e.b.y),
      );
      final o = raked.outline;
      bool anywhere(Vec2 p) =>
          d.sections.any(
            (s) => s.outline.corners.any((c) => c.distanceTo(p) < 1),
          ) ||
          d.frame!.outline.corners.any((c) => c.distanceTo(p) < 1) ||
          d.frame!.innerOutline.corners.any((c) => c.distanceTo(p) < 1);
      final phantoms = [
        for (final p in [
          Vec2(o.left, o.top),
          Vec2(o.right, o.top),
          Vec2(o.left, o.bottom),
          Vec2(o.right, o.bottom),
        ])
          if (!anywhere(p)) p,
      ];
      expect(phantoms, isNotEmpty, reason: 'a box corner that is no corner');
      for (final phantom in phantoms) {
        // The axis snaps landed a drag on it…
        expect(
          axisSnapped(d, phantom + const Vec2(6, -6)).distanceTo(phantom),
          lessThan(1e-6),
        );
        // …and snapping by the geometry never offers it as a point.
        final snapped = CadSnap.point(
          d,
          phantom + const Vec2(6, -6),
          withinMm: within,
        );
        expect(snapped?.kind, isNot(SnapKind.point));
      }
    });
  });

  group('an edge is read at its own angle', () {
    for (final angle in [3.0, 17.0, 23.0, 38.0, 52.0, 73.0]) {
      test('$angle°: a point near the slope lands on it, square to it, and '
          'the slope keeps its angle', () {
        final d = slopedAt(angle);
        final slope = slopeOf(d);
        expect(degrees(slope).abs(), closeTo(angle, 0.01), reason: 'kept');
        for (final t in [0.3, 0.5, 0.7]) {
          for (final off in [-12.0, 6.0, 15.0]) {
            final raw = nearLine(slope, t, off);
            final s = CadSnap.point(d, raw, withinMm: within)!;
            expect(s.kind, SnapKind.line, reason: '$t $off');
            expect(slope.distanceTo(s.at), lessThan(1e-6));
            // Square to the slope: the snap moved only across it.
            expect(
              (s.at - raw).dot(slope.unit).abs(),
              lessThan(1e-6),
              reason: 'square to the line, not along an axis',
            );
          }
        }
      });
    }

    test('a level head and an upright jamb snap exactly as lines too', () {
      final d = angled.drawn();
      final sill = d.frame!.outline.edges.firstWhere(
        (e) => e.a.y == e.b.y && e.a.y == 2000,
      );
      final jamb = d.frame!.outline.edges.firstWhere(
        (e) => e.a.x == e.b.x && e.a.x == 1000,
      );
      final s1 = CadSnap.point(d, const Vec2(260, 2009), withinMm: within)!;
      expect(s1.at, const Vec2(260, 2000));
      expect(s1.line, sill);
      final s2 = CadSnap.point(d, const Vec2(1012, 1650), withinMm: within)!;
      expect(s2.at, const Vec2(1000, 1650));
      expect(s2.line, jamb);
    });
  });

  group('which candidate wins', () {
    test('a corner beats the lines it ends, a crossing is a corner, the '
        'nearer line beats the further', () {
      final d = angled.drawn();
      final slope = slopeOf(d);
      final corner = slope.b.x > slope.a.x ? slope.b : slope.a;
      final s = CadSnap.point(d, corner + const Vec2(-9, 6), withinMm: within)!;
      expect(s.kind, SnapKind.point);
      expect(s.at, corner);

      // The mullion meets the slope: that point is a point of the geometry.
      final mullion = mullionOf(d);
      final top = upperIsA(mullion) ? mullion.a : mullion.b;
      final t = CadSnap.point(d, top + const Vec2(7, -8), withinMm: within)!;
      expect(t.kind, SnapKind.point);
      expect(t.at.distanceTo(top), lessThan(1e-6));

      // Between the outline's slope and the daylight's, 70 mm apart:
      // whichever is nearer.
      final inner = d.frame!.innerOutline.edges.firstWhere(
        (e) => e.a.x != e.b.x && e.a.y != e.b.y,
      );
      final nearOuter = nearLine(slope, 0.8, -10);
      expect(
        slope.distanceTo(nearOuter),
        lessThan(inner.distanceTo(nearOuter)),
      );
      expect(CadSnap.point(d, nearOuter, withinMm: within)!.line, slope);
    });

    test('outside the reach, nothing snaps: the drag lands where it is', () {
      final d = slopedAt(38);
      final slope = slopeOf(d);
      final clear = nearLine(slope, 0.5, 120);
      expect(CadSnap.point(d, clear, withinMm: within), isNull);
      // Just past the reach of the slope it is not snapped onto it.
      expect(
        CadSnap.point(
          d,
          nearLine(slope, 0.5, -(within + 5)),
          withinMm: within,
        )?.line,
        isNot(slope),
      );
    });
  });

  group('a member moved square to itself', () {
    test('a raking side of the trapezoid, dragged out, lands through a '
        'corner — at its own angle, every other side where it was', () {
      final d = trapezoid();
      var snapped = 0;
      var accepted = 0;
      for (var i = 0; i < d.frame!.outline.corners.length; i++) {
        final n = d.frame!.outline.corners.length;
        final side = Segment(
          d.frame!.outline.corners[i],
          d.frame!.outline.corners[(i + 1) % n],
        );
        final normal = side.unit.perpendicular;
        // The corners of the other sides the drag could line it up with.
        final others = [
          for (final c in d.frame!.outline.corners)
            if (side.distanceTo(c) > 1) c,
        ];
        // The nearest of them across the side: the likeliest to line up.
        double across(Vec2 p) => (p - side.midpoint).dot(normal);
        final target = others.reduce(
          (a, b) => across(a).abs() < across(b).abs() ? a : b,
        );
        final want = across(target);
        final raw = side.midpoint + normal * (want + 9) + side.unit * 40;
        final s = CadSnap.across(
          d,
          side,
          raw,
          withinMm: within,
          bandMm: d.frame!.profileMm,
        );
        expect(s, isNotNull, reason: 'side $i snaps');
        snapped++;
        // Exactly the target's offset, and only across the side.
        expect(across(s!.at), closeTo(want, 1e-6));
        expect((s.at - raw).dot(side.unit).abs(), lessThan(1e-6));

        final offset = DesignEdits.frameMemberOffset(d, i, s.at);
        final moved = DesignEdits.moveFrameMember(d, i, offset);
        if (identical(moved, d) || moved.frame!.outline == d.frame!.outline) {
          continue; // the frame edit refused a move that would collapse it
        }
        accepted++;
        final now = Segment(
          moved.frame!.outline.corners[i],
          moved.frame!.outline.corners[(i + 1) % n],
        );
        expect(degrees(now), closeTo(degrees(side), 1e-6), reason: 'angle');
        // Through the corner it was lined up with: on its line, extended.
        expect(
          (target - now.a).cross(now.unit).abs(),
          lessThan(1e-6),
          reason: 'side $i through $target',
        );
      }
      expect(accepted, greaterThan(0));
      expect(snapped, d.frame!.outline.corners.length, reason: 'every side');
    });

    test('the under-stair slope dragged: it moves square to itself, keeps '
        'its angle, and the design never becomes a rectangle', () {
      final d = under.readSheet(under.drawn());
      final slope = slopeOf(d);
      final index = d.frame!.outline.edges.indexOf(slope);
      final normal = slope.unit.perpendicular;
      final raw = slope.midpoint + normal * 37;
      final s = CadSnap.across(
        d,
        slope,
        raw,
        withinMm: within,
        bandMm: d.frame!.profileMm,
      );
      final at = s?.at ?? raw;
      final moved = DesignEdits.moveFrameMember(
        d,
        index,
        DesignEdits.frameMemberOffset(d, index, at),
      );
      final now = moved.frame!.outline.edges[index];
      expect(degrees(now), closeTo(degrees(slope), 1e-6));
      expect(moved.frame!.outline.corners, hasLength(5));
      expect(
        moved.frame!.outline.edges.every(
          (e) => e.a.x == e.b.x || e.a.y == e.b.y,
        ),
        isFalse,
        reason: 'never a rectangle',
      );
    });

    test('an upright mullion in an angled design snaps across exactly as the '
        'axis snaps did: to the x of a point the design has', () {
      final d = angled.drawn();
      final mullion = mullionOf(d);
      // 30 cm across, by a corner of the transom's foot... a point at x
      // 330 is not there; the frame corner at x 0 and 1000 are too far.
      final s = CadSnap.across(
        d,
        mullion.segment,
        Vec2(mullion.a.x - 8, 900),
        withinMm: within,
        bandMm: mullion.widthMm / 2,
        ignoreId: mullion.id,
      );
      // Nothing of the design within 20 mm across: left where it is.
      expect(s, isNull);
      final inner = d.frame!.innerOutline;
      final face = inner.corners.map((c) => c.x).reduce(math.max);
      final t = CadSnap.across(
        d,
        mullion.segment,
        Vec2(face - 12, 900),
        withinMm: within,
        bandMm: mullion.widthMm / 2,
        ignoreId: mullion.id,
      )!;
      expect(t.at.x, closeTo(face, 1e-6));
      expect(t.at.y, 900, reason: 'only across');
    });
  });

  group('a child snaps inside its parent', () {
    test(
      'a line inside the raked opening snaps to the opening\'s region, '
      'never to the design\'s lines outside it, and stays the opening\'s',
      () {
        final d = gable.built();
        final o = gable.opening(d, 'one');
        final region = gable.regionOf(d, o);
        final rail = d.childDividersOf(o.sectionId).single;
        final regionSlope = region.edges.firstWhere(
          (e) => e.a.x != e.b.x && e.a.y != e.b.y,
        );
        final raw = nearLine(regionSlope, 0.5, 9);
        final s = CadSnap.point(
          d,
          raw,
          withinMm: within,
          ignoreId: rail.id,
          insideOf: o.sectionId,
        )!;
        expect(regionSlope.distanceTo(s.at), lessThan(1e-6));

        // A point just outside the region, by the frame's slope: no snap to
        // the design's own line.
        final outer = slopeOfNearest(d.frame!.outline, regionSlope);
        final out = nearLine(outer, 0.5, 2);
        final o2 = CadSnap.point(
          d,
          out,
          withinMm: 5,
          ignoreId: rail.id,
          insideOf: o.sectionId,
        );
        expect(o2?.line, isNot(outer));

        // Moving the rail's end to the snap keeps it the opening's.
        final c = opened(d);
        final end = rail.a.distanceTo(s.at) < rail.b.distanceTo(s.at);
        c.moveDividerEnd(rail.id, startEnd: end, to: s.at);
        final now = c.state.design.dividerById(rail.id)!;
        expect(c.state.design.openingHolding(now.parentId)?.id, o.id);
        expect(
          c.state.design.topLevelDividers.map((b) => b.id),
          isNot(contains(rail.id)),
        );
      },
    );
  });

  group('the snapped edit is the design\'s', () {
    test('the mullion\'s end snapped onto the slope: the 200 / 150 sides '
        'unchanged, the hierarchy and finishes intact, through Read, a '
        'save, the solid, undo and redo', () {
      final d = angled.drawn();
      final c = opened(d);
      final mullion = mullionOf(d);
      final slope = slopeOf(d);
      final raw = nearLine(slope, 0.72, 11);
      final s = CadSnap.point(d, raw, withinMm: within, ignoreId: mullion.id)!;
      final finishes = {for (final x in d.sections) x.id: x.finish};
      final heights = (
        d.frame!.outline.corners.map((p) => p.y).reduce(math.max) -
            d.frame!.outline.corners
                .where((p) => p.x == 0)
                .map((p) => p.y)
                .reduce(math.min),
        d.frame!.outline.corners.map((p) => p.y).reduce(math.max) -
            d.frame!.outline.corners
                .where((p) => p.x == 1000)
                .map((p) => p.y)
                .reduce(math.min),
      );
      expect(heights, (2000.0, 1500.0));

      c.moveDividerEnd(mullion.id, startEnd: upperIsA(mullion), to: s.at);
      final snapped = c.state.design;
      Vec2 topOf(Design x) {
        final m = x.dividerById(mullion.id) ?? mullionOf(x);
        return upperIsA(m) ? m.a : m.b;
      }

      expect(slopeOf(snapped).distanceTo(topOf(snapped)), lessThan(1e-6));
      expect(slopeOf(snapped), slope, reason: 'the slope did not move');
      expect(snapped.frame!.outline, d.frame!.outline, reason: '200 / 150');
      expect(GeometryFeedback.of(snapped).isEmpty, isTrue, reason: 'valid');
      final opening = snapped.openings.single;
      expect(snapped.childDividersOf(opening.sectionId), hasLength(1));
      for (final x in snapped.sections) {
        if (finishes[x.id] case final f?) expect(x.finish, f);
      }

      // Read.
      c.readDrawing();
      final read = c.state.design;
      expect(slopeOf(read).distanceTo(topOf(read)), lessThan(0.5));
      expect(topOf(read).distanceTo(topOf(snapped)), lessThan(0.5));
      expect(read.frame!.outline, d.frame!.outline);
      expect(
        read.childDividersOf(read.openings.single.sectionId),
        hasLength(1),
      );

      // Saved and opened again.
      final back = Design.fromJson(
        jsonDecode(jsonEncode(read.toJson())) as Map<String, Object?>,
      );
      expect(jsonEncode(back.toJson()), jsonEncode(read.toJson()));

      // The solid is built from it: the mullion's facets reach the slope.
      final mesh = MeshBuilder.build(read);
      final bar = read.dividerById(mullion.id) ?? mullionOf(read);
      final barTop = [
        for (final f in mesh.facets)
          if (f.elementId == bar.id)
            for (final p in f.corners) p.y,
      ].reduce(math.min);
      // Up to the frame's daylight under the slope, and never above it.
      expect(barTop, greaterThan(topOf(read).y - 1));
      expect(
        barTop,
        lessThan(topOf(read).y + read.frame!.profileMm * 1.5),
        reason: 'up to the slope',
      );

      // Undo and redo.
      c.undo(); // the Read
      c.undo(); // the snap
      expect(topOf(c.state.design), upperIsA(mullion) ? mullion.a : mullion.b);
      c.redo();
      expect(topOf(c.state.design).distanceTo(s.at), lessThan(1e-6));
    });
  });

  group('drawn by hand, snapped, read again', () {
    test('the under-stair mullion\'s end, drawn to the corner by hand, '
        'snapped half way down the slope: Read builds it on the slope, not '
        'where the hand\'s ink stopped', () {
      final d = under.readSheet(under.drawn(outline: under.byHand));
      final c = opened(d);
      final slope = slopeOf(d);
      final bar = d.topLevelDividers.single;
      final s = CadSnap.point(
        d,
        slope.pointAt(0.5) - slope.unit.perpendicular * 10,
        withinMm: within,
        ignoreId: bar.id,
      )!;
      expect(s.kind, SnapKind.line);
      c.moveDividerEnd(bar.id, startEnd: upperIsA(bar), to: s.at);
      c.readDrawing();
      final read = c.state.design;
      final now = read.dividerById(bar.id)!;
      expect(slope.distanceTo(upperIsA(now) ? now.a : now.b), lessThan(1e-6));
      expect((upperIsA(now) ? now.a : now.b).distanceTo(s.at), lessThan(1e-6));
      expect(GeometryFeedback.of(read).isEmpty, isTrue, reason: 'connected');
      expect(read.frame!.outline.corners, hasLength(5));
    });
  });

  group('the standard categories keep their snapping', () {
    for (final kind in [
      DesignKind.door,
      DesignKind.window,
      DesignKind.sliding,
      DesignKind.both,
    ]) {
      test('${kind.name}: snapped by the axes, as before', () {
        expect(CadSnap.byGeometry(Design.empty(id: 'd', kind: kind)), isFalse);
      });
    }
    test('and the angled one by its geometry', () {
      expect(
        CadSnap.byGeometry(Design.empty(id: 'a', kind: DesignKind.angled)),
        isTrue,
      );
    });
  });
}

/// The edge of [outline] nearest to and parallel with [like].
Segment slopeOfNearest(Polygon outline, Segment like) => outline.edges
    .where((e) => e.unit.cross(like.unit).abs() < 0.05)
    .reduce(
      (a, b) =>
          a.distanceTo(like.midpoint) < b.distanceTo(like.midpoint) ? a : b,
    );
