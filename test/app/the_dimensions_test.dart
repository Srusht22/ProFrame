import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/cad_layers.dart';
import 'package:proframe/app/canvas/dimension_handles.dart';
import 'package:proframe/app/canvas/dimension_layout.dart';
import 'package:proframe/app/canvas/view_transform.dart';
import 'package:proframe/domain/dimensions/dimension_chain.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';

import '../domain/many_openings_in_one_design_test.dart' as many;
import '../domain/rendering_geometry_baseline_test.dart' as base;
import '../mixed_door_and_window_test.dart' as mixed;

// Phase 14 of the CAD and 3D work: the dimensions on the technical drawing.
//
// **Each kind of figure has its side**, as an elevation is dimensioned:
//
// | Side | Nearest the drawing | Beyond it |
// | --- | --- | --- |
// | Foot | the main divisions across (DAYLIGHT) | the overall width |
// | Left | the main divisions down (DAYLIGHT) | the overall height |
// | Head | what each divided part is divided into, across (DIVISION) | each opening's width |
// | Right | what each divided part is divided into, down (DIVISION) | each opening's height |
//
// **Every figure is a section that is there**, measured: the frame, a main
// division, an opening's own region, a pane a line made. Nothing is worked
// out that the design does not have, and a measurement is written once — a
// part whose runs are exactly another's says nothing new down the side.
//
// **Readable at any size**: every figure centimetres to the millimetre, one
// format across the drawing; no two figures and no row's name overlapping,
// on a laptop's sheet or a phone's; a figure too long for its run stands
// just past it, with the dimension line carried on to it; and every figure
// outside the drawing, never on it.

ViewTransform _view(Design d, Size size) => ViewTransform.fit(
  d.frame!.outline,
  size,
  marginFraction: 0.06,
  padding:
      const EdgeInsets.only(left: 118, right: 70, top: 20, bottom: 150) +
      DimensionLayout.roomFor(d, rightToo: size.width >= 600),
);

/// The layout as the painter lays it out on a sheet [size] across.
DimensionLayout _on(Design d, Size size) =>
    DimensionLayout.of(d, _view(d, size), canvas: size);

const _laptop = Size(1280, 760);
const _phone = Size(390, 620);

/// A window with two lights a hand's width wide beside a wide one, and a
/// mark in the wide one — figures far longer than the runs they measure.
Design _narrow() => base.read(
  Design.empty(
    id: 'narrow',
    kind: DesignKind.window,
    name: 'Narrow',
    now: base.at,
  ),
  [
    base.pen('outline', base.rectangle(2400, 1500)),
    base.pen('a', const [Vec2(160, 0), Vec2(160, 1500)]),
    base.pen('b', const [Vec2(320, 0), Vec2(320, 1500)]),
    base.pen('mark', base.chevron(const Vec2(1300, 750))),
  ],
);

/// [_narrow], for looking at.
Design narrowForRender() => _narrow();

/// Whether [f] is staggered: joined to its run by a leader from the run's
/// middle, square to the line.
bool _lifted(PlacedFigure f) =>
    f.leader != null && f.leader!.$1 == (f.from + f.to) / 2;

Map<String, Design> _designs() => {
  'door': base.door(),
  'window': base.window(),
  'sliding': base.sliding(),
  'three openings': many.fittedOut(),
  'door and window': mixed.theScreen(),
  'narrow lights': _narrow(),
};

void main() {
  final designs = _designs();

  group('each kind of figure has its side', () {
    test('a divided door: divisions and overall along the foot and down the '
        'left; the opening\'s divisions and the opening along the head and '
        'down the right', () {
      final d = designs['door']!;
      final chains = DimensionChains.of(d);
      ChainRunOf only(DimensionChain c) {
        final kinds = {for (final r in c.runs) r.of};
        expect(kinds, hasLength(1), reason: '$kinds on one row');
        return kinds.single;
      }

      final bySide = <DimensionSide, List<(int, ChainRunOf)>>{};
      for (final c in chains) {
        (bySide[c.side] ??= []).add((c.row, only(c)));
      }
      for (final rows in bySide.values) {
        rows.sort((a, b) => a.$1.compareTo(b.$1));
      }
      expect(bySide[DimensionSide.bottom], [
        (0, ChainRunOf.daylight),
        (1, ChainRunOf.overall),
      ]);
      expect(bySide[DimensionSide.left], [(0, ChainRunOf.overall)]);
      expect(bySide[DimensionSide.top], [(0, ChainRunOf.opening)]);
      expect(bySide[DimensionSide.right], [
        (0, ChainRunOf.division),
        (1, ChainRunOf.opening),
      ]);
    });

    test('a design with nothing open and nothing divided keeps to the foot '
        'and the left', () {
      final d = base.read(
        Design.empty(
          id: 'plain',
          kind: DesignKind.window,
          name: 'Plain',
          now: base.at,
        ),
        [
          base.pen('outline', base.rectangle(1800, 1200)),
          base.pen('m', const [Vec2(900, 0), Vec2(900, 1200)]),
        ],
      );
      for (final c in DimensionChains.of(d)) {
        expect(c.side, isIn([DimensionSide.bottom, DimensionSide.left]));
      }
    });

    test('a measurement is written once: openings side by side at one '
        'height are one height down the right', () {
      final d = designs['three openings']!;
      final right = DimensionChains.of(d)
          .where((c) => c.side == DimensionSide.right);
      expect(
        right.where((c) => c.runs.first.of == ChainRunOf.opening),
        hasLength(1),
      );
      expect(
        right.where((c) => c.runs.first.of == ChainRunOf.division),
        hasLength(1),
      );
      // Across the head each opening has its own width, all on one row.
      final top = DimensionChains.of(d).where(
        (c) =>
            c.side == DimensionSide.top &&
            c.runs.first.of == ChainRunOf.opening,
      );
      expect(top.single.runs, hasLength(d.openings.length));
    });

    test('no two runs on one row measure overlapping lengths', () {
      for (final MapEntry(key: name, value: d) in designs.entries) {
        for (final c in DimensionChains.of(d)) {
          final runs = [...c.runs]
            ..sort((a, b) => a.fromMm.compareTo(b.fromMm));
          for (var i = 1; i < runs.length; i++) {
            expect(
              runs[i].fromMm,
              greaterThanOrEqualTo(runs[i - 1].toMm - 1),
              reason: '$name ${c.side} row ${c.row}',
            );
          }
        }
      }
    });
  });

  group('every figure is geometry that is there', () {
    test('each run measures exactly the section it names, or the frame', () {
      for (final MapEntry(key: name, value: d) in designs.entries) {
        final outline = d.frame!.outline;
        for (final c in DimensionChains.of(d)) {
          final across = c.axis == DimensionAxis.horizontal;
          for (final run in c.runs) {
            if (run.of == ChainRunOf.side) {
              expect(run.sideKey, isNotNull, reason: name);
              continue;
            }
            final box = run.of == ChainRunOf.overall
                ? outline
                : d.sectionById(run.sectionId!)!.outline;
            expect(run.fromMm, across ? box.left : box.top, reason: name);
            expect(run.toMm, across ? box.right : box.bottom, reason: name);
            switch (run.of) {
              case ChainRunOf.overall:
                expect(run.sectionId, isNull);
              case ChainRunOf.daylight:
                expect(d.sectionById(run.sectionId!)!.parentId, isNull);
              case ChainRunOf.opening:
                expect(d.openingOf(run.sectionId!), isNotNull, reason: name);
              case ChainRunOf.division:
                expect(d.sectionById(run.sectionId!)!.parentId, isNotNull);
              case ChainRunOf.side:
                break;
            }
          }
        }
      }
    });

    test('every figure is written in centimetres, to the millimetre', () {
      final written = RegExp(r'^(\d+\.\d|\?) cm$');
      for (final d in designs.values) {
        for (final f in DimensionLayout.of(d, _view(d, _laptop)).figures) {
          expect(written.hasMatch(f.text), isTrue, reason: f.text);
          if (f.known) {
            expect(
              double.parse(f.text.split(' ').first) * 10,
              closeTo(f.run.valueMm, 0.5 + 1e-9),
              reason: 'the figure is the run, to the millimetre',
            );
          }
        }
      }
    });

    test('a line drawn in one part rewrites no other part\'s figure', () {
      final d = designs['door']!;
      final before = {
        for (final f in DimensionLayout.of(d, _view(d, _laptop)).figures)
          if (f.run.of != ChainRunOf.division)
            '${f.chain.side}|${f.run.sectionId}': f.text,
      };
      // A second line across the fixed light.
      final light = d.topLevelSections.firstWhere(
        (s) => d.openingOf(s.id) == null,
      );
      final edited = base.read(d, [
        ...d.sketch.strokes,
        base.pen('another', [
          Vec2(light.outline.left + 20, 800),
          Vec2(light.outline.right - 20, 800),
        ]),
      ]);
      final after = {
        for (final f in DimensionLayout.of(edited, _view(d, _laptop)).figures)
          '${f.chain.side}|${f.run.sectionId}': f.text,
      };
      for (final MapEntry(:key, :value) in before.entries) {
        if (after.containsKey(key)) expect(after[key], value, reason: key);
      }
    });
  });

  group('readable', () {
    for (final (screen, size) in [('laptop', _laptop), ('phone', _phone)]) {
      test('on a $screen: no two figures or names overlap, and none is on '
          'the drawing', () {
        for (final MapEntry(key: name, value: d) in designs.entries) {
          final view = _view(d, size);
          final layout = _on(d, size);
          final words = [
            for (final f in layout.figures) (f.text, f.rect),
            for (final n in layout.names) (n.text, n.rect),
          ];
          for (var i = 0; i < words.length; i++) {
            for (var j = i + 1; j < words.length; j++) {
              expect(
                words[i].$2.deflate(0.5).overlaps(words[j].$2.deflate(0.5)),
                isFalse,
                reason:
                    '$name: ${words[i].$1} ${words[i].$2} and '
                    '${words[j].$1} ${words[j].$2}',
              );
            }
          }
          final drawing = Rect.fromPoints(
            view.toScreen(d.frame!.outline.topLeft),
            view.toScreen(
              Vec2(d.frame!.outline.right, d.frame!.outline.bottom),
            ),
          );
          for (final (text, rect) in words) {
            expect(rect.overlaps(drawing), isFalse, reason: '$name: $text');
          }
        }
      });
    }

    test('a figure too long for its run stands past it, on its line carried '
        'on to it', () {
      final d = designs['narrow lights']!;
      final layout = _on(d, _laptop);
      expect(layout.figures.where(_lifted), isNotEmpty, reason: 'staggered');
      final led = layout.figures.where((f) => f.leader != null).toList();
      expect(led, isNotEmpty);
      for (final f in led) {
        final (from, to) = f.leader!;
        final across = f.chain.axis == DimensionAxis.horizontal;
        final run = Rect.fromPoints(f.from, f.to);
        if (_lifted(f)) {
          // Staggered: over the middle of its own run, a line further off,
          // joined to that middle square to the line.
          expect(from, (f.from + f.to) / 2);
          expect(across ? to.dx : to.dy, across ? from.dx : from.dy);
          expect(
            f.rect.contains(to) || f.rect.inflate(0.5).contains(to),
            isTrue,
          );
          continue;
        }
        // Beside it: from one end of the run, along its own line, to the
        // figure's side — and the figure past the run, not over it.
        expect(from == f.to || from == f.from, isTrue);
        if (across) {
          expect(to.dy, closeTo(f.to.dy, 1e-9));
        } else {
          expect(to.dx, closeTo(f.to.dx, 1e-9));
        }
        expect(
          across
              ? f.rect.left > run.right || f.rect.right < run.left
              : f.rect.top > run.bottom || f.rect.bottom < run.top,
          isTrue,
        );
      }
    });

    test('every figure is over its own run or just beside it — never '
        'alongside another run of its row — and on the sheet', () {
      for (final (screen, size) in [('laptop', _laptop), ('phone', _phone)]) {
        for (final MapEntry(key: name, value: d) in designs.entries) {
          for (final f in _on(d, size).figures) {
            final across = f.chain.axis == DimensionAxis.horizontal;
            double along(Offset o) => across ? o.dx : o.dy;
            final lo = along(f.from), hi = along(f.to);
            final (start, end) = across
                ? (f.rect.left, f.rect.right)
                : (f.rect.top, f.rect.bottom);
            final length = end - start;
            final gap = [
              0.0,
              start - hi,
              lo - end,
            ].reduce((a, b) => a > b ? a : b);
            expect(
              gap,
              lessThanOrEqualTo(length < 24 ? 24 : length),
              reason: '$screen $name ${f.text}',
            );
            for (final other in f.chain.runs) {
              if (identical(other, f.run)) continue;
              final o = [
                for (final p in f.chain.runs)
                  if (identical(p, other)) p,
              ].single;
              final placedOther = _on(
                d,
                size,
              ).figures.where((g) => identical(g.run, o));
              if (placedOther.isEmpty) continue;
              final g = placedOther.single;
              final (p, q) = (along(g.from), along(g.to));
              expect(
                start < q - 1 && end > p + 1,
                isFalse,
                reason: '$screen $name ${f.text} beside another run',
              );
            }
            expect(
              (Offset.zero & size).contains(f.rect.topLeft) &&
                  (Offset.zero & size).contains(f.rect.bottomRight),
              isTrue,
              reason: '$screen $name ${f.text} on the sheet',
            );
          }
        }
      }
    });

    test('looked at small, fewer rows — the overall size always — and '
        'nothing a phone writes that a laptop does not', () {
      for (final MapEntry(key: name, value: d) in designs.entries) {
        final phone = _on(d, _phone);
        final laptop = _on(d, _laptop);
        for (final of in [ChainRunOf.overall]) {
          expect(
            phone.figures.where((f) => f.run.of == of),
            hasLength(2),
            reason: '$name: the overall width and height',
          );
        }
        final onLaptop = {
          for (final f in laptop.figures)
            '${f.chain.side}|${f.run.fromMm}|${f.run.toMm}',
        };
        for (final f in phone.figures) {
          expect(
            onLaptop,
            contains('${f.chain.side}|${f.run.fromMm}|${f.run.toMm}'),
            reason: '$name ${f.text}',
          );
        }
        expect(
          laptop.figures.length,
          greaterThanOrEqualTo(phone.figures.length),
        );
      }
      // And a laptop writes every row there is on these designs.
      for (final MapEntry(key: name, value: d) in designs.entries) {
        final rows = {
          for (final c in DimensionChains.of(d)) '${c.side}|${c.row}',
        };
        final written = {
          for (final f in _on(d, _laptop).figures)
            '${f.chain.side}|${f.chain.row}',
        };
        expect(written, rows, reason: name);
      }
    });

    test('every figure can be tapped where it is written, and names what it '
        'measures', () {
      for (final d in designs.values) {
        final view = _view(d, _laptop);
        final handles = CadDimensions.of(d, view, const CadLayers());
        for (final f in DimensionLayout.of(d, view).figures) {
          final hit = CadDimensions.at(handles, f.figure);
          expect(hit, isNotNull, reason: f.text);
          expect(hit!.valueMm, f.run.valueMm);
          final what = switch (f.run.of) {
            ChainRunOf.overall => 'Overall',
            ChainRunOf.daylight => 'Daylight',
            ChainRunOf.opening => 'Opening',
            ChainRunOf.division => 'Division',
            ChainRunOf.side => f.run.sideLabel!,
          };
          expect(hit.label, startsWith(what));
        }
      }
    });
  });

  test('reading the dimensions changes nothing in the design', () {
    for (final d in designs.values) {
      final before = d.toJson().toString();
      DimensionLayout.of(d, _view(d, _phone));
      CadDimensions.of(d, _view(d, _phone), const CadLayers());
      expect(d.toJson().toString(), before);
    }
  });
}
