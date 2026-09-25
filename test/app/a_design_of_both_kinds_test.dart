import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/app.dart';
import 'package:proframe/app/inspector/alert_layer.dart';
import 'package:proframe/app/inspector/opening_kind_alert.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/sketch/stroke.dart';

import 'new_design.dart';

// A third thing to start from, beside a door and a window: an assembly that
// holds leaves of each kind.
//
//   ┌──────────┬──────────┬──────────┐
//   │  FIXED   │    >     │    >     │
//   └──────────┴──────────┴──────────┘
//                a door    a window
//
// **It is the kind that has no default, and that is the whole of what it
// means.** A door design says its leaves are doors until the user says
// otherwise; a window design says the same. An assembly the user has told
// us holds both says nothing about any particular leaf — so nothing is
// assumed for one, and the question about each is put as an alert over the
// workspace with the work behind it blurred back.
//
// What is built for an unanswered leaf is what the mark alone says: it
// opens, so it hangs on its hinges. It carries no handle, because which
// handle is precisely the question outstanding.

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 30; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 30)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

List<Vec2> chevron(Vec2 at, {double size = 110}) => [
      Vec2(at.x - size / 2, at.y - size),
      Vec2(at.x + size / 2, at.y),
      Vec2(at.x - size / 2, at.y + size),
    ];

/// A fixed light and two marked ones.
Sketch sheet() => Sketch(strokes: [
      pen('outline', const [
        Vec2(0, 0),
        Vec2(3600, 0),
        Vec2(3600, 2100),
        Vec2(0, 2100),
        Vec2(0, 0),
      ]),
      pen('mull1', const [Vec2(1200, 0), Vec2(1200, 2100)]),
      pen('mull2', const [Vec2(2400, 0), Vec2(2400, 2100)]),
      pen('k1', chevron(const Vec2(1800, 1050))),
      pen('k2', chevron(const Vec2(3000, 1050))),
    ]);

ProviderContainer makeContainer() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

WorkspaceController read({DesignKind kind = DesignKind.both}) {
  final controller = makeContainer().read(workspaceProvider.notifier)
    ..startDesign(kind);
  controller.state = controller.state.copyWith(
    design: controller.state.design.copyWith(sketch: sheet()),
  );
  controller.readDrawing();
  return controller;
}

List<HardwareElement> on(Design design, String openingId) => [
      for (final piece in design.hardware)
        if (design.openingHolding(piece.parentId)?.id == openingId) piece,
    ];

void main() {
  group('a design that holds both kinds', () {
    test('it is a third thing to start from, and a leaf is never it', () {
      expect(DesignKind.values, contains(DesignKind.both));
      // A leaf is a door or a window. `both` describes the assembly, so it
      // is not among the answers to what one opening is.
      expect(DesignKind.leafKinds, [DesignKind.door, DesignKind.window]);
      expect(DesignKind.leafKinds, isNot(contains(DesignKind.both)));

      expect(DesignKind.door.leafDefault, DesignKind.door);
      expect(DesignKind.window.leafDefault, DesignKind.window);
      expect(DesignKind.both.leafDefault, isNull,
          reason: 'it is the kind with nothing for a leaf to follow');
    });

    test('a door and a window can stand in one frame', () {
      final c = read();
      final design = c.state.design;
      expect(design.kind, DesignKind.both);
      expect(design.topLevelSections, hasLength(3));
      expect(design.openings, hasLength(2));

      final order = design.openingsInOrder;
      c
        ..setOpeningKind(order[0].id, DesignKind.door)
        ..setOpeningKind(order[1].id, DesignKind.window);

      final after = c.state.design;
      expect(after.kindOf(after.openingsInOrder[0]), DesignKind.door);
      expect(after.kindOf(after.openingsInOrder[1]), DesignKind.window);
      // The assembly is still the assembly: saying what a leaf is writes on
      // that leaf and nowhere else.
      expect(after.kind, DesignKind.both);
    });

    test('nothing is assumed about a leaf nobody has named', () {
      final design = read().state.design;
      for (final opening in design.openings) {
        expect(opening.kind, isNull);
        expect(design.kindOf(opening), isNull);

        // It opens, so it hangs on hinges — that is the mark's doing. No
        // handle, because which handle has not been said.
        final mine = on(design, opening.id);
        expect(mine, isNotEmpty);
        expect({for (final p in mine) p.kind}, {HardwareKind.hinge});
        expect(mine.where((p) => p.kind.isHandle), isEmpty);
      }
    });

    test('and the handle appears the moment they say', () {
      final c = read();
      final leaf = c.state.design.openingsInOrder.first;

      c.setOpeningKind(leaf.id, DesignKind.door);
      expect({for (final p in on(c.state.design, leaf.id)) p.kind},
          {HardwareKind.hinge, HardwareKind.lever, HardwareKind.lock});

      c.setOpeningKind(leaf.id, DesignKind.window);
      expect({for (final p in on(c.state.design, leaf.id)) p.kind},
          {HardwareKind.hinge, HardwareKind.handle});

      // And the leaf beside it, still unanswered, is still bare.
      final other = c.state.design.openingsInOrder[1];
      expect({for (final p in on(c.state.design, other.id)) p.kind},
          {HardwareKind.hinge});
    });

    test('a leaf in a door or a window design still follows it', () {
      // Nothing about the new kind changes the two that were there.
      for (final kind in DesignKind.leafKinds) {
        final design = read(kind: kind).state.design;
        for (final opening in design.openings) {
          expect(opening.kind, isNull, reason: 'nobody said, so nothing said');
          expect(design.kindOf(opening), kind, reason: 'it follows the design');
          expect(on(design, opening.id).where((p) => p.kind.isHandle),
              isNotEmpty);
        }
      }
    });

    test('the mark still decides what opens, whatever the design is', () {
      // The new category is about what a leaf may be, not about what the
      // reading does. Two marks, two openings, one fixed light — the same
      // design the other two kinds read from this sheet.
      // By the geometry rather than by the ids, which carry the design's
      // own id and so differ between two readings of the same sheet.
      String shape(Design design) => [
            design.topLevelSections.length,
            design.topLevelDividers.length,
            design.openings.length,
            for (final o in design.openingsInOrder)
              design.sectionById(o.sectionId)!.outline.corners.join(','),
          ].join(':');

      expect(shape(read().state.design),
          shape(read(kind: DesignKind.window).state.design));
      expect(shape(read().state.design),
          shape(read(kind: DesignKind.door).state.design));
    });

    test('it survives a save and a reload', () {
      final c = read();
      final leaf = c.state.design.openingsInOrder.first;
      c.setOpeningKind(leaf.id, DesignKind.door);

      final back = Design.fromJson(c.state.design.toJson());
      expect(back.kind, DesignKind.both);
      expect(back.openingById(leaf.id)!.kind, DesignKind.door);
      expect(back.kindOf(back.openingsInOrder[1]), isNull);
    });
  });

  group('the handle goes at the middle of the leaf', () {
    test('at the middle of the edge it is hung opposite, on any leaf', () {
      final c = read();
      for (final opening in [...c.state.design.openingsInOrder]) {
        c.setOpeningKind(opening.id, DesignKind.door);
      }

      final design = c.state.design;
      for (final opening in design.openingsInOrder) {
        final outline = design.sectionById(opening.sectionId)!.outline;
        final handle =
            on(design, opening.id).firstWhere((p) => p.kind.isHandle);
        expect(handle.at.y, closeTo(outline.centroid.y, 0.5));
      }
    });

    test('and the kind does not move it', () {
      final c = read();
      final leaf = c.state.design.openingsInOrder.first;

      c.setOpeningKind(leaf.id, DesignKind.door);
      final asDoor =
          on(c.state.design, leaf.id).firstWhere((p) => p.kind.isHandle).at;

      c.setOpeningKind(leaf.id, DesignKind.window);
      final asWindow =
          on(c.state.design, leaf.id).firstWhere((p) => p.kind.isHandle).at;

      // Saying what a leaf is must not slide its handle up a stile whose
      // geometry the user never touched.
      expect(asWindow.x, closeTo(asDoor.x, 0.01));
      expect(asWindow.y, closeTo(asDoor.y, 0.01));
    });

    test('the user’s own figure still has the last word', () {
      final c = read();
      final leaf = c.state.design.openingsInOrder.first;
      c
        ..setOpeningKind(leaf.id, DesignKind.door)
        ..setOpeningHardware(leaf.id, handleAlongMm: 400);

      final design = c.state.design;
      final outline = design.sectionById(leaf.sectionId)!.outline;
      final handle = on(design, leaf.id).firstWhere((p) => p.kind.isHandle);
      expect(handle.at.y, closeTo(outline.bottom - 400, 0.5));
    });
  });

  group('the question is put as an alert over the work', () {
    Future<WorkspaceController> open(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const ProFrameApp(),
      ));
      await tester.pumpAndSettle();
      await toTheCategories(tester);
      await tester.tap(find.text('DOOR & WINDOW'));
      await tester.pumpAndSettle();

      final controller = container.read(workspaceProvider.notifier);
      controller.state = controller.state.copyWith(
        design: controller.state.design.copyWith(sketch: sheet()),
      );
      controller.readDrawing();
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('the start screen offers the third category', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const ProFrameApp(),
      ));
      await tester.pumpAndSettle();
      await toTheCategories(tester);

      expect(find.text('DOOR'), findsOneWidget);
      expect(find.text('WINDOW'), findsOneWidget);
      expect(find.text('DOOR & WINDOW'), findsOneWidget);

      await tester.tap(find.text('DOOR & WINDOW'));
      await tester.pumpAndSettle();
      expect(container.read(workspaceProvider).design.kind, DesignKind.both);
    });

    testWidgets('and a fourth: sliding', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const ProFrameApp(),
      ));
      await tester.pumpAndSettle();
      await toTheCategories(tester);

      expect(find.text('SLIDING'), findsOneWidget);
      await tester.tap(find.text('SLIDING'));
      await tester.pumpAndSettle();
      expect(
        container.read(workspaceProvider).design.kind,
        DesignKind.sliding,
      );
    });

    testWidgets('it is raised over the work, with the work blurred back',
        (tester) async {
      await open(tester);

      expect(find.byType(OpeningKindAlert), findsOneWidget);
      expect(find.text('Opening type'), findsOneWidget);

      // Blurred, not replaced. The design is still there behind it — it is
      // simply not what is being asked about for the moment.
      final blur = tester.widget<BackdropFilter>(
        find.descendant(
          of: find.byType(OpeningKindAlert),
          matching: find.byType(BackdropFilter),
        ),
      );
      expect(blur.filter, isA<ImageFilter>());
      expect(
        find.descendant(
          of: find.byType(OpeningKindAlert),
          matching: find.byType(ModalBarrier),
        ),
        findsOneWidget,
      );
    });

    testWidgets('one leaf at a time, each naming the one it is about',
        (tester) async {
      final controller = await open(tester);
      expect(controller.state.design.openings, hasLength(2));

      // Two marks, two questions — but one card, so the user answers one
      // leaf at a time and is told how many are left.
      expect(controller.state.openingKindQuestions, hasLength(2));
      expect(find.textContaining('What is Opening 1'), findsOneWidget);
      expect(find.textContaining('What is Opening 2'), findsNothing);
      expect(find.text('1 of 2'), findsOneWidget);

      await tester.tap(find.widgetWithText(AlertPressable, 'Door'));
      await tester.pumpAndSettle();

      // The first is answered and gone; the second is now the one asked.
      expect(find.textContaining('What is Opening 2'), findsOneWidget);
      expect(find.text('1 of 2'), findsNothing, reason: 'one left');

      await tester.tap(find.widgetWithText(AlertPressable, 'Window'));
      await tester.pumpAndSettle();

      expect(find.byType(OpeningKindAlert), findsOneWidget);
      expect(find.text('Opening type'), findsNothing, reason: 'nothing left');

      final design = controller.state.design;
      expect(design.kindOf(design.openingsInOrder[0]), DesignKind.door);
      expect(design.kindOf(design.openingsInOrder[1]), DesignKind.window);
    });

    testWidgets('waving it away is not an answer, and nothing waits on it',
        (tester) async {
      final controller = await open(tester);
      final before = controller.state.design.toJson().toString();

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      // Gone, and the design is exactly as the marks made it: the leaves
      // keep no kind, and nothing about them was decided.
      expect(find.text('Opening type'), findsNothing);
      expect(controller.state.design.toJson().toString(), before);
      for (final opening in controller.state.design.openings) {
        expect(opening.kind, isNull);
      }
    });

    testWidgets('and it is never put twice', (tester) async {
      final controller = await open(tester);
      for (final opening in [...controller.state.design.openingsInOrder]) {
        controller.answer(
            WorkspaceState.openingKindQuestion(opening.id), 'window');
      }
      await tester.pumpAndSettle();
      expect(find.text('Opening type'), findsNothing);

      // Reading the sheet again does not bring it back.
      controller.readDrawing();
      await tester.pumpAndSettle();
      expect(find.text('Opening type'), findsNothing);
      expect(controller.state.openingKindQuestions, isEmpty);
    });

    testWidgets('the sheet’s own questions stay in the panel below',
        (tester) async {
      final controller = await open(tester);
      // The alert is for what a leaf is. Everything the reading could not
      // settle is about the sheet, and stays where it was.
      expect(controller.state.sheetQuestions, isEmpty);
      expect(
        controller.state.allQuestions.length,
        controller.state.openingKindQuestions.length +
            controller.state.sheetQuestions.length,
      );
    });
  });
}
