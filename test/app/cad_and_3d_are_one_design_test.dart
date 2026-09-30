import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/cad_layers.dart';
import 'package:proframe/app/canvas/cad_painter.dart';
import 'package:proframe/app/canvas/cad_style.dart';
import 'package:proframe/app/canvas/design_painter.dart';
import 'package:proframe/app/canvas/view_transform.dart';
import 'package:proframe/app/theme/app_theme.dart';
import 'package:proframe/app/viewer/model_painter.dart';
import 'package:proframe/app/viewer/view_mode.dart';
import 'package:proframe/domain/dimensions/measurements.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_geometry.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/infill.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/sections/section_builder.dart';
import 'package:proframe/domain/solid/camera.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

import '../domain/many_openings_in_one_design_test.dart' as many;
import '../mixed_door_and_window_test.dart' as mixed;

// Phase 16 of the CAD and 3D work: the drawing, the technical drawing and the
// solid are one design.
//
// The three may look nothing alike — a sheet of finishes, a drafted
// elevation, a lit solid — but where each part is, and what it is made of,
// is one fact about the design and the three views have to say it the same
// way: the width and the height, where every opening stands and how big it
// is, every divider inside an opening, which pane is glass and which is
// panel, and where the handles and hinges are.
//
// Each view is measured on what it actually puts down, never on what it was
// asked to: the solid by its facets, and each drawing by its pixels — where
// a part is drawn is exactly the pixels that change when that one part is
// left out of the picture. Those three measurements are then required to be
// one another's, and the design's.
//
// Then the rules about change. An edit to the geometry reaches every view,
// and so does a change of material — including the solid's own painter,
// which decided whether to paint again by comparing the first face and the
// number of faces alone, so a pane made a different colour, or a handle
// moved, kept the old picture on the screen. Turning the camera or changing
// how the model or the drawing is shown changes no geometry at all.

const _size = Size(1100, 700);

ViewTransform _view(Design d) => ViewTransform.fit(
  d.frame!.outline,
  _size,
  padding: const EdgeInsets.all(40),
);

/// The technical drawing with nothing but the parts on it.
const _bare = CadLayers(
  grid: false,
  dimensions: false,
  centreLines: false,
  annotations: false,
  grips: false,
  openings: false,
);

Future<Uint8List> _raster(void Function(Canvas) paint) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final image = await recorder.endRecording().toImage(
    _size.width.round(),
    _size.height.round(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// The technical drawing of [d], drawn at [view] (the design's own framing
/// unless another is given, so two designs can be compared pixel for pixel).
Future<Uint8List> _cad(
  Design d, {
  ViewTransform? view,
  CadLayers layers = _bare,
  CadColours ink = Cad.paper,
}) => _raster(
  (canvas) => CadPainter(
    design: d,
    view: view ?? _view(d),
    layers: layers,
    ink: ink,
  ).paint(canvas, _size),
);

/// The drawing the user draws on, the design's geometry without its ink.
Future<Uint8List> _sheet(
  Design d, {
  ViewTransform? view,
  Palette palette = Palette.light,
}) => _raster(
  (canvas) => DesignPainter(
    design: d,
    view: view ?? _view(d),
    showSketch: false,
    palette: palette,
  ).paint(canvas, _size),
);

typedef _View = Future<Uint8List> Function(Design d, ViewTransform view);

final Map<String, _View> _drawings = {
  'the technical drawing': (d, v) => _cad(d, view: v),
  'the drawing': (d, v) => _sheet(d, view: v),
};

/// The box round the pixels that differ between [a] and [b], or null.
Rect? _changed(Uint8List a, Uint8List b) {
  final w = _size.width.round();
  var l = double.infinity, t = double.infinity;
  var r = -double.infinity, btm = -double.infinity;
  for (var i = 0; i < a.length; i += 4) {
    if (a[i] == b[i] &&
        a[i + 1] == b[i + 1] &&
        a[i + 2] == b[i + 2] &&
        a[i + 3] == b[i + 3]) {
      continue;
    }
    final x = ((i ~/ 4) % w).toDouble(), y = ((i ~/ 4) ~/ w).toDouble();
    l = math.min(l, x);
    t = math.min(t, y);
    r = math.max(r, x + 1);
    btm = math.max(btm, y + 1);
  }
  return l.isFinite ? Rect.fromLTRB(l, t, r, btm) : null;
}

/// The box round everything drawn: every pixel that is not the corner's.
Rect _inked(Uint8List rgba) {
  final blank = Uint8List(rgba.length);
  for (var i = 0; i < rgba.length; i += 4) {
    for (var k = 0; k < 4; k++) {
      blank[i + k] = rgba[k];
    }
  }
  return _changed(blank, rgba)!;
}

/// The box round [points] in millimetres.
Rect _box(Iterable<Vec2> points) {
  var l = double.infinity, t = double.infinity;
  var r = -double.infinity, b = -double.infinity;
  for (final p in points) {
    l = math.min(l, p.x);
    t = math.min(t, p.y);
    r = math.max(r, p.x);
    b = math.max(b, p.y);
  }
  return Rect.fromLTRB(l, t, r, b);
}

/// [mm] on the screen [view] draws it on.
Rect _onScreen(Rect mm, ViewTransform view) => Rect.fromPoints(
  view.toScreen(Vec2(mm.left, mm.top)),
  view.toScreen(Vec2(mm.right, mm.bottom)),
);

/// Where the solid puts [facets], across and down the face.
Rect _built(Iterable<Facet> facets) => _box([
  for (final f in facets)
    for (final c in f.corners) Vec2(c.x, c.y),
]);

/// The box round [shape] in millimetres.
Rect _bounds(Polygon shape) => _box(shape.corners);

/// How far apart two boxes are, side by side: the worst of the four.
double _apart(Rect a, Rect b) => [
  (a.left - b.left).abs(),
  (a.top - b.top).abs(),
  (a.right - b.right).abs(),
  (a.bottom - b.bottom).abs(),
].reduce(math.max);

/// A drawn line has a width and an antialiased edge: this many pixels, and
/// no more, either side of where the geometry says.
const _pixels = 2.5;

List<int> _px(Uint8List rgba, Offset p) {
  final i = (p.dy.round() * _size.width.round() + p.dx.round()) * 4;
  return [rgba[i], rgba[i + 1], rgba[i + 2], rgba[i + 3]];
}

int _apartColour(List<int> a, int argb) => [
  (a[0] - (argb >> 16 & 0xFF)).abs(),
  (a[1] - (argb >> 8 & 0xFF)).abs(),
  (a[2] - (argb & 0xFF)).abs(),
].reduce(math.max);

/// Every pane: a main division nobody drew inside, or a pane somebody did.
List<SectionElement> _panes(Design d) => [
  for (final s in d.sections)
    if (d.childSectionsOf(s.id).isEmpty) s,
];

String _json(Design d) => jsonEncode(d.toJson());

String _facet(Facet f) => [
  f.elementId,
  f.role.name,
  f.part,
  f.colour,
  f.surface.id,
  for (final c in f.corners)
    '${c.x.toStringAsFixed(4)},${c.y.toStringAsFixed(4)},'
        '${c.z.toStringAsFixed(4)}',
].join('|');

List<String> _mesh(Mesh m) => [for (final f in m.facets) _facet(f)];

/// The designs the phase names, each with a frame, several openings, glass,
/// panel, a divider inside every opening, handles and hinges.
final Map<String, Design Function()> _designs = {
  // Three windows under a fixed head, each glass over a brown panel.
  'three windows': many.fittedOut,
  // A window and a door between fixed lights, each glass over panel.
  'a window and a door': mixed.theScreen,
  // The first, after a mullion has been dragged and the whole made wider
  // the way the user does it, by typing the width: the views must follow
  // the geometry wherever the edits put it.
  'three windows, edited': () {
    var d = many.fittedOut();
    final mullion = d.topLevelDividers.firstWhere((b) => b.isVertical);
    d = DesignEdits.moveDivider(d, mullion.id, const Vec2(-260, 0));
    return Measurements.apply(d, {
      Measurements.widthKey: d.frame!.outline.width + 600,
    }).design;
  },
  // A line in an opening and a line in the fixed head, each stopping short
  // of the far side, so each divides nothing: still lines the user drew,
  // in every view. The solid used to leave them out.
  'lines that divide nothing': () {
    final d = many.drawn();
    final head = d.topLevelSections.firstWhere(
      (s) => d.openingOf(s.id) == null,
    );
    final opening = d.openingsInOrder.last;
    final light = d.sectionById(opening.sectionId)!.outline;
    final bar = d.dividers.first;
    return SectionBuilder.rebuild(
      d.copyWith(
        dividers: [
          ...d.dividers,
          DividerElement(
            id: 'short-in-the-opening',
            parentId: opening.id,
            widthMm: bar.widthMm,
            finish: bar.finish,
            a: Vec2(light.left, light.top + light.height * 0.4),
            b: Vec2(
              light.left + light.width * 0.6,
              light.top + light.height * 0.4,
            ),
          ),
          DividerElement(
            id: 'short-in-the-head',
            parentId: head.id,
            widthMm: bar.widthMm,
            finish: bar.finish,
            a: Vec2(
              head.outline.left + head.outline.width * 0.3,
              head.outline.top + head.outline.height / 2,
            ),
            b: Vec2(
              head.outline.left + head.outline.width * 0.6,
              head.outline.top + head.outline.height / 2,
            ),
          ),
        ],
      ),
    );
  },
};

void main() {
  for (final MapEntry(key: name, value: make) in _designs.entries) {
    group('$name: every view is the same design', () {
      final d = make();
      final view = _view(d);
      final mesh = MeshBuilder.build(d);
      final geometry = DesignGeometry.of(d);

      test('it has everything the phase names', () {
        if (name == 'lines that divide nothing') {
          // Nothing divided: each line lies in its one pane, and stays.
          expect(d.dividerById('short-in-the-opening'), isNotNull);
          expect(d.dividerById('short-in-the-head'), isNotNull);
          expect(
            d.sections.where((s) => d.sectionHolding(s.parentId) != null),
            isEmpty,
          );
          return;
        }
        expect(d.frame, isNotNull);
        expect(d.openings.length, greaterThanOrEqualTo(2));
        final inside = [
          for (final b in d.dividers)
            if (d.openingHolding(b.parentId) != null) b,
        ];
        expect(
          inside.length,
          d.openings.length,
          reason: 'a divider inside every opening',
        );
        final panes = _panes(d);
        expect(panes.any((p) => p.finish.material.isGlazing), isTrue);
        expect(panes.any((p) => !p.finish.material.isGlazing), isTrue);
        expect(d.hardware.any((h) => h.kind == HardwareKind.hinge), isTrue);
        expect(d.hardware.any((h) => h.kind.isHandle), isTrue);
      });

      test('the width and the height', () async {
        final outline = _bounds(d.frame!.outline);
        expect(
          _apart(
            _built(mesh.facets.where((f) => f.role != FacetRole.hardware)),
            outline,
          ),
          lessThan(1e-6),
          reason: 'the solid',
        );
        final expected = _onScreen(outline, view);
        for (final MapEntry(key: drawing, value: draw) in _drawings.entries) {
          final drawn = _inked(await draw(d, view));
          expect(
            _apart(drawn, expected),
            lessThan(_pixels),
            reason: '$drawing: drawn $drawn, the design $expected',
          );
        }
      });

      test('where every opening stands, and how big it is', () async {
        for (final opening in d.openings) {
          final region = _bounds(d.sectionById(opening.sectionId)!.outline);
          // The solid: the leaf's sash is the region, to the millimetre.
          final sash = mesh.facets.where(
            (f) => f.elementId == opening.sectionId && f.role == FacetRole.sash,
          );
          expect(
            _apart(_built(sash), region),
            lessThan(1e-6),
            reason: '${d.nameOf(opening)} in the solid',
          );

          // Each drawing: what it draws for the opening is the region.
          // Leaving an opening out cannot change which face the drawing is
          // of, or it would move every hinge in the design as well.
          // What it draws for the opening is its leaf and the leaf's
          // ironmongery — a hinge's knuckle stands proud of the leaf's edge,
          // so it is left out with the opening and counted with it.
          final own = [
            for (final h in d.hardware)
              if (d.openingHolding(h.parentId) == opening) h,
          ];
          final without = d.copyWith(
            openings: [
              for (final o in d.openings)
                if (o != opening) o,
            ],
            hardware: [
              for (final h in d.hardware)
                if (!own.contains(h)) h,
            ],
          );
          if (without.seenFrom != d.seenFrom) continue;
          final expected = _onScreen(
            _box([
              ...d.sectionById(opening.sectionId)!.outline.corners,
              for (final h in own)
                if (!d.isConcealed(h))
                  for (final shape in geometry.hardwareOf(h)) ...shape.corners,
            ]),
            view,
          );
          for (final MapEntry(key: drawing, value: draw) in _drawings.entries) {
            final drawn = _changed(
              await draw(d, view),
              await draw(without, view),
            );
            expect(drawn, isNotNull, reason: '$drawing draws nothing');
            expect(
              _apart(drawn!, expected),
              lessThan(_pixels),
              reason:
                  '${d.nameOf(opening)} on $drawing: '
                  'drawn $drawn, the design $expected',
            );
          }
        }
      });

      test('every divider inside an opening, or inside a light', () async {
        for (final bar in d.dividers) {
          final holder = d.sectionHolding(bar.parentId);
          if (holder == null) continue;
          final body = _bounds(geometry.barBody(bar));
          final region = _bounds(d.sectionById(holder)!.outline);
          // Inside what holds it, and never a bar of the design.
          expect(
            region.inflate(0.5).contains(body.topLeft) &&
                region.inflate(0.5).contains(body.bottomRight),
            isTrue,
          );
          expect(d.topLevelDividers, isNot(contains(bar)));

          expect(
            _apart(
              _built(mesh.facets.where((f) => f.elementId == bar.id)),
              body,
            ),
            lessThan(1e-6),
            reason: '${bar.id} in the solid',
          );
          final without = d.copyWith(
            dividers: [
              for (final b in d.dividers)
                if (b != bar) b,
            ],
          );
          final expected = _onScreen(body, view);
          for (final MapEntry(key: drawing, value: draw) in _drawings.entries) {
            final drawn = _changed(
              await draw(d, view),
              await draw(without, view),
            );
            expect(drawn, isNotNull, reason: '$drawing draws nothing');
            expect(
              _apart(drawn!, expected),
              lessThan(_pixels),
              reason:
                  '${bar.id} on $drawing: '
                  'drawn $drawn, the design $expected',
            );
          }
        }
      });

      test('which pane is glass and which is panel', () async {
        final cad = await _cad(d, view: view);
        final sheet = await _sheet(d, view: view);
        final panes = _panes(d);
        for (final pane in panes) {
          final glass = pane.finish.material.isGlazing;
          final facets = [
            for (final f in mesh.facets)
              if (f.elementId == pane.id) f,
          ];
          // The solid: a sealed unit, or a panel.
          expect(
            facets.any((f) => f.role == FacetRole.glazing),
            glass,
            reason: '${pane.id} in the solid',
          );
          expect(
            facets.any((f) => f.role == FacetRole.panel),
            !glass,
            reason: '${pane.id} in the solid',
          );

          // The technical drawing: the glass tint over the pane, or paper
          // with hatching on it.
          final fill = _bounds(geometry.fillOf(pane));
          var tinted = 0, looked = 0;
          for (var i = 1; i < 6; i++) {
            for (var j = 1; j < 6; j++) {
              final at = view.toScreen(
                Vec2(
                  fill.left + fill.width * (0.2 + 0.1 * i),
                  fill.top + fill.height * (0.2 + 0.1 * j),
                ),
              );
              looked++;
              if (_apartColour(_px(cad, at), Cad.paper.glass.toARGB32()) <= 2) {
                tinted++;
              }
            }
          }
          expect(
            tinted / looked,
            glass ? greaterThan(0.6) : lessThan(0.1),
            reason: '${pane.id} on the technical drawing',
          );

          // The drawing: every pane in its own finish — nearer its own
          // colour than any other pane's that is not the same.
          final at = view.toScreen(
            Vec2(
              _bounds(pane.outline).left + _bounds(pane.outline).width * 0.8,
              _bounds(pane.outline).top + _bounds(pane.outline).height * 0.5,
            ),
          );
          final seen = _px(sheet, at);
          final own = _apartColour(seen, pane.finish.colour);
          for (final other in panes) {
            if (other.finish.colour == pane.finish.colour) continue;
            expect(
              own,
              lessThan(_apartColour(seen, other.finish.colour)),
              reason: '${pane.id} on the drawing',
            );
          }
        }
      });

      test('where every handle and hinge is', () async {
        for (final piece in d.hardware) {
          final drawnAs = _box([
            for (final s in geometry.hardwareOf(piece)) ...s.corners,
          ]);
          final built = _built(
            mesh.facets.where(
              (f) => f.elementId == piece.id && f.part != 'the other face',
            ),
          );
          expect(
            _apart(built, drawnAs),
            lessThan(0.05),
            reason: '${piece.kind.name} ${piece.id} in the solid',
          );

          final without = d.copyWith(
            hardware: [
              for (final h in d.hardware)
                if (h != piece) h,
            ],
          );
          final expected = _onScreen(drawnAs, view);
          final concealed = d.isConcealed(piece);
          // The technical drawing shows a piece on the far face as hidden
          // detail when asked; the drawing is of the face you stand at, so
          // there a piece round the back is not drawn at all.
          final cad = _changed(
            await _cad(
              d,
              view: view,
              layers: _bare.copyWith(hiddenDetail: true),
            ),
            await _cad(
              without,
              view: view,
              layers: _bare.copyWith(hiddenDetail: true),
            ),
          );
          expect(cad, isNotNull);
          expect(
            _apart(cad!, expected),
            lessThan(_pixels),
            reason:
                '${piece.kind.name} ${piece.id} on the technical '
                'drawing: drawn $cad, the design $expected',
          );
          final sheet = _changed(
            await _sheet(d, view: view),
            await _sheet(without, view: view),
          );
          if (concealed) {
            expect(sheet, isNull, reason: 'round the back');
          } else {
            expect(sheet, isNotNull);
            expect(
              _apart(sheet!, expected),
              lessThan(_pixels),
              reason:
                  '${piece.kind.name} ${piece.id} on the drawing: '
                  'drawn $sheet, the design $expected',
            );
          }
        }
      });
    });
  }

  group('a change reaches every view', () {
    final d = many.fittedOut();
    final view = _view(d);

    test('the geometry changes: both drawings and the solid follow', () async {
      final bar = d.dividers.firstWhere(
        (b) => d.openingHolding(b.parentId) != null,
      );
      final moved = DesignEdits.moveDividerWithin(
        d,
        bar.id,
        DesignEdits.alongWithin(d, bar)! + 200,
      );
      final before = geometry(d, bar), after = geometry(moved, bar);
      expect(after.top, closeTo(before.top + 200, 1e-6));

      // The solid builds the bar where it now is.
      expect(
        _apart(
          _built(
            MeshBuilder.build(moved).facets.where((f) => f.elementId == bar.id),
          ),
          after,
        ),
        lessThan(1e-6),
      );
      // And each drawing changes where it was and where it is, and nowhere
      // outside the opening it is in.
      final region = _onScreen(
        _bounds(
          d.sectionById(d.openingHolding(bar.parentId)!.sectionId)!.outline,
        ),
        view,
      ).inflate(_pixels);
      for (final MapEntry(key: drawing, value: draw) in _drawings.entries) {
        final drawn = _changed(await draw(d, view), await draw(moved, view));
        expect(drawn, isNotNull, reason: drawing);
        expect(
          region.contains(drawn!.topLeft) && region.contains(drawn.bottomRight),
          isTrue,
          reason: '$drawing: $drawn outside $region',
        );
        expect(
          drawn.top,
          lessThanOrEqualTo(_onScreen(before, view).bottom),
          reason: drawing,
        );
        expect(
          drawn.bottom,
          greaterThanOrEqualTo(_onScreen(after, view).top),
          reason: drawing,
        );
      }
    });

    test(
      'the material changes: every view shows it, on that pane alone',
      () async {
        final glass = _panes(d).firstWhere((p) => p.finish.material.isGlazing);
        final changed = Infill.fill(d, {glass.id: PanelColour.grey.finish});
        final pane = _onScreen(_bounds(glass.outline), view).inflate(_pixels);

        // The solid: that pane is a panel now, and nothing else changed.
        final a = MeshBuilder.build(d), b = MeshBuilder.build(changed);
        Map<String, List<String>> byElement(Mesh m) {
          final out = <String, List<String>>{};
          for (final f in m.facets) {
            (out[f.elementId] ??= []).add(_facet(f));
          }
          return out;
        }

        final was = byElement(a), now = byElement(b);
        for (final id in {...was.keys, ...now.keys}) {
          if (id == glass.id) {
            expect(now[id], isNot(was[id]));
          } else {
            expect(now[id], was[id], reason: id);
          }
        }
        expect(
          b.facets.where(
            (f) => f.elementId == glass.id && f.role == FacetRole.panel,
          ),
          isNotEmpty,
        );

        for (final MapEntry(key: drawing, value: draw) in _drawings.entries) {
          final drawn = _changed(
            await draw(d, view),
            await draw(changed, view),
          );
          expect(drawn, isNotNull, reason: drawing);
          expect(
            pane.contains(drawn!.topLeft) && pane.contains(drawn.bottomRight),
            isTrue,
            reason: '$drawing: $drawn outside the pane $pane',
          );
        }
      },
    );

    test('and the model on the screen is painted again for it', () {
      // The painter decides whether what is on the screen is still right.
      // A change of colour, of glass, or of where a handle is leaves the
      // number of faces and the first face as they were — and it used to
      // look at nothing else, so the picture stayed as it had been.
      ModelPainter painterOf(Design design) {
        final mesh = MeshBuilder.build(design);
        final camera = Camera.presentation.framing(
          mesh,
          width: 640,
          height: 480,
        );
        return ModelPainter(
          faces: camera.project(mesh),
          size: const Size(640, 480),
          viewSpan: Camera.viewSpan(mesh),
          mode: ViewMode.realistic,
          groundPlane: false,
        );
      }

      final panel = _panes(d).firstWhere((p) => !p.finish.material.isGlazing);
      final glass = _panes(d).firstWhere((p) => p.finish.material.isGlazing);
      final handle = d.hardware.firstWhere((h) => h.kind.isHandle);
      final opening = d.openingHolding(handle.parentId)!;
      final edits = {
        'a panel recoloured': Infill.fill(d, {
          panel.id: PanelColour.white.finish,
        }),
        'a clear glass frosted': Infill.fill(d, {
          glass.id: GlassLook.frosted.finish,
        }),
        'a handle recoloured': d.withElement(
          handle.copyWith(
            finish: handle.finish.copyWith(
              colour: HardwareColour.bronze.colour,
            ),
          ),
        ),
        'a handle moved': DesignEdits.setOpeningHardware(
          d,
          opening.id,
          handleAlongMm: 300,
        ),
      };
      final before = painterOf(d);
      expect(
        painterOf(d).shouldRepaint(before),
        isFalse,
        reason: 'the same design is the same picture',
      );
      for (final MapEntry(key: what, value: edited) in edits.entries) {
        expect(
          _mesh(MeshBuilder.build(edited)),
          isNot(_mesh(MeshBuilder.build(d))),
          reason: what,
        );
        expect(painterOf(edited).shouldRepaint(before), isTrue, reason: what);
      }
    });
  });

  test('no drawing fills a part by taking one path from another', () {
    // The web's renderer fills a path difference as the whole of the first
    // path, so a frame drawn as outline-less-daylight covered every pane in
    // its own colour there and nowhere else: the drawing showed neither
    // glass nor panel in the browser while every test canvas was right. A
    // ring is one path filled even-odd, which every renderer fills alike.
    for (final file in [
      'lib/app/canvas/design_painter.dart',
      'lib/app/canvas/cad_painter.dart',
    ]) {
      expect(
        File(file).readAsStringSync(),
        isNot(contains('Path.combine')),
        reason: file,
      );
    }
  });

  group('looking is not editing', () {
    final d = mixed.theScreen();
    final json = _json(d);
    final mesh = _mesh(MeshBuilder.build(d));

    test('turning, zooming and panning the camera change no geometry', () {
      final built = MeshBuilder.build(d);
      for (final camera in [
        Camera.presentation,
        Camera.front,
        Camera.back,
        Camera.top,
        Camera.isometric,
        Camera.presentation.orbited(70, -20),
        Camera.presentation.framing(built, width: 390, height: 700),
        Camera.presentation.copyWith(projection: Projection.parallel),
      ]) {
        final faces = camera.project(built);
        expect(faces, isNotEmpty);
        // Every face on the screen is a face the design built, unchanged.
        expect(faces.every((f) => built.facets.contains(f.source)), isTrue);
      }
      expect(_mesh(built), mesh);
      expect(_mesh(MeshBuilder.build(d)), mesh);
      expect(_json(d), json);
    });

    test('changing how the model is shown changes no geometry', () async {
      final built = MeshBuilder.build(d);
      final camera = Camera.presentation.framing(
        built,
        width: 640,
        height: 480,
      );
      for (final mode in ViewMode.values) {
        for (final palette in [Palette.light, Palette.dark]) {
          await _raster(
            (canvas) => ModelPainter(
              faces: camera.project(built),
              size: const Size(640, 480),
              viewSpan: Camera.viewSpan(built),
              mode: mode,
              palette: palette,
            ).paint(canvas, const Size(640, 480)),
          );
        }
      }
      expect(_mesh(built), mesh);
      expect(_json(d), json);
    });

    test('changing how the drawings are shown changes no geometry', () async {
      for (final layers in [
        const CadLayers(),
        _bare,
        _bare.copyWith(hiddenDetail: true),
        const CadLayers(dimensions: false, annotations: false),
      ]) {
        for (final ink in [Cad.paper, Cad.night]) {
          await _cad(d, layers: layers, ink: ink);
        }
      }
      await _sheet(d);
      await _sheet(d, palette: Palette.dark);
      expect(_json(d), json);
      expect(_mesh(MeshBuilder.build(d)), mesh);
    });
  });
}

/// Where [bar] is in [d], as the geometry every view reads gives it.
Rect geometry(Design d, DividerElement bar) =>
    _bounds(DesignGeometry.of(d).barBody(d.dividerById(bar.id)!));
