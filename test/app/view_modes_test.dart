import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/cad_style.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/screens/workspace_screen.dart';
import 'package:proframe/app/state/tools.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/app/theme/app_theme.dart';
import 'package:proframe/app/viewer/model_painter.dart';
import 'package:proframe/app/viewer/model_view.dart';
import 'package:proframe/app/viewer/view_mode.dart';
import 'package:proframe/app/viewer/view_mode_switch.dart';
import 'package:proframe/domain/dimensions/measurements.dart';
import 'package:proframe/domain/dimensions/units.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/solid/camera.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';
import 'package:proframe/domain/solid/studio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/rendering_geometry_baseline_test.dart' as base;
import 'a_customer_s_page_test.dart' as page;
import 'a_design_in_every_view_test.dart' as every;
import 'customers_screen_test.dart' as customers;
import 'new_design.dart';
import 'the_designs_screen_test.dart' as screen;

// Phase 18 of the CAD and 3D work: the ways a professional looks at a
// design.
//
//   Technical   a line drawing of the solid, its lines ranked, its overall
//               sizes written on it
//   Shaded      one colour, lit, edged: the form and its depth
//   Material    glass, panel, frame and metal as they are made, no shadows
//   Realistic   materials, light and shadow, the floor
//
// Every mode paints the same faces the solid built from the design, so each
// is measured against the others on what it puts on the screen: the model
// in the same place and the same size in all four, and each a different
// picture of it. Then what each is for, on its pixels. And a mode is a way
// of looking, like the camera: choosing one changes nothing in the design,
// nothing kept and nothing to undo, and it sits in the band along the top
// of the view that the model is framed clear of.

const _size = Size(640, 480);

Future<Uint8List> _raster(ModelPainter painter) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), _size);
  final image = await recorder.endRecording().toImage(
    _size.width.round(),
    _size.height.round(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!.buffer.asUint8List();
}

List<int> _at(Uint8List rgba, Offset p) {
  final i = (p.dy.round() * _size.width.round() + p.dx.round()) * 4;
  return [rgba[i], rgba[i + 1], rgba[i + 2]];
}

/// Where two pictures differ: the box round every pixel that is not the
/// same in both.
Rect? _changed(Uint8List a, Uint8List b) {
  final w = _size.width.round();
  var left = w, top = 1 << 30, right = -1, bottom = -1;
  for (var i = 0; i < a.length; i += 4) {
    if (a[i] == b[i] && a[i + 1] == b[i + 1] && a[i + 2] == b[i + 2]) continue;
    final x = (i ~/ 4) % w, y = (i ~/ 4) ~/ w;
    if (x < left) left = x;
    if (x > right) right = x;
    if (y < top) top = y;
    if (y > bottom) bottom = y;
  }
  if (right < 0) return null;
  return Rect.fromLTRB(
    left.toDouble(),
    top.toDouble(),
    right + 1.0,
    bottom + 1.0,
  );
}

String _json(Design d) => jsonEncode(d.toJson());

String _mesh(Mesh mesh) => [
  for (final f in mesh.facets)
    [
      f.elementId,
      f.role.name,
      for (final c in f.corners)
        '${c.x.toStringAsFixed(5)},${c.y.toStringAsFixed(5)},'
            '${c.z.toStringAsFixed(5)}',
    ].join('|'),
].join('\n');

class _Scene {
  final Design design;
  final Mesh mesh;
  final Camera camera;
  late final List<ProjectedFacet> faces = camera.project(mesh);

  _Scene(this.design, {Camera from = Camera.presentation})
    : mesh = MeshBuilder.build(design),
      camera = from.framing(
        MeshBuilder.build(design),
        width: _size.width,
        height: _size.height,
      );

  ModelPainter painter(
    ViewMode mode, {
    bool floor = false,
    bool noFaces = false,
    Palette palette = Palette.light,
  }) => ModelPainter(
    faces: noFaces ? const [] : faces,
    size: _size,
    viewSpan: Camera.viewSpan(mesh),
    mode: mode,
    groundPlane: floor,
    floor: floor ? Floor.under(mesh)?.seenBy(camera, mesh) : null,
    dimensions: overallSizesOn(design, camera, mesh),
    palette: palette,
  );

  /// Where the model is on the screen in [mode]: every pixel that is not
  /// what the same mode paints with no model in it.
  Future<Rect> footprint(ViewMode mode) async {
    final painter = this.painter(mode);
    final bare = await _raster(
      ModelPainter(
        faces: const [],
        size: _size,
        viewSpan: painter.viewSpan,
        mode: mode,
        groundPlane: false,
      ),
    );
    // Without the figures, which stand off the model on purpose.
    final model = await _raster(
      ModelPainter(
        faces: faces,
        size: _size,
        viewSpan: painter.viewSpan,
        mode: mode,
        groundPlane: false,
      ),
    );
    return _changed(bare, model)!;
  }

  /// Points on the screen where the uppermost face is one of [role]'s,
  /// facing the eye and seen whole — sampled across the view.
  /// The uppermost face at each point of a 3-pixel grid across the view,
  /// worked out once: the faces are painted far to near, so it is the last
  /// one holding the point — and never a sheet of glass where it is kept
  /// off what lies in front of it, as the painter keeps it.
  late final List<List<ProjectedFacet?>> _uppermost = () {
    final painter = this.painter(ViewMode.realistic);
    final scale = 1 / painter.millimetresPerPixel;
    Offset place(Vec2 v) =>
        Offset(_size.width / 2 + v.x * scale, _size.height / 2 + v.y * scale);
    final outlines = [
      for (final f in faces) [for (final c in f.corners) place(c)],
    ];
    final boxes = [
      for (final o in outlines)
        Rect.fromPoints(o.first, o.first).expandToInclude(
          Rect.fromLTRB(
            o.map((p) => p.dx).reduce(math.min),
            o.map((p) => p.dy).reduce(math.min),
            o.map((p) => p.dx).reduce(math.max),
            o.map((p) => p.dy).reduce(math.max),
          ),
        ),
    ];
    bool inside(List<Offset> o, Offset p) {
      var hit = false;
      for (var i = 0, j = o.length - 1; i < o.length; j = i++) {
        if ((o[i].dy > p.dy) != (o[j].dy > p.dy) &&
            p.dx <
                (o[j].dx - o[i].dx) * (p.dy - o[i].dy) / (o[j].dy - o[i].dy) +
                    o[i].dx) {
          hit = !hit;
        }
      }
      return hit;
    }

    ProjectedFacet? at(Offset p) {
      for (var k = faces.length - 1; k >= 0; k--) {
        if (!boxes[k].contains(p) || !inside(outlines[k], p)) continue;
        final face = faces[k];
        if (face.hiders.any(
          (h) => h.length >= 3 && inside([for (final c in h) place(c)], p),
        )) {
          continue;
        }
        return face;
      }
      return null;
    }

    return [
      for (var y = 0.0; y < _size.height; y += _step)
        [for (var x = 0.0; x < _size.width; x += _step) at(Offset(x, y))],
    ];
  }();

  static const double _step = 3;

  /// Points on the screen where the uppermost face is one of [role]'s,
  /// facing the eye — each with the same face all round it, so no edge is
  /// sampled.
  List<Offset> pointsOn(
    FacetRole role, {
    bool Function(ProjectedFacet)? where,
  }) {
    final grid = _uppermost;
    return [
      for (var j = 1; j + 1 < grid.length; j++)
        for (var i = 1; i + 1 < grid[j].length; i++)
          if (grid[j][i] case final face?
              when face.source.role == role &&
                  !face.source.isSide &&
                  (where?.call(face) ?? true) &&
                  identical(grid[j - 1][i], face) &&
                  identical(grid[j + 1][i], face) &&
                  identical(grid[j][i - 1], face) &&
                  identical(grid[j][i + 1], face))
            Offset(i * _step, j * _step),
    ];
  }
}

void main() {
  final door = base.door();

  group('the same geometry in every mode', () {
    final scene = _Scene(door);
    final json = _json(door);
    final mesh = _mesh(scene.mesh);

    test(
      'every mode shows the model in the same place at the same size',
      () async {
        final reference = await scene.footprint(ViewMode.realistic);
        for (final mode in ViewMode.values) {
          final at = await scene.footprint(mode);
          // A drawn edge is a line with a width, so an edged mode reaches a
          // pixel or two past the faces; nothing more.
          for (final (a, b) in [
            (at.left, reference.left),
            (at.top, reference.top),
            (at.right, reference.right),
            (at.bottom, reference.bottom),
          ]) {
            expect(a, closeTo(b, 3), reason: '$mode $at $reference');
          }
        }
      },
    );

    test('and each mode is a different picture of it', () async {
      final shots = {
        for (final mode in ViewMode.values)
          mode: await _raster(scene.painter(mode, floor: true)),
      };
      for (final a in ViewMode.values) {
        for (final b in ViewMode.values) {
          if (a.index >= b.index) continue;
          expect(
            _changed(shots[a]!, shots[b]!),
            isNotNull,
            reason: '$a and $b are the same picture',
          );
        }
      }
    });

    test('painting in any mode, in either appearance, changes nothing in '
        'the design or its solid', () async {
      for (final mode in ViewMode.values) {
        for (final palette in [Palette.light, Palette.dark]) {
          await _raster(scene.painter(mode, floor: true, palette: palette));
        }
      }
      expect(_json(door), json);
      expect(_mesh(scene.mesh), mesh);
      expect(_mesh(MeshBuilder.build(door)), mesh);
    });

    test('the four are the ones always offered, in order, and the '
        'wireframe is kept under More', () {
      expect(ViewMode.shown, [
        ViewMode.technical,
        ViewMode.shaded,
        ViewMode.material,
        ViewMode.realistic,
      ]);
      expect(ViewMode.shown, isNot(contains(ViewMode.wireframe)));
      for (final mode in ViewMode.values) {
        expect(mode.label, isNotEmpty);
        expect(mode.hint, isNotEmpty);
      }
    });
  });

  group('technical: accuracy, dimensions, line hierarchy', () {
    final scene = _Scene(door);
    final outline = door.frame!.outline;

    test('the overall width, height and depth are the design\'s own figures, '
        'written as the technical drawing writes them', () {
      final sizes = overallSizesOn(door, scene.camera, scene.mesh);
      expect(sizes.map((s) => s.label), [
        Measurements.figure(outline.width, known: true, places: 1),
        Measurements.figure(outline.height, known: true, places: 1),
        '${Units.formatTo(door.depthMm, 1)} ${Units.symbol}',
      ]);
      expect(sizes.first.label, '160.0 cm');
      expect(sizes[1].label, '210.0 cm');
    });

    test('a size not yet given is written ?', () {
      final unknown = door.copyWith(measured: const {});
      final sizes = overallSizesOn(unknown, scene.camera, scene.mesh);
      expect(sizes.first.label, '? ${Units.symbol}');
      expect(sizes[1].label, '? ${Units.symbol}');
    });

    test('each figure stands on the edge it measures, where the camera '
        'puts it', () {
      final eye = scene.camera.eyeSpaceFor(scene.mesh);
      final sizes = overallSizesOn(door, scene.camera, scene.mesh);
      final width = sizes[0], height = sizes[1], depth = sizes[2];
      expect(width.from, eye.place(Vec3(outline.left, outline.bottom, 0)));
      expect(width.to, eye.place(Vec3(outline.right, outline.bottom, 0)));
      // The depth runs back along the foot of the side that is seen, and
      // the height up the other side, so the two never meet.
      final sides = [outline.left, outline.right];
      final depthAt = sides.firstWhere(
        (x) => depth.from == eye.place(Vec3(x, outline.bottom, 0)),
      );
      expect(depth.to, eye.place(Vec3(depthAt, outline.bottom, -door.depthMm)));
      final heightAt = sides.firstWhere((x) => x != depthAt);
      expect(height.from, eye.place(Vec3(heightAt, outline.top, 0)));
      expect(height.to, eye.place(Vec3(heightAt, outline.bottom, 0)));
      // And the side seen is the one turned towards the eye: its foot
      // stands further out from the drawn face on the screen.
      final back = eye.place(Vec3(depthAt, outline.bottom, -door.depthMm))!;
      final front = eye.place(Vec3(depthAt, outline.bottom, 0))!;
      expect((back - front).length, greaterThan(10));
    });

    test('square on, no side is seen and the depth is left off; turned, '
        'the figures move with the model and say the same', () {
      final front = _Scene(door, from: Camera.front);
      final square = overallSizesOn(door, front.camera, front.mesh);
      expect(square, hasLength(2));
      final turned = _Scene(door, from: Camera.isometric);
      final round = overallSizesOn(door, turned.camera, turned.mesh);
      final here = overallSizesOn(door, scene.camera, scene.mesh);
      expect(
        round.map((s) => s.label).toSet(),
        here.map((s) => s.label).toSet(),
      );
      expect(round.first.from, isNot(here.first.from));
    });

    test('the lines are ranked: the frame heaviest, then a sash, a bar, and '
        'glass the finest', () {
      final painter = scene.painter(ViewMode.technical);
      double outer(FacetRole role, {bool glass = false}) =>
          painter.penOf(role, glass: glass).$1.$1;
      double inner(FacetRole role) => painter.penOf(role).$2.$1;
      expect(outer(FacetRole.frame), greaterThan(outer(FacetRole.sash)));
      expect(outer(FacetRole.sash), greaterThan(outer(FacetRole.bar)));
      expect(outer(FacetRole.bar), greaterThan(outer(FacetRole.panel)));
      expect(
        outer(FacetRole.bar),
        greaterThan(outer(FacetRole.glazing, glass: true)),
      );
      for (final role in FacetRole.values) {
        expect(inner(role), lessThanOrEqualTo(outer(role)), reason: '$role');
      }
      // In the technical drawing's own weights and inks.
      expect(painter.penOf(FacetRole.frame).$1.$2, Cad.paper.heavy);
      expect(
        painter.penOf(FacetRole.glazing, glass: true).$1.$2,
        Cad.paper.glassLine,
      );
    });

    test('on the paper, in the drawing\'s colours: glass its tint, the '
        'frame its structural tone, a panel the paper — flat, with no '
        'floor', () async {
      for (final ink in [Cad.paper, Cad.night]) {
        final palette = ink == Cad.paper ? Palette.light : Palette.dark;
        final shot = await _raster(
          scene.painter(ViewMode.technical, palette: palette),
        );
        expect(
          _raster(
            scene.painter(ViewMode.technical, floor: true, palette: palette),
          ),
          completion(shot),
          reason: 'a drawing stands on no floor',
        );
        List<int> rgb(Color c) => [
          (c.r * 255).round(),
          (c.g * 255).round(),
          (c.b * 255).round(),
        ];
        expect(_at(shot, const Offset(3, 3)), rgb(ink.sheet));
        for (final (role, colour) in [
          (FacetRole.glazing, ink.glass),
          (FacetRole.frame, ink.structure),
          (FacetRole.panel, ink.sheet),
        ]) {
          final points = scene.pointsOn(
            role,
            where: (f) =>
                f.source.surface.isTransparent == (role == FacetRole.glazing),
          );
          expect(points, isNotEmpty, reason: '$role');
          final exact = points
              .where((p) => _listEq(_at(shot, p), rgb(colour)))
              .length;
          expect(
            exact / points.length,
            greaterThan(0.8),
            reason: '$role in ${ink.isDark ? 'night' : 'paper'}',
          );
        }
      }
    });

    test('the figures are written beside the model and only in the '
        'technical mode', () async {
      final foot = await scene.footprint(ViewMode.technical);
      Future<int> inkBelow(ViewMode mode) async {
        final shot = await _raster(scene.painter(mode));
        final bare = await _raster(
          ModelPainter(
            faces: scene.faces,
            size: _size,
            viewSpan: Camera.viewSpan(scene.mesh),
            mode: mode,
            groundPlane: false,
          ),
        );
        var n = 0;
        for (var y = foot.bottom + 2; y < _size.height; y += 1) {
          for (var x = foot.left; x < foot.right; x += 1) {
            if (!_listEq(_at(shot, Offset(x, y)), _at(bare, Offset(x, y)))) n++;
          }
        }
        return n;
      }

      expect(await inkBelow(ViewMode.technical), greaterThan(40));
      for (final mode in ViewMode.values) {
        if (mode.isTechnical) continue;
        expect(await inkBelow(mode), 0, reason: '$mode');
      }
    });
  });

  group('shaded, material, realistic', () {
    final scene = _Scene(door);

    test(
      'shaded shows the form in one colour: the brown panel is grey',
      () async {
        final panel = scene.pointsOn(FacetRole.panel);
        expect(panel, isNotEmpty);
        for (final (mode, brown) in [
          (ViewMode.shaded, false),
          (ViewMode.material, true),
          (ViewMode.realistic, true),
        ]) {
          final shot = await _raster(scene.painter(mode));
          final c = _at(shot, panel[panel.length ~/ 2]);
          final spread =
              [c[0], c[1], c[2]].reduce((a, b) => a > b ? a : b) -
              [c[0], c[1], c[2]].reduce((a, b) => a < b ? a : b);
          expect(
            spread,
            brown ? greaterThan(25) : lessThanOrEqualTo(3),
            reason: '$mode $c',
          );
        }
      },
    );

    test('material shows every part as it is made, and casts no shadow; '
        'realistic casts the floor\'s shadow', () async {
      expect(ViewMode.material.usesFinishes, isTrue);
      expect(ViewMode.material.castsShadows, isFalse);
      expect(ViewMode.realistic.castsShadows, isTrue);
      expect(ViewMode.realistic.drawsEdges, isFalse);
      expect(ViewMode.material.drawsEdges, isTrue);

      final foot = await scene.footprint(ViewMode.realistic);
      final material = await _raster(
        scene.painter(ViewMode.material, floor: true),
      );
      final realistic = await _raster(
        scene.painter(ViewMode.realistic, floor: true),
      );
      double light(List<int> c) => (c[0] + c[1] + c[2]) / 3;
      final under = Offset(foot.center.dx, foot.bottom + 3);
      expect(
        light(_at(realistic, under)),
        lessThan(light(_at(material, under)) - 8),
        reason: 'the floor is darkened just in front of the foot',
      );
    });

    test('glass is seen through in material and realistic', () async {
      final glass = scene.pointsOn(
        FacetRole.glazing,
        where: (f) => f.source.surface.isTransparent,
      );
      expect(glass, isNotEmpty);
      for (final mode in [ViewMode.material, ViewMode.realistic]) {
        final light = await _raster(scene.painter(mode));
        final dark = await _raster(scene.painter(mode, palette: Palette.dark));
        // What is behind the glass is the studio, lighter or darker with
        // the appearance, and it shows through the pane.
        final moved = glass
            .where((p) => !_listEq(_at(light, p), _at(dark, p)))
            .length;
        expect(moved / glass.length, greaterThan(0.5), reason: '$mode');
      }
    });
  });

  group('on the real app', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> openAdam(WidgetTester tester) async {
      await customers.toCustomers(tester);
      await page.openCustomer(tester, 'Adam');
      final open = find
          .byKey(CustomerDesignCard.openKey('basement-door'))
          .hitTestable();
      await tester.scrollUntilVisible(
        open,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(find.byType(WorkspaceScreen), findsOneWidget);
      await every.showView(tester, WorkspaceView.model);
    }

    for (final (name, size) in [
      ('a laptop', every.laptop),
      ('a phone', const Size(390, 844)),
    ]) {
      testWidgets('on $name: the selector sits in the band over the model, '
          'and every mode is the same geometry and changes nothing', (
        tester,
      ) async {
        await every.keepAdam();
        final c = await screen.openTheApp(tester, size: size);
        await openAdam(tester);
        final state = c.read(workspaceProvider);
        final saved = _json(state.design);
        final work = state.work;
        final geometry = every.facets(every.painterOf<ModelPainter>(tester));
        expect(state.viewMode, ViewMode.realistic);

        // Where it is: in the top band, clear of the projection switch.
        final view = tester.getRect(find.byType(ModelView));
        final spread = find.byKey(ViewModeSwitch.keyOf(ViewMode.technical));
        final menu = find.byKey(ViewModeSwitch.menuKey);
        final switchRect = tester.getRect(find.byType(ViewModeSwitch));
        final projection = tester.getRect(
          find.byKey(const ValueKey('camera-perspective')),
        );
        final model = tester.getRect(
          find
              .descendant(
                of: find.byType(ModelView),
                matching: find.byType(CustomPaint),
              )
              .last,
        );
        expect(switchRect.left, greaterThanOrEqualTo(view.left));
        expect(
          switchRect.bottom,
          lessThanOrEqualTo(model.top + ModelView.controlsTop),
          reason: 'the model is framed clear of the band it is in',
        );
        expect(switchRect.overlaps(projection), isFalse);
        if (size == every.laptop) {
          expect(spread, findsOneWidget);
          expect(menu, findsNothing);
        } else {
          expect(menu, findsOneWidget);
          expect(spread, findsNothing);
        }

        for (final mode in [...ViewMode.shown, ViewMode.realistic]) {
          if (menu.evaluate().isNotEmpty) {
            await tester.tap(menu);
            await tester.pumpAndSettle();
          }
          await tester.tap(find.byKey(ViewModeSwitch.keyOf(mode)).last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final now = c.read(workspaceProvider);
          expect(now.viewMode, mode);
          final painter = every.painterOf<ModelPainter>(tester);
          expect(painter.mode, mode);
          expect(every.facets(painter), geometry, reason: '$mode');
          expect(painter.dimensions.isNotEmpty, mode.isTechnical);
          if (mode.isTechnical) {
            expect(
              painter.dimensions.map((d) => d.label),
              contains(
                Measurements.figure(
                  now.design.frame!.outline.width,
                  known: Measurements.knowsOverall(
                    now.design,
                    MeasureAxis.across,
                  ),
                  places: 1,
                ),
              ),
            );
          }
          expect(_json(now.design), saved, reason: '$mode');
          expect(identical(now.work, work), isTrue, reason: '$mode');
          expect(c.read(workspaceProvider.notifier).canUndo, isFalse);
        }
      });
    }

    testWidgets('under More the wireframe is offered too', (tester) async {
      await every.keepAdam();
      final c = await screen.openTheApp(tester, size: every.laptop);
      await openAdam(tester);
      expect(
        find.byKey(ViewModeSwitch.keyOf(ViewMode.wireframe)),
        findsNothing,
      );
      await showEverything(tester);
      // Five may not fit side by side; then the list holds them.
      final menu = find.byKey(ViewModeSwitch.menuKey);
      if (menu.evaluate().isNotEmpty) {
        await tester.tap(menu);
        await tester.pumpAndSettle();
      }
      await tester.tap(
        find.byKey(ViewModeSwitch.keyOf(ViewMode.wireframe)).last,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(c.read(workspaceProvider).viewMode, ViewMode.wireframe);
    });
  });
}

bool _listEq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
