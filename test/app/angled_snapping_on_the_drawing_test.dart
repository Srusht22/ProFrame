import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/cad_painter.dart';
import 'package:proframe/app/canvas/design_painter.dart';
import 'package:proframe/app/state/tools.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/app/viewer/model_painter.dart';
import 'package:proframe/domain/geometry/segment.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/angled_dimensions_test.dart' as angled;
import '../domain/geometry_normalizer_test.dart' show pen;
import 'a_design_in_every_view_test.dart' as every;
import 'angled_geometry_feedback_on_screen_test.dart' show openFor;
import 'new_design.dart' show showEverything;

// The original problem, on the real app with the pointer: on the technical
// drawing of an angled design, the end of a mullion that meets the sloped
// head is taken by its grip and dragged along the slope. With the Snap layer
// on it lands on the slope — at the slope's own angle, wherever along it the
// pointer is; with it off it lands exactly where the pointer is. Then Read
// again, Draw and 3D, and the snapped end is still on the slope.

/// [d] with its leaf said to be a window, so nothing is asked on opening.
Design said(Design d) =>
    d.withElement(d.openings.single.copyWith(kind: DesignKind.window));

Segment slopeOf(Design d) =>
    d.frame!.outline.edges.singleWhere((e) => e.a.x != e.b.x && e.a.y != e.b.y);

DividerElement mullionOf(Design d) =>
    d.dividers.singleWhere((b) => b.fromStrokeId == 'mullion');

Vec2 topOf(DividerElement bar) => bar.a.y < bar.b.y ? bar.a : bar.b;

(CadPainter, Offset) cad(WidgetTester tester) {
  final paint = find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter is CadPainter,
  );
  return (
    tester.widget<CustomPaint>(paint).painter! as CadPainter,
    tester.getTopLeft(paint),
  );
}

Offset screen(WidgetTester tester, Vec2 sheet) {
  final (painter, origin) = cad(tester);
  return origin + painter.view.toScreen(sheet);
}

/// The mullion picked and the end on the slope dragged to [to], along the
/// way a hand would take it.
Future<void> dragTopTo(
  WidgetTester tester,
  ProviderContainer c,
  Vec2 to,
) async {
  final design = c.read(workspaceProvider).design;
  final mullion = mullionOf(design);
  c.read(workspaceProvider.notifier).select(mullion.id);
  await tester.pumpAndSettle();
  final from = screen(tester, topOf(mullion));
  final end = screen(tester, to);
  final drag = await tester.startGesture(from);
  for (var i = 1; i <= 12; i++) {
    await drag.moveTo(Offset.lerp(from, end, i / 12)!);
    await tester.pump();
  }
  await drag.up();
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the end of a mullion dragged near the sloped head lands on '
      'it, and stays through Read again, Draw and 3D', (tester) async {
    final c = await openFor(tester, said(angled.drawn()));
    await every.showView(tester, WorkspaceView.plan);
    await showEverything(tester);
    final before = c.read(workspaceProvider).design;
    final slope = slopeOf(before);

    // A few pixels off the slope, outside the frame, 70 % of the way along
    // it: the outline's slope the nearest line, the daylight's a profile
    // further in.
    final (painter, _) = cad(tester);
    final off = painter.view.lengthToSheet(5);
    final target = slope.pointAt(0.7) - slope.unit.perpendicular * off;
    await dragTopTo(tester, c, target);

    final snapped = c.read(workspaceProvider).design;
    final top = topOf(mullionOf(snapped));
    expect(slope.distanceTo(top), lessThan(1e-6), reason: 'on the slope');
    expect(top.distanceTo(slope.pointAt(0.7)), lessThan(off * 1.5));
    expect(slopeOf(snapped), slope, reason: 'the slope kept its angle');
    expect(snapped.frame!.outline, before.frame!.outline, reason: '200 / 150');
    expect(
      snapped.childDividersOf(snapped.openings.single.sectionId),
      hasLength(1),
      reason: 'the opening keeps its own line',
    );

    // Read again: still on the slope.
    await tester.tap(find.text('Read again'));
    await tester.pumpAndSettle();
    final read = c.read(workspaceProvider).design;
    expect(identical(read, snapped), isFalse, reason: 'the sheet was read');
    expect(slope.distanceTo(topOf(mullionOf(read))), lessThan(0.5));
    expect(read.frame!.outline, before.frame!.outline);

    // Every view draws that design.
    expect(identical(every.painterOf<CadPainter>(tester).design, read), isTrue);
    await every.showView(tester, WorkspaceView.draw);
    expect(
      identical(every.painterOf<DesignPainter>(tester).design, read),
      isTrue,
    );
    await every.showView(tester, WorkspaceView.model);
    expect(
      every.facets(every.painterOf<ModelPainter>(tester)),
      every.projected(c, read),
    );
  });

  testWidgets('with Snap off, the end lands exactly where the pointer has '
      'it — snapping is help, never a rule', (tester) async {
    final c = await openFor(tester, said(angled.drawn()));
    await every.showView(tester, WorkspaceView.plan);
    final controller = c.read(workspaceProvider.notifier);
    controller.setLayers(
      c.read(workspaceProvider).layers.copyWith(snap: false),
    );
    await tester.pumpAndSettle();
    final slope = slopeOf(c.read(workspaceProvider).design);
    final (painter, _) = cad(tester);
    final off = painter.view.lengthToSheet(5);
    final target = slope.pointAt(0.7) - slope.unit.perpendicular * off;
    await dragTopTo(tester, c, target);
    final top = topOf(mullionOf(c.read(workspaceProvider).design));
    expect(slope.distanceTo(top), greaterThan(off * 0.5), reason: 'off it');
  });

  testWidgets('a door keeps the axis snapping it had: a lower mullion '
      'dragged near the upper one\'s line lands in line with it', (
    tester,
  ) async {
    final door = SketchInterpreter.interpret(
      Design.empty(id: 'door', kind: DesignKind.door).copyWith(
        name: 'Garden Door',
        sketch: Sketch(
          strokes: [
            pen('outline', const [
              Vec2(0, 0),
              Vec2(1600, 0),
              Vec2(1600, 2100),
              Vec2(0, 2100),
              Vec2(0, 0),
            ]),
            pen('transom', const [Vec2(0, 600), Vec2(1600, 600)]),
            pen('upper', const [Vec2(500, 0), Vec2(500, 600)]),
            pen('lower', const [Vec2(1100, 600), Vec2(1100, 2100)]),
          ],
        ),
      ),
    ).design;
    final c = await openFor(tester, door);
    await every.showView(tester, WorkspaceView.plan);
    final d = c.read(workspaceProvider).design;
    final lower = d.dividers.singleWhere((b) => b.fromStrokeId == 'lower');
    c.read(workspaceProvider.notifier).select(lower.id);
    await tester.pumpAndSettle();
    final (painter, _) = cad(tester);
    final from = screen(tester, lower.segment.midpoint);
    // Two pixels from the upper mullion's centre line, nearer that than
    // either of its faces.
    final near = painter.view.lengthToSheet(2);
    final to = screen(tester, Vec2(500 + near, lower.segment.midpoint.y));
    final drag = await tester.startGesture(from);
    for (var i = 1; i <= 12; i++) {
      await drag.moveTo(Offset.lerp(from, to, i / 12)!);
      await tester.pump();
    }
    await drag.up();
    await tester.pumpAndSettle();
    final now = c.read(workspaceProvider).design.dividerById(lower.id)!;
    expect((now.a.x + now.b.x) / 2, closeTo(500, 1e-6));
    expect(now.isVertical, isTrue);
  });
}
