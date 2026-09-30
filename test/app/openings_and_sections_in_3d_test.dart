import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/cad_layers.dart';
import 'package:proframe/app/canvas/cad_painter.dart';
import 'package:proframe/app/canvas/view_transform.dart';
import 'package:proframe/app/theme/app_theme.dart';
import 'package:proframe/app/viewer/display_style.dart';
import 'package:proframe/app/viewer/model_painter.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/hardware/opening_hardware.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_tree.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/infill.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/solid/camera.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';
import 'package:proframe/domain/solid/studio.dart';

import '../domain/many_openings_in_one_design_test.dart' as many;
import '../domain/rendering_geometry_baseline_test.dart' as base;

// Phase 15 of the CAD and 3D work: complex designs, drawn as what they are.
//
// A design may hold several openings — doors and windows — each divided
// into glass and panel by lines drawn inside it. The model keeps that
// hierarchy (the frame; the openings, each its own leaf; the divisions and
// panes inside each), and so must the 3D view:
//
// - **Glass over panel is two things in the leaf**: the upper pane built and
//   shown as glass, seen through; the lower as a panel, solid.
// - **Each opening is its own**: its own sash, its own panes and dividers,
//   its own ironmongery by its own kind, nothing shared with another
//   opening, and swinging one moves it alone — two openings side by side
//   either side of a mullion are two leaves, never one.
// - **A divider inside an opening stays in it**: inside the opening's
//   outline, set back in the leaf's depth rather than the frame's, and
//   swinging with the leaf — never a member of the outer frame.
// - **Glass → panel on one pane changes that pane**, in the solid and on
//   the technical drawing, and nothing else.
// - **What stands open reads as standing open**: the floor under a leaf
//   swung out takes that leaf's shadow — the leaf's own members, turned with
//   it — and not a block of shadow the size of everything round it.

/// Three openings in a row under a fixed head, each divided into glass over
/// panel by a line drawn inside it: the first a door, the other two windows.
Design _set() {
  var d = many.fittedOut();
  final order = d.openingsInOrder;
  d = OpeningHardware.settle(
    d.copyWith(
      openings: [
        for (final o in d.openings)
          o.copyWith(
            kind: o.id == order.first.id ? DesignKind.door : DesignKind.window,
          ),
      ],
    ),
  );
  return d;
}

/// Every element that is [opening]'s — its own region, the panes and bars
/// inside it, its ironmongery.
Set<String> _partsOf(Design d, OpeningElement opening) => {
  opening.sectionId,
  for (final part in d.contentsOf(opening)) part.id,
};

String _fingerprint(Facet f) => [
  f.elementId,
  f.role,
  f.part,
  for (final c in f.corners)
    '${c.x.toStringAsFixed(3)},'
        '${c.y.toStringAsFixed(3)},${c.z.toStringAsFixed(3)}',
  f.colour,
  f.surface.id,
].join('|');

Map<String, List<String>> _byElement(Mesh mesh) {
  final out = <String, List<String>>{};
  for (final f in mesh.facets) {
    (out[f.elementId] ??= []).add(_fingerprint(f));
  }
  return out;
}

const _size = Size(720, 540);

Future<Uint8List> _render(Design d, {Palette palette = Palette.light}) async {
  final mesh = MeshBuilder.build(d);
  final camera = Camera.presentation.framing(
    mesh,
    width: _size.width,
    height: _size.height,
  );
  final recorder = ui.PictureRecorder();
  ModelPainter(
    faces: camera.project(mesh),
    size: _size,
    viewSpan: Camera.viewSpan(mesh),
    style: DisplayStyle.shaded,
    groundPlane: false,
    palette: palette,
  ).paint(Canvas(recorder), _size);
  final image = await recorder.endRecording().toImage(
    _size.width.round(),
    _size.height.round(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Where on the picture of [d] the middle of [section]'s front face lands.
Offset _onPicture(Design d, String section) {
  final mesh = MeshBuilder.build(d);
  final camera = Camera.presentation.framing(
    mesh,
    width: _size.width,
    height: _size.height,
  );
  final faces = camera.project(mesh);
  // The pane's own face — not the bead round it, which carries its id too.
  final face = faces
      .where(
        (f) =>
            f.source.elementId == section &&
            !f.source.isSide &&
            (f.source.role == FacetRole.glazing ||
                f.source.role == FacetRole.panel),
      )
      .first;
  var sx = 0.0, sy = 0.0;
  for (final c in face.corners) {
    sx += c.x;
    sy += c.y;
  }
  final scale = _size.shortestSide * Camera.spanShare / Camera.viewSpan(mesh);
  return Offset(
    _size.width / 2 + sx / face.corners.length * scale,
    _size.height / 2 + sy / face.corners.length * scale,
  );
}

List<int> _px(Uint8List rgba, Offset p) {
  final i = (p.dy.round() * _size.width.round() + p.dx.round()) * 4;
  return [rgba[i], rgba[i + 1], rgba[i + 2]];
}

void main() {
  group('a door of glass over panel', () {
    final door = base.door();
    final opening = door.openings.single;
    final panes = door.childSectionsOf(opening.sectionId)
      ..sort((a, b) => a.outline.top.compareTo(b.outline.top));
    final glass = panes.first, panel = panes.last;

    test(
      'the hierarchy: the frame, the opening, and in it glass and panel',
      () {
        final tree = DesignTree.of(door);
        final branch = tree.openings.single;
        expect(branch.openingId, opening.id);
        expect(
          [for (final p in branch.panes) p.sectionId],
          [glass.id, panel.id],
        );
        expect(branch.barIds, hasLength(1), reason: 'the line between them');
        expect(tree.barIds, isNot(contains(branch.barIds.single)));
      },
    );

    test('the glass is built as glass and the panel as panel', () {
      final mesh = MeshBuilder.build(door);
      final glassFacets = mesh.facets.where((f) => f.elementId == glass.id);
      final panelFacets = mesh.facets.where((f) => f.elementId == panel.id);
      expect(glassFacets.where((f) => f.role == FacetRole.glazing), isNotEmpty);
      expect(glassFacets.where((f) => f.role == FacetRole.panel), isEmpty);
      expect(panelFacets.where((f) => f.role == FacetRole.panel), isNotEmpty);
      expect(panelFacets.where((f) => f.surface.isTransparent), isEmpty);
    });

    test('and looks it: the glass shows what is behind it, the panel does '
        'not', () async {
      // Clear glass, so what is behind it is plain to see.
      final clear = Infill.fill(door, {glass.id: GlassLook.clear.finish});
      final light = await _render(clear);
      final dark = await _render(clear, palette: Palette.dark);
      int apart(List<int> a, List<int> b) =>
          [for (var i = 0; i < 3; i++) (a[i] - b[i]).abs()].reduce(math.max);
      final atGlass = _onPicture(clear, glass.id);
      final atPanel = _onPicture(clear, panel.id);
      expect(apart(_px(light, atGlass), _px(dark, atGlass)), greaterThan(20));
      expect(apart(_px(light, atPanel), _px(dark, atPanel)), 0);
    });
  });

  group('three openings, each its own', () {
    final d = _set();
    final openings = d.openingsInOrder;
    final mesh = MeshBuilder.build(d);

    test('a door and two windows, each with its own sash, panes, divider '
        'and ironmongery, sharing nothing', () {
      expect(openings, hasLength(3));
      expect(
        [for (final o in openings) d.kindOf(o)],
        [DesignKind.door, DesignKind.window, DesignKind.window],
      );
      final parts = [for (final o in openings) _partsOf(d, o)];
      for (var i = 0; i < 3; i++) {
        for (var j = i + 1; j < 3; j++) {
          expect(parts[i].intersection(parts[j]), isEmpty);
        }
        // Built, every part of it.
        final built = {for (final f in mesh.facets) f.elementId};
        expect(built.containsAll(parts[i]), isTrue);
      }
      // A door carries a lock and a window none: each by its own kind.
      final locks = [
        for (final o in openings)
          d.hardware
              .where(
                (h) =>
                    h.kind == HardwareKind.lock &&
                    parts[openings.indexOf(o)].contains(h.id),
              )
              .length,
      ];
      expect(locks, [1, 0, 0]);
    });

    test('side by side either side of a mullion, two leaves: their sashes '
        'do not meet', () {
      Rect leafOf(OpeningElement o) {
        var box = Rect.zero;
        var first = true;
        for (final f in mesh.facets) {
          if (f.elementId != o.sectionId) continue;
          for (final c in f.corners) {
            final r = Rect.fromLTWH(c.x, c.y, 0, 0);
            box = first ? r : box.expandToInclude(r);
            first = false;
          }
        }
        return box;
      }

      final leaves = [for (final o in openings) leafOf(o)];
      for (var i = 0; i + 1 < leaves.length; i++) {
        expect(
          leaves[i].right,
          lessThan(leaves[i + 1].left),
          reason: 'the mullion between them is the design\'s',
        );
      }
      // And the mullion is neither leaf's.
      for (final bar in d.topLevelDividers) {
        for (final o in openings) {
          expect(_partsOf(d, o), isNot(contains(bar.id)));
        }
      }
    });

    test('each swings as one body of its own, and nothing else moves', () {
      final shut = _byElement(mesh);
      final open = MeshBuilder.build(d, openFraction: 0.6);
      final swung = _byElement(open);
      final parts = [for (final o in openings) _partsOf(d, o)];
      final inAny = parts.expand((p) => p).toSet();
      for (final id in shut.keys) {
        if (inAny.contains(id)) {
          expect(swung[id], isNot(shut[id]), reason: '$id should move');
        } else {
          expect(swung[id], shut[id], reason: '$id should stay');
        }
      }
      // One body each: every distance within an opening is kept as it
      // swings, and distances from one opening to another are not — two
      // leaves turning about two hinges, not one thing.
      List<(Vec3, Vec3)> pointsOf(Set<String> ids) {
        final a = [
          for (final f in mesh.facets)
            if (ids.contains(f.elementId) && f.role != FacetRole.hardware)
              ...f.corners,
        ];
        final b = [
          for (final f in open.facets)
            if (ids.contains(f.elementId) && f.role != FacetRole.hardware)
              ...f.corners,
        ];
        expect(a.length, b.length);
        final step = math.max(1, a.length ~/ 40);
        return [for (var i = 0; i < a.length; i += step) (a[i], b[i])];
      }

      final samples = [for (final p in parts) pointsOf(p)];
      for (var i = 0; i < samples.length; i++) {
        for (final (p0, p1) in samples[i]) {
          for (final (q0, q1) in samples[i]) {
            expect(((p1 - q1).length - (p0 - q0).length).abs(), lessThan(0.01));
          }
        }
        for (var j = i + 1; j < samples.length; j++) {
          var changed = 0.0;
          for (final (p0, p1) in samples[i]) {
            for (final (q0, q1) in samples[j]) {
              changed = math.max(
                changed,
                ((p1 - q1).length - (p0 - q0).length).abs(),
              );
            }
          }
          expect(
            changed,
            greaterThan(50),
            reason: 'openings $i and $j would be one body',
          );
        }
      }
    });
  });

  group('a divider inside an opening stays in it', () {
    final d = _set();
    final mesh = MeshBuilder.build(d);

    test(
      'inside the opening, set back in the leaf, and never the frame\'s',
      () {
        // How far forward the design's own bars stand.
        final frameBars = {for (final b in d.topLevelDividers) b.id};
        final barFront = mesh.facets
            .where((f) => frameBars.contains(f.elementId))
            .expand((f) => f.corners)
            .map((c) => c.z)
            .reduce(math.max);
        for (final o in d.openingsInOrder) {
          final box = d.sectionById(o.sectionId)!.outline;
          final inside = d.dividers.where(
            (b) => d.openingHolding(b.parentId)?.id == o.id,
          );
          expect(inside, hasLength(1));
          final bar = inside.single;
          expect(d.topLevelDividers, isNot(contains(bar)));
          final corners = [
            for (final f in mesh.facets)
              if (f.elementId == bar.id) ...f.corners,
          ];
          expect(corners, isNotEmpty);
          for (final c in corners) {
            expect(
              c.x >= box.left - 0.5 &&
                  c.x <= box.right + 0.5 &&
                  c.y >= box.top - 0.5 &&
                  c.y <= box.bottom + 0.5,
              isTrue,
              reason: '${bar.id} at $c',
            );
          }
          // In the leaf's depth: set back behind the design's own bars.
          expect(corners.map((c) => c.z).reduce(math.max), lessThan(barFront));
        }
      },
    );
  });

  group('glass to panel changes that pane and nothing else', () {
    final d = _set();
    final second = d.openingsInOrder[1];
    final upper = (d.childSectionsOf(
      second.sectionId,
    )..sort((a, b) => a.outline.top.compareTo(b.outline.top))).first;
    final changed = Infill.fill(d, {upper.id: PanelColour.grey.finish});

    test('in the solid', () {
      final before = _byElement(MeshBuilder.build(d));
      final after = _byElement(MeshBuilder.build(changed));
      expect(after.keys.toSet(), before.keys.toSet());
      for (final id in before.keys) {
        if (id == upper.id) {
          expect(after[id], isNot(before[id]));
        } else {
          expect(after[id], before[id], reason: id);
        }
      }
      final mesh = MeshBuilder.build(changed);
      expect(
        mesh.facets.where(
          (f) => f.elementId == upper.id && f.surface.isTransparent,
        ),
        isEmpty,
      );
    });

    test('on the technical drawing', () async {
      const size = Size(900, 600);
      final view = ViewTransform.fit(
        d.frame!.outline,
        size,
        padding: const EdgeInsets.all(40),
      );
      const layers = CadLayers(
        grid: false,
        dimensions: false,
        annotations: false,
      );
      Future<Uint8List> draw(Design design) async {
        final recorder = ui.PictureRecorder();
        CadPainter(
          design: design,
          view: view,
          layers: layers,
        ).paint(Canvas(recorder), size);
        final image = await recorder.endRecording().toImage(900, 600);
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        return data!.buffer.asUint8List();
      }

      final a = await draw(d);
      final b = await draw(changed);
      final pane = Rect.fromPoints(
        view.toScreen(Vec2(upper.outline.left, upper.outline.top)),
        view.toScreen(Vec2(upper.outline.right, upper.outline.bottom)),
      ).inflate(1);
      var inside = 0;
      for (var i = 0; i < a.length; i += 4) {
        if (a[i] == b[i] && a[i + 1] == b[i + 1] && a[i + 2] == b[i + 2]) {
          continue;
        }
        final p = Offset(((i ~/ 4) % 900).toDouble(), ((i ~/ 4) ~/ 900) * 1.0);
        expect(pane.contains(p), isTrue, reason: 'changed outside at $p');
        inside++;
      }
      expect(inside, greaterThan(100));
    });
  });

  group('what stands open reads as standing open', () {
    test('the floor under a swung leaf takes the leaf\'s shadow, not a '
        'block the size of the box round it', () {
      final d = _set();
      final open = MeshBuilder.build(d, openFraction: 0.7);
      final floor = Floor.under(open)!;
      // Every member of a swung leaf is blocked square to the leaf itself.
      final turned = floor.blocks.where((b) => b.axes != null).toList();
      expect(turned, isNotEmpty);
      // The box square to the model round a turned member stands mostly on
      // open floor: a corner of it away from the member is lit by most of
      // the sky, where a box would have shut it all out.
      var checked = 0;
      for (final block in turned) {
        final box = block.square;
        if (box.maxX - box.minX < 150 || box.maxZ - box.minZ < 150) continue;
        final cx = (box.minX + box.maxX) / 2, cz = (box.minZ + box.maxZ) / 2;
        final open = [
          for (final x in [box.minX, box.maxX])
            for (final z in [box.minZ, box.maxZ])
              floor.occlusionAt(cx + (x - cx) * 0.8, cz + (z - cz) * 0.8),
        ].reduce(math.min);
        expect(open, lessThan(0.6));
        checked++;
      }
      expect(checked, greaterThan(0));
      // And shut, nothing is turned: the plain boxes it always was.
      expect(
        Floor.under(MeshBuilder.build(d))!.blocks.every((b) => b.axes == null),
        isTrue,
      );
    });
  });
}
