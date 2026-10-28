import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/cad_painter.dart';
import 'package:proframe/app/canvas/cad_view.dart';
import 'package:proframe/app/canvas/design_painter.dart';
import 'package:proframe/app/canvas/drawing_surface.dart';
import 'package:proframe/app/canvas/view_controls.dart';
import 'package:proframe/app/canvas/view_transform.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/state/tools.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/app/theme/app_theme.dart';
import 'package:proframe/app/viewer/model_painter.dart';
import 'package:proframe/app/viewer/model_view.dart';
import 'package:proframe/app/viewer/view_mode.dart';
import 'package:proframe/domain/solid/camera.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a_customer_s_page_test.dart' as page;
import 'a_design_in_every_view_test.dart' as every;
import 'customers_screen_test.dart' as customers;
import 'materials_read_as_materials_test.dart' as showcase;
import 'the_designs_screen_test.dart' as screen;

// Phase 19 of the CAD and 3D work: the polish, where it was more than looks.
//
// Three views had three sets of zoom buttons — a column with a fit on the
// drawing, a column with no fit at the top of the technical drawing, a row
// with a fit and a reset on the model. There is one now, the same row in the
// same corner of all three. On the technical drawing the old one sat inside
// the drawing's own pointer handling, so a press on zoom was also a press on
// the drawing: it put down whatever part was picked and did not zoom. Laid
// over the drawing, a press on a button is a press on the button.
//
// The drawing and the technical drawing kept the framing a phone had given
// them when the window grew; they now refit to the room they have, as the
// model does, unless the user has moved the view.
//
// And the model outlines what is picked along the outside of the pick —
// where it was outlined round every facet it is built from, a heavy band of
// rings for every arris — and never tints it, because a tint over a finish
// reads as another finish.

const _phone = Size(390, 844);

Future<ProviderContainer> _openAdam(WidgetTester tester, Size size) async {
  await every.keepAdam();
  final c = await screen.openTheApp(tester, size: size);
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
  return c;
}

Rect _rectOf(WidgetTester tester, Type view) =>
    tester.getRect(find.byType(view).first);

ViewTransform _viewOf<T extends CustomPainter>(WidgetTester tester) {
  final painter = every.painterOf<T>(tester);
  return switch (painter) {
    CadPainter(:final view) => view,
    DesignPainter(:final view) => view,
    _ => throw StateError('$T'),
  };
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('one set of view controls', () {
    for (final (name, size) in [
      ('a laptop', every.laptop),
      ('a phone', _phone),
    ]) {
      testWidgets('on $name: the same row, in the same corner, on the '
          'drawing, the technical drawing and the model', (tester) async {
        await _openAdam(tester, size);
        final placed = <WorkspaceView, (double, double)>{};
        for (final (view, widget) in [
          (WorkspaceView.draw, DrawingSurface),
          (WorkspaceView.plan, CadView),
          (WorkspaceView.model, ModelView),
        ]) {
          await every.showView(tester, view);
          final controls = find.byType(ViewControls);
          expect(controls, findsOneWidget, reason: '$view');
          final at = tester.getRect(controls);
          final area = _rectOf(tester, widget);
          placed[view] = (area.right - at.right, area.bottom - at.bottom);
          for (final key in [
            ViewControls.inKey,
            ViewControls.outKey,
            ViewControls.fitKey,
          ]) {
            expect(find.byKey(key), findsOneWidget, reason: '$view $key');
          }
          expect(
            find.byKey(ViewControls.resetKey),
            view == WorkspaceView.model ? findsOneWidget : findsNothing,
            reason: 'only the model has a view it was first shown from',
          );
          // Zoom in, out and fit each do what they say.
          final c = ProviderScope.containerOf(
            tester.element(find.byType(ViewControls)),
          );
          double zoom() => switch (view) {
            WorkspaceView.model => c.read(workspaceProvider).camera.zoom,
            WorkspaceView.plan => _viewOf<CadPainter>(tester).scale,
            _ => _viewOf<DesignPainter>(tester).scale,
          };
          final was = zoom();
          await tester.tap(find.byKey(ViewControls.inKey));
          await tester.pumpAndSettle();
          expect(zoom(), greaterThan(was), reason: '$view in');
          await tester.tap(find.byKey(ViewControls.outKey));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(ViewControls.outKey));
          await tester.pumpAndSettle();
          expect(zoom(), lessThan(was), reason: '$view out');
          await tester.tap(find.byKey(ViewControls.fitKey));
          await tester.pumpAndSettle();
          expect(zoom(), closeTo(was, was * 1e-6), reason: '$view fit');
          expect(tester.takeException(), isNull);
        }
        // The same margins from the corner of each view.
        final first = placed.values.first;
        for (final MapEntry(key: view, value: at) in placed.entries) {
          expect(at.$1, closeTo(first.$1, 0.5), reason: '$view right');
          expect(at.$2, closeTo(first.$2, 0.5), reason: '$view bottom');
        }
      });
    }

    for (final view in [
      WorkspaceView.draw,
      WorkspaceView.plan,
      WorkspaceView.model,
    ]) {
      testWidgets('on the $view, a press on a control leaves what is '
          'picked picked, and the design as it was', (tester) async {
        final c = await _openAdam(tester, every.laptop);
        await every.showView(tester, view);
        final controller = c.read(workspaceProvider.notifier);
        final door = c.read(workspaceProvider).design;
        final picked = door.openings.single.sectionId;
        controller.select(picked);
        await tester.pumpAndSettle();
        final saved = jsonEncode(door.toJson());
        for (final key in [
          ViewControls.inKey,
          ViewControls.outKey,
          ViewControls.fitKey,
          if (view == WorkspaceView.model) ViewControls.resetKey,
        ]) {
          await tester.tap(find.byKey(key));
          await tester.pumpAndSettle();
          expect(
            c.read(workspaceProvider).selectedId,
            picked,
            reason: '$view $key put down what was picked',
          );
        }
        expect(jsonEncode(c.read(workspaceProvider).design.toJson()), saved);
        expect(controller.canUndo, isFalse);
      });
    }
  });

  group('the drawings refit when their room changes', () {
    for (final (view, type) in [
      (WorkspaceView.draw, DesignPainter),
      (WorkspaceView.plan, CadPainter),
    ]) {
      ViewTransform viewNow(WidgetTester tester) => type == CadPainter
          ? _viewOf<CadPainter>(tester)
          : _viewOf<DesignPainter>(tester);

      testWidgets('the $view, as fitted on a phone, is fitted again on a '
          'laptop', (tester) async {
        await _openAdam(tester, _phone);
        await every.showView(tester, view);
        final small = viewNow(tester).scale;
        await tester.binding.setSurfaceSize(every.laptop);
        await tester.pumpAndSettle();
        final large = viewNow(tester);
        expect(large.scale, greaterThan(small * 1.2));
        // And it is the fit: Fit changes nothing.
        await tester.tap(find.byKey(ViewControls.fitKey));
        await tester.pumpAndSettle();
        expect(viewNow(tester).isSameAs(large), isTrue);
      });

      testWidgets('the $view the user has zoomed stays as they left it', (
        tester,
      ) async {
        await _openAdam(tester, _phone);
        await every.showView(tester, view);
        await tester.tap(find.byKey(ViewControls.inKey));
        await tester.pumpAndSettle();
        final theirs = viewNow(tester).scale;
        await tester.binding.setSurfaceSize(every.laptop);
        await tester.pumpAndSettle();
        expect(viewNow(tester).scale, closeTo(theirs, theirs * 1e-9));
      });
    }
  });

  group('what is picked on the model', () {
    final d = showcase.showcase();
    const size = Size(900, 700);
    final mesh = MeshBuilder.build(d);
    final camera = Camera.front.framing(
      mesh,
      width: size.width,
      height: size.height,
    );

    Future<Uint8List> shoot({String? selectedId}) async {
      final recorder = ui.PictureRecorder();
      ModelPainter(
        faces: camera.project(mesh),
        size: size,
        viewSpan: Camera.viewSpan(mesh),
        mode: ViewMode.realistic,
        groundPlane: false,
        selectedId: selectedId,
      ).paint(Canvas(recorder), size);
      final image = await recorder.endRecording().toImage(
        size.width.round(),
        size.height.round(),
      );
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!.buffer.asUint8List();
    }

    bool gold(Uint8List rgba, int x, int y) {
      final i = (y * size.width.round() + x) * 4;
      final r = rgba[i], g = rgba[i + 1], b = rgba[i + 2];
      final s = Palette.light.selection;
      return (r - (s.r * 255)).abs() < 40 &&
          (g - (s.g * 255)).abs() < 40 &&
          (b - (s.b * 255)).abs() < 40;
    }

    test('the frame picked is outlined along its outside and its inside, '
        'not across its face', () async {
      final plain = await shoot();
      final picked = await shoot(selectedId: d.frame!.id);
      // Across the left jamb at mid height, from the backdrop to the
      // daylight: the outside of the frame and the inside of it.
      final eye = camera.eyeSpaceFor(mesh);
      final outline = d.frame!.outline;
      final inner = d.frame!.innerOutline;
      final painter = ModelPainter(
        faces: const [],
        size: size,
        viewSpan: Camera.viewSpan(mesh),
        mode: ViewMode.realistic,
      );
      final scale = 1 / painter.millimetresPerPixel;
      double screenX(double x) =>
          size.width / 2 +
          eye.place(Vec3(x, (outline.top + outline.bottom) / 2, 0))!.x * scale;
      final y =
          (size.height / 2 +
                  eye
                          .place(
                            Vec3(
                              outline.left,
                              (outline.top + outline.bottom) / 2,
                              0,
                            ),
                          )!
                          .y *
                      scale)
              .round();
      final from = screenX(outline.left).round() - 6;
      final to = screenX(inner.left).round() + 3;
      var runs = 0;
      var inRun = false;
      for (var x = from; x <= to; x++) {
        final on = gold(picked, x, y);
        if (on && !inRun) runs++;
        inRun = on;
      }
      // And over forty-one rows of it.
      var goldPixels = 0;
      for (var x = from; x <= to; x++) {
        for (var dy = -20; dy <= 20; dy++) {
          if (gold(picked, x, y + dy)) goldPixels++;
        }
      }
      // The outline is a line or two across each of these forty-one rows:
      // round every facet the jamb is built from — its arrises and its
      // sightline — it was a band of gold four times as heavy.
      expect(runs, inInclusiveRange(1, 2), reason: 'lines across the jamb');
      expect(goldPixels, inInclusiveRange(20, 100), reason: 'how much gold');
      // Not a pixel of the jamb's face between them is tinted.
      final middle = ((screenX(outline.left) + screenX(inner.left)) / 2)
          .round();
      final i = (y * size.width.round() + middle) * 4;
      expect(
        [picked[i], picked[i + 1], picked[i + 2]],
        [plain[i], plain[i + 1], plain[i + 2]],
      );
    });

    test('a pane picked keeps its own look: only its edge is drawn', () async {
      final pane = d.childSectionsOf(d.openings.single.sectionId).first;
      final plain = await shoot();
      final picked = await shoot(selectedId: pane.id);
      var changed = 0, inside = 0;
      final eye = camera.eyeSpaceFor(mesh);
      final painter = ModelPainter(
        faces: const [],
        size: size,
        viewSpan: Camera.viewSpan(mesh),
        mode: ViewMode.realistic,
      );
      final scale = 1 / painter.millimetresPerPixel;
      final o = pane.outline;
      final a = eye.place(Vec3(o.left, o.top, 0))!;
      final b = eye.place(Vec3(o.right, o.bottom, 0))!;
      final box = Rect.fromPoints(
        Offset(size.width / 2 + a.x * scale, size.height / 2 + a.y * scale),
        Offset(size.width / 2 + b.x * scale, size.height / 2 + b.y * scale),
      ).deflate(size.width * 0.03);
      for (var i = 0; i < plain.length; i += 4) {
        if (plain[i] == picked[i] &&
            plain[i + 1] == picked[i + 1] &&
            plain[i + 2] == picked[i + 2]) {
          continue;
        }
        changed++;
        final x = (i ~/ 4) % size.width.round();
        final y = (i ~/ 4) ~/ size.width.round();
        if (box.contains(Offset(x.toDouble(), y.toDouble()))) inside++;
      }
      expect(changed, greaterThan(100), reason: 'the pick is shown');
      expect(inside, 0, reason: 'nothing inside the pane is tinted');
    });
  });
}
