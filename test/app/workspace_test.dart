import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/state/tools.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/sketch/stroke.dart';

ProviderContainer makeContainer() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

/// Samples along a path, wobbled like a hand.
List<StrokeSample> along(List<Vec2> through, {double wobble = 6}) {
  var seed = 3;
  double next() {
    seed = (seed * 1103515245 + 12345) % 2147483648;
    return seed / 2147483648 - 0.5;
  }

  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 12; i++) {
      final at = through[leg].lerp(through[leg + 1], i / 12);
      samples.add(StrokeSample(
        Vec2(at.x + next() * wobble, at.y + next() * wobble),
      ));
    }
  }
  samples.add(StrokeSample(through.last));
  return samples;
}

void main() {
  group('drawing and reading', () {
    test('a new design is empty — nothing is there to start with', () {
      final container = makeContainer();
      final controller = container.read(workspaceProvider.notifier)
        ..startDesign(DesignKind.window);
      final state = container.read(workspaceProvider);

      expect(state.design.frame, isNull);
      expect(state.design.sections, isEmpty);
      expect(state.design.sketch.isEmpty, isTrue);
      expect(controller.canUndo, isFalse);
    });

    test('drawing a box and reading it gives one section', () {
      final container = makeContainer();
      final controller = container.read(workspaceProvider.notifier)
        ..startDesign(DesignKind.window)
        ..addStroke(
          along(const [
            Vec2(0, 0),
            Vec2(1000, 0),
            Vec2(1000, 2000),
            Vec2(0, 2000),
            Vec2(0, 0),
          ]),
          tool: Tool.pen,
        );

      expect(container.read(workspaceProvider).needsReading, isTrue);
      controller.readDrawing();

      final state = container.read(workspaceProvider);
      expect(state.design.frame, isNotNull);
      expect(state.design.sections, hasLength(1));
      expect(state.needsReading, isFalse);
      expect(state.view, WorkspaceView.plan);
    });

    test('the ink survives reading, and survives editing afterwards', () {
      final container = makeContainer();
      final controller = container.read(workspaceProvider.notifier)
        ..startDesign(DesignKind.door)
        ..addStroke(
          along(const [
            Vec2(0, 0),
            Vec2(900, 0),
            Vec2(900, 2100),
            Vec2(0, 2100),
            Vec2(0, 0),
          ]),
          tool: Tool.pen,
        )
        ..readDrawing();

      expect(container.read(workspaceProvider).design.sketch.strokes,
          hasLength(1));

      controller
        ..resizeFrame(widthMm: 1400)
        ..setRealWidth(2000);

      expect(container.read(workspaceProvider).design.sketch.strokes,
          hasLength(1));
    });

    test('undo puts back what was there before', () {
      final container = makeContainer();
      final controller = container.read(workspaceProvider.notifier)
        ..startDesign(DesignKind.window)
        ..addStroke(
          along(const [Vec2(0, 0), Vec2(500, 0)]),
          tool: Tool.pen,
        );

      expect(container.read(workspaceProvider).design.sketch.strokes,
          hasLength(1));
      controller.undo();
      expect(container.read(workspaceProvider).design.sketch.isEmpty, isTrue);
      controller.redo();
      expect(container.read(workspaceProvider).design.sketch.strokes,
          hasLength(1));
    });

    test('a drag is one step on the way back, not a hundred', () {
      final container = makeContainer();
      final controller = container.read(workspaceProvider.notifier)
        ..startDesign(DesignKind.window)
        ..addStroke(
          along(const [
            Vec2(0, 0),
            Vec2(1000, 0),
            Vec2(1000, 2000),
            Vec2(0, 2000),
            Vec2(0, 0),
          ]),
          tool: Tool.pen,
        )
        ..addStroke(along(const [Vec2(400, 0), Vec2(400, 2000)]),
            tool: Tool.pen)
        ..readDrawing();

      final divider =
          container.read(workspaceProvider).design.dividers.single;
      controller.select(divider.id);

      final before =
          container.read(workspaceProvider).design.dividers.single.a.x;
      for (var i = 0; i < 25; i++) {
        controller.dragSelected(const Vec2(4, 0));
      }
      controller.endGesture();

      final after =
          container.read(workspaceProvider).design.dividers.single.a.x;
      expect(after, greaterThan(before));

      controller.undo();
      expect(
        container.read(workspaceProvider).design.dividers.single.a.x,
        closeTo(before, 0.01),
      );
    });

    test('erasing a mark takes the geometry read from it too', () {
      final container = makeContainer();
      final controller = container.read(workspaceProvider.notifier)
        ..startDesign(DesignKind.window)
        ..addStroke(
          along(const [
            Vec2(0, 0),
            Vec2(1000, 0),
            Vec2(1000, 2000),
            Vec2(0, 2000),
            Vec2(0, 0),
          ]),
          tool: Tool.pen,
        )
        ..addStroke(along(const [Vec2(400, 0), Vec2(400, 2000)]),
            tool: Tool.pen)
        ..readDrawing();

      var state = container.read(workspaceProvider);
      expect(state.design.dividers, hasLength(1));
      final barStroke = state.design.dividers.single.fromStrokeId!;

      controller.eraseStroke(barStroke);
      state = container.read(workspaceProvider);
      expect(state.design.dividers, isEmpty);
      expect(state.design.sketch.strokes, hasLength(1));
      expect(state.design.sections, hasLength(1));
    });
  });

  group('nothing is invented', () {
    test('a diagonal opens nothing until the user says it does', () {
      final container = makeContainer();
      final controller = container.read(workspaceProvider.notifier)
        ..startDesign(DesignKind.window)
        ..addStroke(
          along(const [
            Vec2(0, 0),
            Vec2(1000, 0),
            Vec2(1000, 2000),
            Vec2(0, 2000),
            Vec2(0, 0),
          ]),
          tool: Tool.pen,
        )
        ..addStroke(
          along(const [Vec2(80, 1900), Vec2(900, 1000)], wobble: 3),
          tool: Tool.pen,
        )
        ..readDrawing();

      var state = container.read(workspaceProvider);
      expect(state.design.openings, isEmpty);
      expect(state.questions, isEmpty,
          reason: 'the line is built; nothing is asked about it');

      // The user says, from the bar's own panel, that they meant an opening.
      controller.openSectionOfBar(
        state.design.dividers.single.id,
        OpeningMechanism.hingedRight,
      );

      state = container.read(workspaceProvider);
      expect(state.design.openings, hasLength(1));
      expect(state.design.openings.single.mechanism,
          OpeningMechanism.hingedRight);
      expect(state.design.openings.single.confirmed, isTrue);
      // The line it stood for is gone; the opening took its place.
      expect(state.design.dividers, isEmpty);
      expect(state.questions, isEmpty);
    });

    test('leaving a diagonal alone leaves the line alone', () {
      final container = makeContainer();
      final controller = container.read(workspaceProvider.notifier)
        ..startDesign(DesignKind.window)
        ..addStroke(
          along(const [
            Vec2(0, 0),
            Vec2(1000, 0),
            Vec2(1000, 2000),
            Vec2(0, 2000),
            Vec2(0, 0),
          ]),
          tool: Tool.pen,
        )
        ..addStroke(
          along(const [Vec2(80, 1900), Vec2(900, 1000)], wobble: 3),
          tool: Tool.pen,
        )
        ..readDrawing();

      final before = container.read(workspaceProvider).design;

      // Nothing is asked and nothing is decided: reading the drawing leaves
      // the line exactly as it was drawn, opening nothing.
      expect(container.read(workspaceProvider).questions, isEmpty);
      expect(before.openings, isEmpty);

      // And it stays that way until the user says otherwise.
      controller.select(before.dividers.single.id);
      final after = container.read(workspaceProvider).design;
      expect(after.openings, isEmpty);
      expect(after.dividers.length, before.dividers.length);
      expect(after.dividers.single.a.x, closeTo(before.dividers.single.a.x, 0.01));
    });

    test('no hardware appears unless it is added', () {
      final container = makeContainer();
      final controller = container.read(workspaceProvider.notifier)
        ..startDesign(DesignKind.door)
        ..addStroke(
          along(const [
            Vec2(0, 0),
            Vec2(900, 0),
            Vec2(900, 2100),
            Vec2(0, 2100),
            Vec2(0, 0),
          ]),
          tool: Tool.pen,
        )
        ..readDrawing();

      expect(container.read(workspaceProvider).design.hardware, isEmpty);

      controller.addHardware(HardwareKind.lever, const Vec2(820, 1050));
      final hardware = container.read(workspaceProvider).design.hardware;
      expect(hardware, hasLength(1));
      expect(hardware.single.at.x, 820);
      expect(hardware.single.at.y, 1050);
    });

    test('a colour set on one section does not spread to the others', () {
      final container = makeContainer();
      final controller = container.read(workspaceProvider.notifier)
        ..startDesign(DesignKind.window)
        ..addStroke(
          along(const [
            Vec2(0, 0),
            Vec2(1200, 0),
            Vec2(1200, 2000),
            Vec2(0, 2000),
            Vec2(0, 0),
          ]),
          tool: Tool.pen,
        )
        ..addStroke(along(const [Vec2(350, 0), Vec2(350, 2000)]),
            tool: Tool.pen)
        ..readDrawing();

      final sections = container.read(workspaceProvider).design.sections;
      expect(sections, hasLength(2));

      controller.setFinish(
        sections.first.id,
        const Finish(colour: 0xFF8C1E20, material: MaterialKind.panel),
      );

      final after = container.read(workspaceProvider).design.sections;
      expect(after.firstWhere((s) => s.id == sections.first.id).finish.colour,
          0xFF8C1E20);
      expect(after.firstWhere((s) => s.id == sections.last.id).finish.colour,
          isNot(0xFF8C1E20));
    });

    test('reading twice gives the same design', () {
      final container = makeContainer();
      final controller = container.read(workspaceProvider.notifier)
        ..startDesign(DesignKind.window)
        ..addStroke(
          along(const [
            Vec2(0, 0),
            Vec2(1100, 0),
            Vec2(1100, 1700),
            Vec2(0, 1700),
            Vec2(0, 0),
          ]),
          tool: Tool.pen,
        )
        ..addStroke(along(const [Vec2(290, 0), Vec2(290, 1700)]),
            tool: Tool.pen)
        ..readDrawing();

      final once = container.read(workspaceProvider).design;
      controller.readDrawing();
      final twice = container.read(workspaceProvider).design;

      expect(twice.sections.length, once.sections.length);
      expect(twice.dividers.length, once.dividers.length);
      expect(twice.frame!.widthMm, closeTo(once.frame!.widthMm, 0.01));
      for (var i = 0; i < once.sections.length; i++) {
        expect(twice.sections[i].widthMm,
            closeTo(once.sections[i].widthMm, 0.01));
      }
    });
  });

  group('saving', () {
    test('a design survives being written out and read back', () {
      final container = makeContainer();
      container.read(workspaceProvider.notifier)
        ..startDesign(DesignKind.door)
        ..addStroke(
          along(const [
            Vec2(0, 0),
            Vec2(900, 0),
            Vec2(900, 2100),
            Vec2(0, 2100),
            Vec2(0, 0),
          ]),
          tool: Tool.pen,
        )
        ..readDrawing()
        ..addHardware(HardwareKind.lever, const Vec2(820, 1050));

      final before = container.read(workspaceProvider).design;
      final after = Design.fromJson(before.toJson());

      expect(after.id, before.id);
      expect(after.kind, before.kind);
      expect(after.sketch.strokes, hasLength(before.sketch.strokes.length));
      expect(after.sections, hasLength(before.sections.length));
      expect(after.hardware.single.at.x, 820);
      expect(after.frame!.widthMm, closeTo(before.frame!.widthMm, 0.01));
    });
  });
}
