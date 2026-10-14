import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/geometry_feedback.dart';
import 'package:proframe/domain/recognition/geometry_validation.dart';
import 'package:proframe/domain/sketch/stroke.dart';

import 'an_angled_design_keeps_its_geometry_test.dart'
    show nonParallel, rakedWithOpening, read, slopedTop, unequal;
import 'an_under_stair_design_test.dart' as under;
import 'geometry_normalizer_test.dart' show pen;
import 'openings_inside_an_angled_design_test.dart' as gable;

// An Angled / Asymmetrical design is checked rather than squared, and what
// the check finds is now said: in words that name the part — never an id —
// with how much it matters, and the parts to show on the drawing. It is
// worked out from the design as it is, so a valid shape says nothing
// however unrectangular it is, an invalid one is never passed over, and a
// problem put right is gone. Nothing is ever mended.

const standards = [
  DesignKind.door,
  DesignKind.window,
  DesignKind.sliding,
  DesignKind.both,
];

/// A trapezoid: the head 80 cm, the foot 140, both sides sloping in.
const trapezoid = [
  Vec2(300, 0),
  Vec2(1100, 0),
  Vec2(1400, 1800),
  Vec2(0, 1800),
  Vec2(300, 0),
];

/// Every id a notice could leak, and the words of the code's own classes.
void expectWordsOnly(Design d, GeometryFeedback feedback) {
  final ids = {for (final e in d.allElements) e.id};
  for (final notice in feedback.notices) {
    for (final id in ids) {
      expect(notice.message.contains(id), isFalse, reason: notice.message);
    }
    expect(
      notice.message,
      isNot(matches(RegExp(r'Element|::|Divider|Section\b|null'))),
    );
    expect(notice.message, matches(RegExp(r'^[A-Z].*\.$')));
  }
}

GeometryFeedback feedbackOn(Design d) {
  final before = jsonEncode(d.toJson());
  final feedback = GeometryFeedback.of(d);
  expect(jsonEncode(d.toJson()), before, reason: 'checking changed it');
  expectWordsOnly(d, feedback);
  return feedback;
}

void main() {
  final good = read(rakedWithOpening()).design;

  group('a valid angled design says nothing, however unrectangular', () {
    final valid = <String, Design>{
      'a sloped top, left 200 cm and right 150': read([
        pen('outline', slopedTop),
      ]).design,
      'the sloped top with a mullion and an opening': good,
      'unequal heights and widths': read([pen('outline', unequal)]).design,
      'sides that are not parallel': read([pen('outline', nonParallel)]).design,
      'a trapezoid': read([pen('outline', trapezoid)]).design,
      'the window under a stair': under.readSheet(under.drawn()),
      'the window under a stair, drawn by hand': under.readSheet(
        under.drawn(outline: under.byHand),
      ),
      'a gable with two raked openings, divided and furnished': gable.built(),
    };
    for (final MapEntry(key: what, value: d) in valid.entries) {
      test(what, () {
        expect(d.kind, DesignKind.angled);
        expect(d.frame, isNotNull);
        expect(
          d.frame!.outline.edges.any((e) => e.a.x != e.b.x && e.a.y != e.b.y),
          isTrue,
          reason: 'not a rectangle',
        );
        final feedback = feedbackOn(d);
        expect(feedback.isEmpty, isTrue, reason: '${feedback.notices}');
      });
    }
  });

  group('an invalid angled design is never passed over', () {
    test('Example B — a sloped bar drawn connected to nothing: a warning '
        'naming it, and the bar to show', () {
      final r = read([
        ...rakedWithOpening(),
        pen('loose', const [Vec2(800, 1100), Vec2(1050, 1500)]),
      ]);
      final loose = r.design.dividers.singleWhere(
        (b) => b.fromStrokeId == 'loose',
      );
      final feedback = feedbackOn(r.design);
      expect(feedback.notices, hasLength(1));
      final notice = feedback.notices.single;
      expect(notice.severity, GeometryProblemSeverity.warning);
      expect(notice.problem.kind, GeometryProblemKind.disconnected);
      expect(
        notice.message,
        'A sloped bar is not connected to the frame or to another bar.',
      );
      expect(notice.showIds, {loose.id});
      expect(feedback.hasErrors, isFalse);
      expect(feedback.title, 'Geometry may need review');
      // The reading reported the same thing: one validator.
      expect(r.problems.map((p) => p.elementId), [loose.id]);
    });

    test('Example C — an outline drawn crossing itself: an error naming the '
        'two sides that cross, and those sides to show', () {
      final r = read([
        pen('outline', const [
          Vec2(0, 0),
          Vec2(1200, 2000),
          Vec2(1200, 0),
          Vec2(0, 2000),
          Vec2(0, 0),
        ]),
      ]);
      final feedback = feedbackOn(r.design);
      final crossing = feedback.notices.firstWhere(
        (n) => n.problem.kind == GeometryProblemKind.selfIntersection,
      );
      expect(crossing.severity, GeometryProblemSeverity.error);
      expect(feedback.hasErrors, isTrue);
      expect(feedback.title, 'Geometry needs attention');
      expect(
        crossing.message,
        anyOf(
          'Two sides of the frame cross each other.',
          matches(RegExp(r'^The .+ of the frame crosses the .+\.$')),
        ),
      );
      expect(crossing.showIds, hasLength(2));
      final sides = {for (final m in r.design.frameMembers) m.id: m};
      expect(sides.keys, containsAll(crossing.showIds));
      final [a, b] = [for (final id in crossing.showIds) sides[id]!];
      expect(a.run.crossing(b.run), isNotNull, reason: 'they do cross');
      // And nothing was straightened, deleted or closed for the user.
      expect(r.design.frame!.outline.isSimple, isFalse);
    });

    test('an opening whose mark is outside its region: a warning naming '
        'the opening', () {
      final opening = good.openings.single;
      final d = good.copyWith(
        openings: [opening.copyWith(markAt: const Vec2(1000, 1500))],
      );
      final notice = feedbackOn(d).notices.single;
      expect(notice.problem.kind, GeometryProblemKind.opening);
      expect(notice.severity, GeometryProblemSeverity.warning);
      expect(
        notice.message,
        'The mark of Opening 1 is outside the region it opens.',
      );
      expect(notice.showIds, {opening.id});
    });

    test('an opening that has lost its region: an error', () {
      final opening = good.openings.single;
      // Built by hand past the model's own rule, as an older file could
      // hold it: the opening's region is gone.
      final d = Design.fromJson({
        ...good.toJson(),
        'sections': [
          for (final s in good.sections)
            if (s.id != opening.sectionId) s.toJson(),
        ],
      });
      final notices = GeometryFeedback.of(d).notices
          .where((n) => n.problem.kind == GeometryProblemKind.opening);
      if (d.openings.isEmpty) {
        // The model refuses an opening without its region outright, so
        // there is nothing left to report — which is also not silence
        // about a problem.
        expect(notices, isEmpty);
      } else {
        expect(notices.single.isError, isTrue);
        expect(
          notices.single.message,
          'Opening 1 has lost the region it opens.',
        );
      }
    });

    test('a figure the geometry no longer agrees with: a warning saying '
        'both figures', () {
      final d = good.copyWith(
        dimensions: const [
          DimensionElement(
            id: 'left',
            a: Vec2(0, 0),
            b: Vec2(0, 2000),
            statedMm: 1500,
          ),
        ],
      );
      final notice = feedbackOn(d).notices.single;
      expect(notice.problem.kind, GeometryProblemKind.dimension);
      expect(notice.severity, GeometryProblemSeverity.warning);
      expect(
        notice.message,
        'The dimension you gave as 150 cm no longer matches the drawing, '
        'which measures 200 cm.',
      );
      expect(notice.showIds, {'left'});
    });

    test('a dimension that measures nothing', () {
      final d = good.copyWith(
        dimensions: const [
          DimensionElement(id: 'nil', a: Vec2(500, 500), b: Vec2(500, 500)),
        ],
      );
      expect(
        feedbackOn(d).notices.single.message,
        'A dimension measures nothing: its two ends are at the same point.',
      );
    });

    test('a line of the opening\'s outside it, and a hinge off its leaf', () {
      final opening = good.openings.single;
      final stray = DividerElement(
        id: 'stray',
        a: const Vec2(700, 1500),
        b: const Vec2(1100, 1500),
        parentId: opening.id,
      );
      final line = feedbackOn(
        good.copyWith(dividers: [...good.dividers, stray]),
      ).notices.firstWhere((n) => n.problem.elementId == 'stray');
      expect(
        line.message,
        'A line inside Opening 1 reaches outside Opening 1.',
      );
      expect(line.severity, GeometryProblemSeverity.warning);

      final hinge = good.hardware.firstWhere(
        (h) => h.kind == HardwareKind.hinge,
      );
      final off = feedbackOn(
        good.copyWith(
          hardware: [
            for (final h in good.hardware)
              if (h.id == hinge.id)
                h.copyWith(at: const Vec2(1100, 1500))
              else
                h,
          ],
        ),
      ).notices.single;
      expect(off.message, 'A hinge of Opening 1 is not on its leaf.');
      expect(off.showIds, {hinge.id});
    });

    test('an outline that encloses nothing, and a point that is not a '
        'number: errors, the second with nothing to show', () {
      final flat = feedbackOn(
        good.withElement(
          good.frame!.copyWith(
            outline: const Polygon([Vec2(0, 0), Vec2(100, 0)]),
          ),
        ),
      );
      final boundary = flat.notices.firstWhere(
        (n) => n.problem.kind == GeometryProblemKind.boundary,
      );
      expect(boundary.isError, isTrue);
      expect(
        boundary.message,
        'The frame\'s outline does not enclose a shape.',
      );

      final bar = good.dividers.first;
      final nan = GeometryFeedback.of(
        good.withElement(bar.copyWith(b: const Vec2(double.nan, 0))),
      ).notices.single;
      expect(nan.isError, isTrue);
      expect(
        nan.message,
        'A bar has a point that is not a number, so it '
        'cannot be placed.',
      );
      expect(nan.showIds, isEmpty);
    });

    test('errors come first, and warnings are never called errors', () {
      final opening = good.openings.single;
      final d = good.copyWith(
        dividers: [
          ...good.dividers,
          const DividerElement(
            id: 'loose',
            a: Vec2(800, 1500),
            b: Vec2(1000, 1500),
          ),
        ],
        openings: [opening.copyWith(markAt: const Vec2(1000, 1500))],
      );
      final bad = d.withElement(
        d.dividers.first.copyWith(b: const Vec2(double.infinity, 0)),
      );
      final feedback = GeometryFeedback.of(bad);
      expect(feedback.notices.first.isError, isTrue);
      final warnings = GeometryFeedback.of(d).notices;
      expect(warnings, hasLength(2));
      expect(warnings.every((n) => !n.isError), isTrue);
      expect(GeometryFeedback.of(d).title, 'Geometry may need review');
    });
  });

  group('the standard categories are not touched', () {
    for (final kind in standards) {
      test('${kind.name}: the same problems say nothing, and its reading is '
          'as it was', () {
        final r = read([
          ...rakedWithOpening(),
          pen('loose', const [Vec2(800, 1100), Vec2(1050, 1500)]),
        ], kind: kind);
        expect(r.problems, isEmpty);
        expect(GeometryFeedback.of(r.design).isEmpty, isTrue);
        expect(GeometryFeedback.of(r.design), same(GeometryFeedback.none));
      });
    }
  });

  group('put right, and the problem is gone', () {
    test('the loose bar rubbed out and the sheet read again', () {
      final strokes = [
        ...rakedWithOpening(),
        pen('loose', const [Vec2(800, 1100), Vec2(1050, 1500)]),
      ];
      final broken = read(strokes).design;
      expect(GeometryFeedback.of(broken).isNotEmpty, isTrue);
      final mended = read([
        for (final s in strokes)
          if (s.id != 'loose') s,
      ]).design;
      expect(GeometryFeedback.of(mended).isEmpty, isTrue);
    });

    test('a figure made true again, and a mark put back in its light', () {
      final stated = good.copyWith(
        dimensions: const [
          DimensionElement(
            id: 'left',
            a: Vec2(0, 0),
            b: Vec2(0, 2000),
            statedMm: 1500,
          ),
        ],
      );
      expect(GeometryFeedback.of(stated).isNotEmpty, isTrue);
      final fixed = stated.copyWith(
        dimensions: [stated.dimensions.single.copyWith(statedMm: 2000)],
      );
      expect(GeometryFeedback.of(fixed).isEmpty, isTrue);

      final opening = good.openings.single;
      final strayMark = good.copyWith(
        openings: [opening.copyWith(markAt: const Vec2(1000, 1500))],
      );
      expect(GeometryFeedback.of(strayMark).isNotEmpty, isTrue);
      final back = strayMark.copyWith(
        openings: [strayMark.openings.single.copyWith(markAt: opening.markAt)],
      );
      expect(GeometryFeedback.of(back).isEmpty, isTrue);
    });

    test('the check is the design\'s: worked out once for a design, afresh '
        'for every edit, and never written into it', () {
      expect(GeometryFeedback.of(good), same(GeometryFeedback.of(good)));
      final json = good.toJson();
      expect(jsonEncode(json).contains('problem'), isFalse);
      expect(Design.fromJson(json).kind, DesignKind.angled);
      expect(
        Sketch(strokes: good.sketch.strokes).strokes,
        hasLength(good.sketch.strokes.length),
      );
    });
  });
}
