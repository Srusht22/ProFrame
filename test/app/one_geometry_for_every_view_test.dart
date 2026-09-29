import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/cad_layers.dart';
import 'package:proframe/app/canvas/cad_painter.dart';
import 'package:proframe/app/canvas/design_painter.dart';
import 'package:proframe/app/canvas/view_transform.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/hardware/opening_hardware.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_geometry.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/frame_profile.dart';
import 'package:proframe/domain/model/opening_leaf.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

import '../domain/rendering_geometry_baseline_test.dart' as base;

// Phase 2 of the CAD and 3D work: one geometry, drawn three ways.
//
//     SAVED DESIGN  →  DesignGeometry  →  the drawing, the CAD sheet, the solid
//
// Each view used to work out some of its own geometry. The solid stopped a
// bar at the frame's inner face and the drawings ran it to the outline; the
// technical drawing trimmed a glazing bar to the leaf the solid trimmed it to
// by a route of its own; and the ironmongery was sized from the leaf in the
// solid and from the whole design on both sheets, so a lever was one size in
// the model and another on the drawing. None of those is a picture of the
// same thing.
//
// So this takes designs made the way the user makes them and holds, part by
// part, that what the solid builds is exactly what `DesignGeometry` says —
// the bars' bodies, the panes, the sashes, the ironmongery — and that both
// drawings put down exactly those shapes, on the pixels.

const _size = Size(900, 700);

ViewTransform _view(Design design) => ViewTransform.fit(
  design.frame!.outline,
  _size,
  padding: const EdgeInsets.all(40),
);

/// The technical drawing, with nothing laid over the parts themselves.
Future<Uint8List> cad(Design design) async {
  final recorder = ui.PictureRecorder();
  CadPainter(
    design: design,
    view: _view(design),
    layers: const CadLayers(
      grid: false,
      dimensions: false,
      centreLines: false,
      annotations: false,
      grips: false,
    ),
  ).paint(Canvas(recorder), _size);
  return _rgba(recorder);
}

/// The drawing the user draws on.
Future<Uint8List> sheet(Design design) async {
  final recorder = ui.PictureRecorder();
  DesignPainter(
    design: design,
    view: _view(design),
  ).paint(Canvas(recorder), _size);
  return _rgba(recorder);
}

Future<Uint8List> _rgba(ui.PictureRecorder recorder) async {
  final image = await recorder.endRecording().toImage(
    _size.width.round(),
    _size.height.round(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// The box round every pixel that differs between two pictures.
Rect? changed(Uint8List a, Uint8List b) {
  final w = _size.width.round();
  double? l, t, r, bt;
  for (var i = 0; i < a.length; i += 4) {
    if (a[i] == b[i] &&
        a[i + 1] == b[i + 1] &&
        a[i + 2] == b[i + 2] &&
        a[i + 3] == b[i + 3]) {
      continue;
    }
    final x = ((i ~/ 4) % w).toDouble(), y = ((i ~/ 4) ~/ w).toDouble();
    l = l == null ? x : (x < l ? x : l);
    t = t == null ? y : (y < t ? y : t);
    r = r == null ? x : (x > r ? x : r);
    bt = bt == null ? y : (y > bt ? y : bt);
  }
  return l == null ? null : Rect.fromLTRB(l, t!, r! + 1, bt! + 1);
}

/// The box round [shapes] on the screen.
Rect onScreen(Design design, List<Polygon> shapes) {
  final view = _view(design);
  Rect? box;
  for (final shape in shapes) {
    for (final c in shape.corners) {
      final p = view.toScreen(c);
      final dot = Rect.fromLTWH(p.dx, p.dy, 0, 0);
      box = box == null ? dot : box.expandToInclude(dot);
    }
  }
  return box!;
}

String _key(double x, double y) =>
    '${x.toStringAsFixed(3)},${y.toStringAsFixed(3)}';

/// The distinct corners of [facets], seen square on.
Set<String> seenSquareOn(Iterable<Facet> facets) => {
  for (final f in facets)
    for (final c in f.corners) _key(c.x + 0, c.y + 0),
};

Set<String> cornersOf(Iterable<Polygon> shapes) => {
  for (final s in shapes)
    for (final c in s.corners) _key(c.x + 0, c.y + 0),
};

/// A window with a line drawn at a slope right across it, from the head to
/// the sill: the bar that trims differently from a square one.
Design sloping() => base.read(
  Design.empty(
    id: 'sloping',
    kind: DesignKind.window,
    name: 'Sloping',
    now: base.at,
  ),
  [
    base.pen('outline', base.rectangle(1800, 1200)),
    base.pen('slope', const [Vec2(500, -40), Vec2(1100, 1240)]),
    base.pen('mark', base.chevron(const Vec2(1400, 600))),
  ],
);

/// The baseline door with a second line inside its opening, at a slope.
Design doorWithASlopingLine() {
  final door = base.door();
  final opening = door.openings.single;
  return DesignEdits.addDividerInside(
    door,
    opening.sectionId,
    id: 'slope-inside',
    a: const Vec2(200, 300),
    b: const Vec2(800, 900),
  );
}

void main() {
  final designs = <String, Design>{
    'door': base.door(),
    'window': base.window(),
    'sliding': base.sliding(),
    'sloping window': sloping(),
    'door with a sloping line': doorWithASlopingLine(),
  };

  test('the designs are made the way the user makes them', () {
    expect(designs['sloping window']!.dividers, hasLength(1));
    final inside = designs['door with a sloping line']!.dividerById(
      'slope-inside',
    );
    expect(inside, isNotNull);
    expect(
      designs['door with a sloping line']!.openingHolding(inside!.parentId),
      isNotNull,
      reason: 'a line drawn inside an opening is that opening\'s',
    );
  });

  test('the geometry is read from the design and changes nothing in it', () {
    for (final design in designs.values) {
      final before = base.designGeometry(design);
      final geometry = DesignGeometry.of(design);
      expect(identical(geometry, DesignGeometry.of(design)), isTrue);
      for (final bar in design.dividers) {
        geometry.barBody(bar);
      }
      for (final section in design.sections) {
        geometry.fillOf(section);
        geometry.leafInner(section);
      }
      for (final piece in design.hardware) {
        geometry.hardwareOf(piece);
      }
      expect(base.designGeometry(design), before);
    }
  });

  for (final MapEntry(key: name, value: design) in designs.entries) {
    group(name, () {
      final geometry = DesignGeometry.of(design);
      final mesh = MeshBuilder.build(design);
      final sliding = design.kind == DesignKind.sliding;

      test('the solid builds every bar as the body the drawings draw', () {
        for (final bar in design.dividers) {
          final facets = mesh.facets.where(
            (f) => f.elementId == bar.id && f.role == FacetRole.bar,
          );
          // A sliding design's line between two panels is where they meet,
          // and its material is their own stiles: nothing is built for it.
          if (sliding) continue;
          final body = geometry.barBody(bar);
          expect(body.isEmpty, isFalse, reason: bar.id);
          // The body, and — where the bar is a plain four-sided member —
          // its front with the long edges eased by its material's arris,
          // which stays inside the body.
          final arris = barArrisOf(bar.finish.material, bar.widthMm);
          final eased = body.corners.length == 4
              ? body.insetEach([arris, 0, arris, 0])
              : body;
          expect(
            seenSquareOn(facets),
            cornersOf([body, eased]),
            reason: '${bar.id}: the solid and the drawings show one bar',
          );
        }
      });

      test('no bar reaches past what it is trimmed to', () {
        for (final bar in design.dividers) {
          final bounds = geometry.boundsOf(bar)!;
          for (final c in geometry.barBody(bar).corners) {
            expect(
              bounds.contains(c) || bounds.awayFrom(c) < 1e-6,
              isTrue,
              reason: '${bar.id} at $c',
            );
          }
        }
      });

      test('a line inside an opening stays inside that opening', () {
        for (final bar in design.dividers) {
          final opening = design.openingHolding(bar.parentId);
          if (opening == null) continue;
          final leaf = geometry.leafInner(
            design.sectionById(opening.sectionId)!,
          )!;
          for (final c in geometry.barBody(bar).corners) {
            expect(
              leaf.contains(c) || leaf.awayFrom(c) < 1e-6,
              isTrue,
              reason: '${bar.id} at $c is outside ${opening.id}',
            );
          }
        }
      });

      test(
        'the solid fills every pane exactly as far as the geometry says',
        () {
          for (final section in design.sections) {
            final panes = mesh.facets.where(
              (f) =>
                  f.elementId == section.id &&
                  (f.role == FacetRole.glazing || f.role == FacetRole.panel),
            );
            if (panes.isEmpty) continue;
            // A panel on a sliding track is a sash of its own, filled to its
            // own daylight; anything else is filled to what fills its region.
            expect(
              seenSquareOn(panes),
              cornersOf([
                geometry.onTrack(section)
                    ? geometry.leafInner(section)!
                    : geometry.fillOf(section),
              ]),
              reason: section.id,
            );
          }
        },
      );

      test('the solid builds every sash as the leaf the geometry gives', () {
        final leaves = {
          for (final opening in design.openings)
            design.sectionById(opening.sectionId)!,
          for (final section in design.sections)
            if (geometry.onTrack(section)) section,
        };
        if (sliding) {
          // Each panel reaches the middle of the line it meets its
          // neighbour at, so the two cover what the drawing shows.
          final panels = design.topLevelSections;
          expect(panels, hasLength(2));
          final meeting = design.dividers.single;
          for (final panel in panels) {
            final outer = geometry.leafOuter(panel);
            expect(
              (outer.left - meeting.a.x).abs() < 1e-6 ||
                  (outer.right - meeting.a.x).abs() < 1e-6,
              isTrue,
            );
          }
        }
        for (final section in leaves) {
          final sash = mesh.facets.where(
            (f) => f.elementId == section.id && f.role == FacetRole.sash,
          );
          expect(sash, isNotEmpty);
          // The sash's profile swept between the leaf's outside and its
          // daylight: every point of its section on the mitre between the
          // two, and nothing outside the one or inside the other.
          final outer = geometry.leafOuter(section);
          final inner = geometry.leafInner(section)!;
          final profile = FrameProfile.of(
            design.frame!.finish.material,
            width: OpeningLeaf.profileFor(design.frame!),
            depth: 1000,
          );
          expect(seenSquareOn(sash), {
            for (var j = 0; j < outer.corners.length; j++)
              for (final p in profile.section)
                () {
                  final o = outer.corners[j], i = inner.corners[j];
                  final t = p.across / profile.width;
                  return _key(o.x + (i.x - o.x) * t, o.y + (i.y - o.y) * t);
                }(),
          });
        }
      });

      test('the solid builds every piece of ironmongery to the size the '
          'drawings draw it', () {
        for (final piece in design.hardware) {
          if (piece.kind == HardwareKind.screen) continue;
          final facets = mesh.facets.where(
            (f) => f.elementId == piece.id && f.part != 'the other face',
          );
          expect(facets, isNotEmpty, reason: piece.id);
          final built = _box([
            for (final f in facets)
              for (final c in f.corners) Vec2(c.x, c.y),
          ]);
          final drawn = _box([
            for (final s in geometry.hardwareOf(piece)) ...s.corners,
          ]);
          expect(
            (built.left - drawn.left).abs() +
                (built.top - drawn.top).abs() +
                (built.right - drawn.right).abs() +
                (built.bottom - drawn.bottom).abs(),
            lessThan(0.05),
            reason:
                '${piece.kind.name} ${piece.id}: built $built, '
                'drawn $drawn',
          );
        }
      });

      test('the solid stands inside the frame the drawings draw', () {
        final frame = design.frame!.outline;
        final all = _box([
          for (final f in mesh.facets)
            if (f.role != FacetRole.hardware)
              for (final c in f.corners) Vec2(c.x, c.y),
        ]);
        expect(all.left, closeTo(frame.left, 1e-6));
        expect(all.top, closeTo(frame.top, 1e-6));
        expect(all.right, closeTo(frame.right, 1e-6));
        expect(all.bottom, closeTo(frame.bottom, 1e-6));
      });
    });
  }

  group('both drawings put down the same shapes', () {
    test('a bar of the design stops at the frame\'s inner face on both '
        'sheets, as it does in the solid', () async {
      for (final design in [designs['door']!, designs['window']!]) {
        final geometry = DesignGeometry.of(design);
        // The same design with every bar of it drawn only as far as the
        // frame's daylight: if the drawings draw the geometry's body, the
        // two are one picture.
        final trimmed = design.copyWith(
          dividers: [
            for (final bar in design.dividers)
              if (bar.parentId != null)
                bar
              else
                bar.copyWith(
                  a: geometry.boundsOf(bar)!.portionOf(bar.segment)!.a,
                  b: geometry.boundsOf(bar)!.portionOf(bar.segment)!.b,
                ),
          ],
        );
        expect(await cad(trimmed), await cad(design));
        expect(await sheet(trimmed), await sheet(design));
      }
    });

    test('a sloping bar meets the frame along the frame\'s face', () async {
      final design = designs['sloping window']!;
      final bar = design.dividers.single;
      final body = DesignGeometry.of(design).barBody(bar);
      final inner = design.frame!.innerOutline;
      // Both of its ends lie along the head and the sill: two corners on
      // each, and none past either.
      expect(
        body.corners.where((c) => (c.y - inner.top).abs() < 1e-6),
        hasLength(2),
      );
      expect(
        body.corners.where((c) => (c.y - inner.bottom).abs() < 1e-6),
        hasLength(2),
      );
    });

    for (final (name, kind) in [
      ('window', HardwareKind.handle),
      ('window', HardwareKind.hinge),
      ('door', HardwareKind.lever),
      ('door', HardwareKind.lock),
      ('sliding', HardwareKind.pull),
    ]) {
      test('the $name\'s ${kind.name} is drawn the size it is built, on the '
          'technical drawing and on the sheet', () async {
        final design = designs[name]!;
        final piece = design.hardware.firstWhere((p) => p.kind == kind);
        expect(design.isConcealed(piece), isFalse);
        final without = design.copyWith(
          hardware: [
            for (final p in design.hardware)
              if (p.id != piece.id) p,
          ],
        );
        final expected = onScreen(
          design,
          DesignGeometry.of(design).hardwareOf(piece),
        );
        for (final (view, paint) in [('CAD', cad), ('sheet', sheet)]) {
          final box = changed(await paint(design), await paint(without));
          expect(box, isNotNull, reason: view);
          // Within the width of the line it is drawn with.
          expect(
            (box!.left - expected.left).abs() < 3 &&
                (box.top - expected.top).abs() < 3 &&
                (box.right - expected.right).abs() < 3 &&
                (box.bottom - expected.bottom).abs() < 3,
            isTrue,
            reason: '$view drew $box where the geometry is $expected',
          );
        }
      });
    }

    test('what is built of ironmongery is what OpeningHardware placed', () {
      for (final design in designs.values) {
        for (final piece in design.hardware) {
          final shapes = DesignGeometry.of(design).hardwareOf(piece);
          expect(shapes, isNotEmpty);
          final footprint = OpeningHardware.footprintOf(design, piece);
          if (footprint != null) expect(shapes, [footprint]);
        }
      }
    });
  });

  test('no view works out a bar or a piece of ironmongery for itself', () {
    final views = [
      'lib/app/canvas/cad_painter.dart',
      'lib/app/canvas/design_painter.dart',
      'lib/domain/solid/mesh_builder.dart',
    ];
    for (final path in views) {
      final source = File(path).readAsStringSync();
      for (final forbidden in [
        'widthMm / 2',
        'clippedTo(',
        'daylightAround(',
        'Polygon.stadium(',
        'HardwareKind.lever => scale',
        '/ 900',
      ]) {
        expect(
          source.contains(forbidden),
          isFalse,
          reason:
              '$path works out "$forbidden" itself: it is '
              'DesignGeometry\'s to say',
        );
      }
    }
  });
}

Rect _box(List<Vec2> points) {
  var l = double.infinity, t = double.infinity;
  var r = -double.infinity, b = -double.infinity;
  for (final p in points) {
    if (p.x < l) l = p.x;
    if (p.y < t) t = p.y;
    if (p.x > r) r = p.x;
    if (p.y > b) b = p.y;
  }
  return Rect.fromLTRB(l, t, r, b);
}
