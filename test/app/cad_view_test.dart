import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/app.dart';
import 'package:proframe/app/canvas/cad_layers.dart';
import 'package:proframe/app/state/tools.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/sections/section_builder.dart';
import 'package:proframe/domain/sketch/stroke.dart';

import 'new_design.dart';

ProviderContainer makeContainer() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

/// A drawn, read design with a deliberately off-centre bar and a transom on
/// one side only — the sort of thing a template would never produce.
WorkspaceController lopsided(ProviderContainer container) {
  final controller = container.read(workspaceProvider.notifier)
    ..startDesign(DesignKind.window)
    ..addStroke(
      const [
        StrokeSample(Vec2(0, 0)),
        StrokeSample(Vec2(1400, 0)),
        StrokeSample(Vec2(1400, 2000)),
        StrokeSample(Vec2(0, 2000)),
        StrokeSample(Vec2(0, 0)),
      ],
      tool: Tool.pen,
    )
    ..addStroke(
      const [StrokeSample(Vec2(430, 0)), StrokeSample(Vec2(430, 2000))],
      tool: Tool.pen,
    )
    ..addStroke(
      const [StrokeSample(Vec2(0, 760)), StrokeSample(Vec2(430, 760))],
      tool: Tool.pen,
    )
    ..readDrawing();
  return controller;
}

Design withBar({required double atX}) {
  final at = DateTime(2026);
  return SectionBuilder.rebuild(Design(
    id: 'd',
    name: 'test',
    kind: DesignKind.window,
    createdAt: at,
    updatedAt: at,
    frame: FrameElement(
      id: 'f',
      outline: Polygon.rect(0, 0, 1000, 2000),
      profileMm: 50,
    ),
    dividers: [
      DividerElement(
        id: 'm',
        a: Vec2(atX, 0),
        b: Vec2(atX, 2000),
        widthMm: 40,
      ),
    ],
  ));
}

void main() {
  group('opening the CAD drawing changes nothing', () {
    test('the design is identical before and after switching to it', () {
      final container = makeContainer();
      final controller = lopsided(container);

      final before =
          container.read(workspaceProvider).design.toJson().toString();
      controller.showView(WorkspaceView.plan);
      final after =
          container.read(workspaceProvider).design.toJson().toString();

      expect(after, before);
    });

    test('turning every layer off and on changes nothing', () {
      final container = makeContainer();
      final controller = lopsided(container);
      final before =
          container.read(workspaceProvider).design.toJson().toString();

      controller
        ..setLayers(const CadLayers(
          grid: false,
          dimensions: false,
          hatching: false,
          openings: false,
          annotations: false,
          grips: false,
          snap: false,
        ))
        ..setLayers(const CadLayers(centreLines: true, sketch: true));

      expect(
        container.read(workspaceProvider).design.toJson().toString(),
        before,
      );
    });

    test('the sections stay unequal, and the transom stays on one side', () {
      final container = makeContainer();
      lopsided(container).showView(WorkspaceView.plan);
      final design = container.read(workspaceProvider).design;

      expect(design.sections, hasLength(3));
      final widths = [for (final s in design.sections) s.widthMm.round()];
      expect(widths.toSet().length, greaterThan(1),
          reason: 'the columns must not have been equalised');

      // Two short sections on the left of the bar, one tall one on the right.
      final left = design.sections.where((s) => s.outline.right < 430).length;
      final right = design.sections.where((s) => s.outline.left > 430).length;
      expect(left, 2);
      expect(right, 1);
    });
  });

  group('editable boundaries', () {
    test('dragging a bar moves that bar only', () {
      final container = makeContainer();
      final controller = lopsided(container);
      final bar = container.read(workspaceProvider).design.dividers
          .firstWhere((d) => d.isVertical);

      controller.moveDividerTo(bar.id, const Vec2(700, 1000));
      final moved = container
          .read(workspaceProvider)
          .design
          .dividers
          .firstWhere((d) => d.id == bar.id);

      expect(moved.a.x, closeTo(700, 1));
      expect(moved.b.x, closeTo(700, 1));
      // It is still the full height it was drawn at.
      expect((moved.b.y - moved.a.y).abs(), closeTo(2000, 1));
    });

    test('dragging the head of the frame leaves the bars where they are', () {
      final container = makeContainer();
      final controller = lopsided(container);
      final barBefore = container
          .read(workspaceProvider)
          .design
          .dividers
          .firstWhere((d) => d.isVertical);

      controller.moveFrameEdge(FrameEdge.top, -300);

      final design = container.read(workspaceProvider).design;
      expect(design.frame!.outline.top, closeTo(-300, 1));
      final barAfter =
          design.dividers.firstWhere((d) => d.id == barBefore.id);
      expect(barAfter.a.x, closeTo(barBefore.a.x, 0.01));
      expect(barAfter.a.y, closeTo(barBefore.a.y, 0.01));
    });

    test('the frame cannot be dragged inside out', () {
      final container = makeContainer();
      final controller = lopsided(container);
      controller.moveFrameEdge(FrameEdge.right, -5000);
      final frame = container.read(workspaceProvider).design.frame!;
      expect(frame.widthMm, greaterThan(0));
      expect(frame.outline.right, greaterThan(frame.outline.left));
    });

    test('a grip drag is one step on the way back', () {
      final container = makeContainer();
      final controller = lopsided(container);
      final bar = container.read(workspaceProvider).design.dividers
          .firstWhere((d) => d.isVertical);
      final startedAt = bar.a.x;

      for (var x = 440.0; x <= 700; x += 10) {
        controller.moveDividerTo(bar.id, Vec2(x, 1000));
      }
      controller.endGesture();
      controller.undo();

      final back = container
          .read(workspaceProvider)
          .design
          .dividers
          .firstWhere((d) => d.id == bar.id);
      expect(back.a.x, closeTo(startedAt, 0.5));
    });
  });

  group('snapping', () {
    test('only offers positions where something already is', () {
      final design = withBar(atX: 330);
      final candidates =
          DesignEdits.snapCandidates(design, horizontal: true);

      // The frame's own edges, the daylight edges, and the bar's faces and
      // centre. Nothing else.
      expect(candidates, contains(closeTo(0, 0.01)));
      expect(candidates, contains(closeTo(1000, 0.01)));
      expect(candidates, contains(closeTo(330, 0.01)));
      expect(candidates, contains(closeTo(310, 0.01)));
      expect(candidates, contains(closeTo(350, 0.01)));

      // Emphatically not the middle, and not a third of the way across:
      // snapping to those would pull the design towards symmetry.
      expect(candidates.any((c) => (c - 500).abs() < 0.5), isFalse);
      expect(candidates.any((c) => (c - 333.33).abs() < 0.5), isFalse);
      expect(candidates.any((c) => (c - 666.67).abs() < 0.5), isFalse);
    });

    test('a bar being dragged does not snap to itself', () {
      final design = withBar(atX: 330);
      final candidates = DesignEdits.snapCandidates(
        design,
        horizontal: true,
        ignoreId: 'm',
      );
      expect(candidates.any((c) => (c - 330).abs() < 0.5), isFalse);
    });

    test('nothing is snapped to when nothing is near', () {
      final design = withBar(atX: 330);
      final candidates =
          DesignEdits.snapCandidates(design, horizontal: true);
      expect(DesignEdits.snapTo(candidates, 620, withinMm: 12), isNull);
      expect(
        DesignEdits.snapTo(candidates, 334, withinMm: 12),
        closeTo(330, 0.01),
      );
    });
  });

  group('overruling a mark sticks', () {
    test('setting a marked section back to fixed survives reading again', () {
      final container = makeContainer();
      final controller = container.read(workspaceProvider.notifier)
        ..startDesign(DesignKind.door)
        ..addStroke(
          const [
            StrokeSample(Vec2(0, 0)),
            StrokeSample(Vec2(1000, 0)),
            StrokeSample(Vec2(1000, 2200)),
            StrokeSample(Vec2(0, 2200)),
            StrokeSample(Vec2(0, 0)),
          ],
          tool: Tool.pen,
        )
        ..addStroke(
          const [
            StrokeSample(Vec2(380, 900)),
            StrokeSample(Vec2(640, 1100)),
            StrokeSample(Vec2(380, 1300)),
          ],
          tool: Tool.pen,
        )
        ..readDrawing();

      var design = container.read(workspaceProvider).design;
      expect(design.openings, hasLength(1));
      final section = design.sections.single;

      // The user overrules their own mark.
      controller.setOpening(section.id, OpeningMechanism.fixed);
      expect(container.read(workspaceProvider).design.openings, isEmpty);

      // And it stays overruled, rather than the mark putting it straight
      // back the next time the drawing is read.
      controller.readDrawing();
      design = container.read(workspaceProvider).design;
      expect(design.openings, isEmpty);
    });

    test('overruled, the mark is built as the lines it is', () {
      final container = makeContainer();
      final controller = container.read(workspaceProvider.notifier)
        ..startDesign(DesignKind.window)
        ..addStroke(
          const [
            StrokeSample(Vec2(0, 0)),
            StrokeSample(Vec2(1200, 0)),
            StrokeSample(Vec2(1200, 1200)),
            StrokeSample(Vec2(0, 1200)),
            StrokeSample(Vec2(0, 0)),
          ],
          tool: Tool.pen,
        )
        ..addStroke(
          const [
            StrokeSample(Vec2(300, 300)),
            StrokeSample(Vec2(700, 600)),
            StrokeSample(Vec2(300, 900)),
          ],
          tool: Tool.pen,
        )
        ..readDrawing();

      expect(container.read(workspaceProvider).design.openings, hasLength(1));
      final section = container.read(workspaceProvider).design.sections.single;

      controller
        ..setOpening(section.id, OpeningMechanism.fixed)
        ..readDrawing();

      final design = container.read(workspaceProvider).design;
      expect(design.openings, isEmpty);
      // Having been told it is not a mark, it is built exactly as drawn.
      expect(design.dividers, hasLength(2));
      expect(design.sketch.strokes, hasLength(2));
    });

    test('erasing the mark takes the opening with it', () {
      final container = makeContainer();
      final controller = container.read(workspaceProvider.notifier)
        ..startDesign(DesignKind.door)
        ..addStroke(
          const [
            StrokeSample(Vec2(0, 0)),
            StrokeSample(Vec2(1000, 0)),
            StrokeSample(Vec2(1000, 2200)),
            StrokeSample(Vec2(0, 2200)),
            StrokeSample(Vec2(0, 0)),
          ],
          tool: Tool.pen,
        )
        ..addStroke(
          const [
            StrokeSample(Vec2(380, 900)),
            StrokeSample(Vec2(640, 1100)),
            StrokeSample(Vec2(380, 1300)),
          ],
          tool: Tool.pen,
        )
        ..readDrawing();

      expect(container.read(workspaceProvider).design.openings, hasLength(1));

      final mark =
          container.read(workspaceProvider).design.sketch.strokes.last.id;
      controller
        ..eraseStroke(mark)
        ..readDrawing();

      final design = container.read(workspaceProvider).design;
      expect(design.openings, isEmpty);
      expect(design.sketch.strokes, hasLength(1));
    });
  });

  testWidgets('the CAD drawing shows its layers and its status bar',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    late WidgetRef captured;
    await tester.pumpWidget(ProviderScope(
      child: Consumer(builder: (context, ref, _) {
        captured = ref;
        return const ProFrameApp();
      }),
    ));
    await tester.pumpAndSettle();
    await toTheCategories(tester);
    await chooseDesign(tester, 'WINDOW');

    lopsided(ProviderContainer());
    captured.read(workspaceProvider.notifier)
      ..addStroke(
        const [
          StrokeSample(Vec2(0, 0)),
          StrokeSample(Vec2(1400, 0)),
          StrokeSample(Vec2(1400, 2000)),
          StrokeSample(Vec2(0, 2000)),
          StrokeSample(Vec2(0, 0)),
        ],
        tool: Tool.pen,
      )
      ..readDrawing();
    await tester.pumpAndSettle();

    expect(find.text('CAD drawing'), findsOneWidget);
    expect(find.text('Dimensions'), findsOneWidget);
    expect(find.text('Hatching'), findsOneWidget);
    expect(find.text('Openings'), findsOneWidget);
    expect(find.text('Snap'), findsOneWidget);
    expect(find.text('Handles'), findsOneWidget);
    expect(find.textContaining('1 sections · 0 bars'), findsOneWidget);
  });
}
