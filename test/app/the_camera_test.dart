import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/app/theme/app_theme.dart';
import 'package:proframe/app/viewer/model_painter.dart';
import 'package:proframe/app/viewer/model_view.dart';
import 'package:proframe/app/viewer/view_mode.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/solid/camera.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/rendering_geometry_baseline_test.dart' as base;

// Phase 9 of the CAD and 3D work: a camera to inspect the design with.
//
// The model is fitted to the view without being asked — when the view
// opens, when it changes size, and when the design's own size does — from a
// product photographer's view: turned a little, from a little above its
// middle, through a long lens that keeps it upright. It can be turned,
// zoomed towards the pointer, panned with two fingers, Shift or the middle
// button — at the pointer's own speed at every zoom — fitted again, reset,
// and looked at in perspective or orthographically. None of it is the
// design: the camera is the workspace's, and the design, its history and
// what is kept are untouched by every move of it.

const phone = Size(390, 640);
const laptop = Size(1200, 700);

/// The model's extent on the screen, in pixels, as [painter] paints it.
Rect onScreen(ModelPainter painter) {
  final scale =
      math.min(painter.size.width, painter.size.height) *
      Camera.spanShare /
      painter.viewSpan;
  var l = double.infinity, t = double.infinity;
  var r = -double.infinity, b = -double.infinity;
  for (final face in painter.faces) {
    for (final c in face.corners) {
      final x = painter.size.width / 2 + c.x * scale;
      final y = painter.size.height / 2 + c.y * scale;
      l = math.min(l, x);
      r = math.max(r, x);
      t = math.min(t, y);
      b = math.max(b, y);
    }
  }
  return Rect.fromLTRB(l, t, r, b);
}

/// The same for [camera] looking at [mesh] in a view [size] big.
Rect framedIn(Camera camera, Mesh mesh, Size size) => onScreen(
  ModelPainter(
    faces: camera.project(mesh),
    size: size,
    viewSpan: Camera.viewSpan(mesh),
    mode: ViewMode.realistic,
  ),
);

void expectFramed(
  Rect box,
  Size size, {
  String reason = '',
  double top = 0,
  double bottom = 0,
}) {
  final free = size.height - top - bottom;
  // Centred in the room the controls leave…
  expect(
    box.center.dx,
    closeTo(size.width / 2, size.width * 0.01),
    reason: '$reason: $box',
  );
  expect(
    box.center.dy,
    closeTo(top + free / 2, size.height * 0.01),
    reason: '$reason: $box',
  );
  // …as large as fits there, in whichever direction is tighter…
  final fills = math.max(box.width / size.width, box.height / free);
  expect(fills, closeTo(Camera.framedShare, 0.01), reason: '$reason: $box');
  // …and clear of the controls and the edges.
  expect(box.left, greaterThan(0), reason: reason);
  expect(box.top, greaterThan(top), reason: reason);
  expect(box.right, lessThan(size.width), reason: reason);
  expect(box.bottom, lessThan(size.height - bottom), reason: reason);
}

/// [expectFramed] in the model view, clear of its controls.
void expectFramedInView(Rect box, Size size, {String reason = ''}) =>
    expectFramed(
      box,
      size,
      reason: reason,
      top: ModelView.controlsTop,
      bottom: ModelView.controlsBottom,
    );

Future<ProviderContainer> showModel(
  WidgetTester tester,
  Design design, {
  Size size = phone,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(workspaceProvider.notifier).openDesign(design);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.build(),
        home: const Scaffold(body: ModelView()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

ModelPainter painterOf(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((p) => p.painter)
    .whereType<ModelPainter>()
    .single;

/// The view the model is painted in, on the screen.
Rect viewOf(WidgetTester tester) => tester.getRect(
  find.byWidgetPredicate((w) => w is CustomPaint && w.painter is ModelPainter),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final door = base.door();
  final window = base.window();

  group('the camera', () {
    test('the first view is a product photograph, not a distortion', () {
      const view = Camera.presentation;
      expect(view.projection, Projection.perspective);
      expect(view.yawDegrees, inInclusiveRange(20, 40), reason: 'turned');
      expect(
        view.pitchDegrees,
        inInclusiveRange(5, 15),
        reason: 'from a little above its middle',
      );
      // A long lens: the near jamb of a door is barely taller on the screen
      // than the far one.
      final faces = view.project(MeshBuilder.build(door));
      final outline = door.frame!.outline;
      double jamb(double x) {
        var top = double.infinity, bottom = -double.infinity;
        for (final f in faces) {
          for (var k = 0; k < f.corners.length; k++) {
            final c = f.source.corners[k];
            if ((c.x - x).abs() > 1e-6) continue;
            top = math.min(top, f.corners[k].y);
            bottom = math.max(bottom, f.corners[k].y);
          }
        }
        return bottom - top;
      }

      final ratio = jamb(outline.left) / jamb(outline.right);
      expect(
        math.max(ratio, 1 / ratio),
        lessThan(1.08),
        reason: 'no leaning door',
      );
      expect(
        math.max(ratio, 1 / ratio),
        greaterThan(1.001),
        reason: 'still a perspective',
      );
    });

    for (final (name, design) in [('door', door), ('window', window)]) {
      for (final size in [phone, laptop, const Size(700, 700)]) {
        test('$name framed in a ${size.width.round()}×'
            '${size.height.round()} view', () {
          final mesh = MeshBuilder.build(design);
          for (final projection in Projection.values) {
            final from = Camera.presentation.copyWith(
              projection: projection,
              yawDegrees: 50,
              zoom: 7,
            );
            final framed = from.framing(
              mesh,
              width: size.width,
              height: size.height,
            );
            expectFramed(
              framedIn(framed, mesh, size),
              size,
              reason: '$name ${projection.label}',
            );
            // Where it looks from and how it projects are kept.
            expect(framed.yawDegrees, from.yawDegrees);
            expect(framed.pitchDegrees, from.pitchDegrees);
            expect(framed.projection, projection);
            expect(framed.distanceInSpans, from.distanceInSpans);
          }
        });
      }
    }

    test(
      'framed clear of the controls over the top and the foot of the view',
      () {
        final mesh = MeshBuilder.build(door);
        for (final size in [phone, laptop]) {
          final framed = Camera.presentation.framing(
            mesh,
            width: size.width,
            height: size.height,
            top: 52,
            bottom: 60,
          );
          expectFramed(
            framedIn(framed, mesh, size),
            size,
            top: 52,
            bottom: 60,
            reason: '$size',
          );
        }
      },
    );

    test(
      'orthographic keeps parallel edges parallel; perspective does not',
      () {
        final mesh = MeshBuilder.build(door);
        final outline = door.frame!.outline;
        double jamb(Camera camera, double x) {
          var top = double.infinity, bottom = -double.infinity;
          for (final f in camera.project(mesh)) {
            for (var k = 0; k < f.corners.length; k++) {
              final c = f.source.corners[k];
              if ((c.x - x).abs() > 1e-6) continue;
              top = math.min(top, f.corners[k].y);
              bottom = math.max(bottom, f.corners[k].y);
            }
          }
          return bottom - top;
        }

        final ortho = Camera.presentation.copyWith(
          projection: Projection.parallel,
        );
        expect(
          jamb(ortho, outline.left),
          closeTo(jamb(ortho, outline.right), 1e-6),
        );
        expect(
          (jamb(Camera.presentation, outline.left) -
                  jamb(Camera.presentation, outline.right))
              .abs(),
          greaterThan(1),
        );
        expect(Projection.parallel.label, 'Orthographic');
      },
    );

    test('zooming towards a point keeps that point where it is', () {
      final mesh = MeshBuilder.build(door);
      final corner = door.frame!.outline.corners.first;
      // The corner of the frame's face nearest the viewer, where it is on
      // the screen, in millimetres from the middle of the view.
      Vec2Like seen(Camera c) {
        Vec2Like? best;
        var front = -double.infinity;
        for (final f in c.project(mesh)) {
          for (var k = 0; k < f.corners.length; k++) {
            final s = f.source.corners[k];
            if ((s.x - corner.x).abs() < 1e-6 &&
                (s.y - corner.y).abs() < 1e-6 &&
                s.z > front) {
              front = s.z;
              best = (x: f.corners[k].x / c.zoom, y: f.corners[k].y / c.zoom);
            }
          }
        }
        return best!;
      }

      // Exactly, orthographically; and in perspective as nearly as a point
      // not at the depth the view is centred on can be — its depth scales
      // it a few per cent more than a pan moves it, the way every modelling
      // program's zoom-to-pointer behaves.
      for (final (camera, slack) in [
        (Camera.presentation.copyWith(projection: Projection.parallel), 1e-6),
        (Camera.presentation, 0.08),
      ]) {
        final at = seen(camera);
        final zoomed = camera.zoomedToward(2.5, acrossMm: at.x, downMm: at.y);
        final after = seen(zoomed);
        expect(zoomed.zoom, closeTo(camera.zoom * 2.5, 1e-9));
        expect(
          after.x * zoomed.zoom,
          closeTo(at.x * camera.zoom, at.x.abs() * slack + 1e-6),
          reason: camera.projection.label,
        );
        expect(
          after.y * zoomed.zoom,
          closeTo(at.y * camera.zoom, at.y.abs() * slack + 1e-6),
          reason: camera.projection.label,
        );
        // Where zooming about the middle would have put it instead.
        expect(
          (at.x * zoomed.zoom - at.x * camera.zoom).abs(),
          greaterThan(at.x.abs() * 0.5),
        );
      }
    });
  });

  group('in the app', () {
    testWidgets('the model is fitted to the view the moment it opens', (
      tester,
    ) async {
      for (final size in [phone, laptop]) {
        final c = await showModel(tester, door, size: size);
        final view = viewOf(tester).size;
        expectFramedInView(onScreen(painterOf(tester)), view, reason: '$size');
        final camera = c.read(workspaceProvider).camera;
        expect(camera.yawDegrees, Camera.presentation.yawDegrees);
        expect(camera.pitchDegrees, Camera.presentation.pitchDegrees);
      }
    });

    testWidgets('a drag turns it; Shift, two fingers or the middle button '
        'pan it, at the pointer\'s own speed at every zoom', (tester) async {
      final c = await showModel(tester, door);
      final middle = viewOf(tester).center;

      final yaw = c.read(workspaceProvider).camera.yawDegrees;
      await tester.dragFrom(middle, const Offset(60, 0));
      await tester.pumpAndSettle();
      expect(c.read(workspaceProvider).camera.yawDegrees, isNot(yaw));

      for (final zoomIns in [0, 3]) {
        for (var i = 0; i < zoomIns; i++) {
          await tester.tap(find.byTooltip('Zoom in'));
          await tester.pumpAndSettle();
        }
        // Shift and drag: once the drag has begun, the model follows the
        // pointer exactly.
        final turned = c.read(workspaceProvider).camera.yawDegrees;
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        final gesture = await tester.startGesture(middle);
        await gesture.moveBy(const Offset(30, 0));
        await tester.pump();
        final before = onScreen(painterOf(tester)).center;
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(8, 5));
          await tester.pump();
        }
        final after = onScreen(painterOf(tester)).center;
        await gesture.up();
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
        expect(
          c.read(workspaceProvider).camera.yawDegrees,
          turned,
          reason: 'a pan does not turn it',
        );
        expect(after.dx - before.dx, closeTo(80, 3), reason: 'zoom $zoomIns');
        expect(after.dy - before.dy, closeTo(50, 3), reason: 'zoom $zoomIns');
      }

      // The middle button pans too.
      final before = onScreen(painterOf(tester)).center;
      final gesture = await tester.startGesture(
        middle,
        kind: PointerDeviceKind.mouse,
        buttons: kMiddleMouseButton,
      );
      await gesture.moveBy(const Offset(-40, 0));
      await gesture.moveBy(const Offset(-40, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        onScreen(painterOf(tester)).center.dx - before.dx,
        closeTo(-80, 6),
      );
    });

    testWidgets('the wheel zooms towards the pointer', (tester) async {
      final c = await showModel(tester, door, size: laptop);
      final view = viewOf(tester);
      final zoom = c.read(workspaceProvider).camera.zoom;
      final box = onScreen(painterOf(tester));
      // Over the top left of the model.
      final at = Offset(box.left + box.width * 0.2, box.top + box.height * 0.2);
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(at));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -40)));
      await tester.pumpAndSettle();
      expect(c.read(workspaceProvider).camera.zoom, greaterThan(zoom));
      // The model grew about the pointer, not about the middle of the view:
      // its top left corner moved away from the pointer by the zoom, and
      // not towards the middle.
      final after = onScreen(painterOf(tester));
      final f = c.read(workspaceProvider).camera.zoom / zoom;
      final expected = at + (box.topLeft - at) * f;
      expect(after.left, closeTo(expected.dx, box.width * 0.02));
      expect(after.top, closeTo(expected.dy, box.height * 0.02));
      expect(view.contains(at), isTrue);
    });

    testWidgets('Fit frames it again from where it is; Reset returns to the '
        'first view', (tester) async {
      final c = await showModel(tester, window, size: laptop);
      final view = viewOf(tester).size;
      await tester.dragFrom(viewOf(tester).center, const Offset(-90, 30));
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pumpAndSettle();
      final turned = c.read(workspaceProvider).camera;
      expect(turned.yawDegrees, isNot(Camera.presentation.yawDegrees));

      await tester.tap(find.byTooltip('Fit the model to the view'));
      await tester.pumpAndSettle();
      final fitted = c.read(workspaceProvider).camera;
      expect(fitted.yawDegrees, turned.yawDegrees, reason: 'kept');
      expect(fitted.pitchDegrees, turned.pitchDegrees, reason: 'kept');
      expectFramedInView(onScreen(painterOf(tester)), view, reason: 'fitted');

      await tester.tap(find.byTooltip('Reset the view'));
      await tester.pumpAndSettle();
      final reset = c.read(workspaceProvider).camera;
      expect(reset.yawDegrees, Camera.presentation.yawDegrees);
      expect(reset.pitchDegrees, Camera.presentation.pitchDegrees);
      expectFramedInView(onScreen(painterOf(tester)), view, reason: 'reset');
    });

    testWidgets('perspective and orthographic are one tap apart, named', (
      tester,
    ) async {
      final c = await showModel(tester, door);
      expect(find.text('Perspective'), findsOneWidget);
      expect(find.text('Orthographic'), findsOneWidget);
      await tester.tap(find.text('Orthographic'));
      await tester.pumpAndSettle();
      expect(c.read(workspaceProvider).camera.projection, Projection.parallel);
      await tester.tap(find.text('Perspective'));
      await tester.pumpAndSettle();
      expect(
        c.read(workspaceProvider).camera.projection,
        Projection.perspective,
      );
    });

    testWidgets('a view the user set is theirs until the view or the design '
        'changes size', (tester) async {
      final c = await showModel(tester, door);
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.dragFrom(viewOf(tester).center, const Offset(50, 0));
      await tester.pumpAndSettle();
      final mine = c.read(workspaceProvider).camera;

      // Away from the model and back: the same view.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: AppTheme.build(),
            home: const Scaffold(body: Text('elsewhere')),
          ),
        ),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: AppTheme.build(),
            home: const Scaffold(body: ModelView()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(c.read(workspaceProvider).camera.zoom, mine.zoom);
      expect(c.read(workspaceProvider).camera.yawDegrees, mine.yawDegrees);

      // The window changes size: fitted again, still from the user's side.
      tester.view.physicalSize = laptop;
      await tester.pumpAndSettle();
      expectFramedInView(
        onScreen(painterOf(tester)),
        viewOf(tester).size,
        reason: 'resized',
      );
      expect(c.read(workspaceProvider).camera.yawDegrees, mine.yawDegrees);
    });

    testWidgets('no move of the camera touches the design', (tester) async {
      final c = await showModel(tester, door);
      final design = jsonEncode(c.read(workspaceProvider).design.toJson());
      final middle = viewOf(tester).center;

      await tester.dragFrom(middle, const Offset(70, -20));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.dragFrom(middle, const Offset(30, 30));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(middle));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -40)));
      for (final tooltip in [
        'Zoom in',
        'Zoom out',
        'Fit the model to the view',
        'Reset the view',
      ]) {
        await tester.tap(find.byTooltip(tooltip));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Orthographic'));
      await tester.pumpAndSettle();

      final state = c.read(workspaceProvider);
      expect(jsonEncode(state.design.toJson()), design);
      expect(
        c.read(workspaceProvider.notifier).canUndo,
        isFalse,
        reason: 'nothing to undo: nothing was done to the design',
      );
      // And the solid it builds is the one it built.
      expect(
        base.meshGeometry(MeshBuilder.build(state.design)),
        base.meshGeometry(MeshBuilder.build(door)),
      );
    });
  });
}

typedef Vec2Like = ({double x, double y});
