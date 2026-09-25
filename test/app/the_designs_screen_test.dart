import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/app.dart';
import 'package:proframe/app/canvas/design_preview.dart';
import 'package:proframe/app/screens/designs_screen.dart';
import 'package:proframe/app/screens/new_design_screen.dart';
import 'package:proframe/app/screens/start_screen.dart';
import 'package:proframe/app/screens/workspace_screen.dart';
import 'package:proframe/app/state/tools.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'new_design.dart';
import 'pause_and_take_it_back_test.dart' as sheet;

// The app opens on the designs, not on "door or window": a workshop draws
// for hundreds of people, so the first choice is to carry on with one of
// them or to begin another. Every design is shown by its own saved geometry,
// found by who it is for or its number, and opened
// exactly as it was left. The drawing, the CAD drawing and the model are
// what they always were — this is only the way in to them.

/// A design drawn and read the way the user makes one: an outline [wide]
/// millimetres across, a mullion, and a `>` in the left light.
Design drawn({
  required String customer,
  required DesignKind kind,
  required DateTime edited,
  double wide = 2400,
}) {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  final controller = c.read(workspaceProvider.notifier)
    ..startDesign(kind, name: customer, customer: customer);
  controller.state = controller.state.copyWith(
    design: controller.state.design.copyWith(
      sketch: Sketch(
        strokes: [
          sheet.pen('outline', [
            const Vec2(0, 0),
            Vec2(wide, 0),
            Vec2(wide, 2100),
            const Vec2(0, 2100),
            const Vec2(0, 0),
          ]),
          sheet.pen('mullion', [Vec2(wide / 2, 0), Vec2(wide / 2, 2100)]),
          sheet.pen('mark', sheet.chevron(Vec2(wide / 4, 1050))),
        ],
      ),
    ),
  );
  controller.readDrawing();
  final design = controller.state.design.copyWith(updatedAt: edited);
  expect(design.frame, isNotNull, reason: 'the drawing was read');
  return design;
}

final now = DateTime.now();

/// Three kept designs, edited an hour, a day and a week ago — kept out of
/// that order, so the list has to sort them.
Future<List<Design>> keepThree() async {
  final designs = [
    drawn(
      customer: 'Karwan',
      kind: DesignKind.door,
      edited: now.subtract(const Duration(days: 1)),
      wide: 1000,
    ),
    drawn(
      customer: 'Ahmed',
      kind: DesignKind.both,
      edited: now.subtract(const Duration(hours: 1)),
    ),
    drawn(
      customer: 'Sara',
      kind: DesignKind.window,
      edited: now.subtract(const Duration(days: 7)),
      wide: 1600,
    ),
  ];
  final store = DesignStore();
  for (final design in designs) {
    await store.save(design);
  }
  return designs;
}

Future<ProviderContainer> openTheApp(
  WidgetTester tester, {
  Size size = const Size(1280, 820),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const ProFrameApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

/// The customers on the cards, in the order the screen shows them: by where
/// each card is, row by row.
List<String> shownInOrder(WidgetTester tester, List<String> customers) {
  final at = {
    for (final who in customers)
      if (find.text(who).evaluate().isNotEmpty)
        who: tester.getTopLeft(
          find.ancestor(of: find.text(who), matching: find.byType(DesignCard)),
        ),
  };
  return at.keys.toList()..sort((a, b) {
    final dy = at[a]!.dy.compareTo(at[b]!.dy);
    return dy != 0 ? dy : at[a]!.dx.compareTo(at[b]!.dx);
  });
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the app opens on the designs', () {
    testWidgets('with nothing kept yet, it says so and offers one thing', (
      tester,
    ) async {
      await openTheApp(tester);
      expect(find.byType(DesignsScreen), findsOneWidget);
      expect(find.text('Designs'), findsOneWidget);
      expect(find.text('Search designs...'), findsOneWidget);
      expect(find.text('No recent designs yet'), findsOneWidget);
      expect(
        find.text('Create your first design to get started.'),
        findsOneWidget,
      );
      expect(find.text('New Design'), findsWidgets);
      // Not door or window, yet.
      expect(find.byType(StartScreen), findsNothing);
      expect(find.text('DOOR'), findsNothing);
    });

    testWidgets('the recent designs, the most recently edited first', (
      tester,
    ) async {
      await keepThree();
      await openTheApp(tester);
      expect(find.text('Recent Designs'), findsOneWidget);
      expect(find.byType(DesignCard), findsNWidgets(3));
      expect(shownInOrder(tester, ['Ahmed', 'Karwan', 'Sara']), [
        'Ahmed',
        'Karwan',
        'Sara',
      ]);
      // Each card says who, how big, what kind and when.
      expect(find.text('240 × 210 cm'), findsOneWidget);
      expect(find.text('100 × 210 cm'), findsOneWidget);
      expect(find.text('Door & window'), findsOneWidget);
      expect(find.textContaining('Edited 1 hour ago'), findsOneWidget);
      expect(find.textContaining('Edited yesterday'), findsOneWidget);
    });

    testWidgets('each picture is that design, drawn from what was saved', (
      tester,
    ) async {
      final kept = await keepThree();
      await openTheApp(tester);
      final painters = [
        for (final paint in tester.widgetList<CustomPaint>(
          find.descendant(
            of: find.byType(DesignCard),
            matching: find.byType(CustomPaint),
          ),
        ))
          if (paint.painter case final DesignPreviewPainter p) p,
      ];
      expect(painters, hasLength(3));
      for (final design in kept) {
        final shown = painters.singleWhere((p) => p.design.id == design.id);
        expect(
          jsonEncode(shown.design.toJson()),
          jsonEncode(design.toJson()),
          reason: 'the saved design itself, not a picture of one',
        );
      }
      // And no picture of anything at all.
      expect(find.byType(Image), findsNothing);
      expect(find.byType(RawImage), findsNothing);
    });

    testWidgets('three different designs are three different pictures', (
      tester,
    ) async {
      await keepThree();
      await openTheApp(tester);
      Future<List<int>> pixels(String customer) async {
        final card = find.ancestor(
          of: find.text(customer),
          matching: find.byType(DesignCard),
        );
        final preview = find.descendant(
          of: card,
          matching: find.byType(DesignPreview),
        );
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find
              .ancestor(of: preview, matching: find.byType(RepaintBoundary))
              .first,
        );
        final image = await tester.runAsync(
          () => boundary.toImage(pixelRatio: 1),
        );
        final bytes = await tester.runAsync(image!.toByteData);
        return bytes!.buffer.asUint8List();
      }

      final ahmed = await pixels('Ahmed');
      final karwan = await pixels('Karwan');
      expect(ahmed, isNot(equals(karwan)));
    });
  });

  group('search', () {
    Future<void> search(WidgetTester tester, String query) async {
      await tester.enterText(find.byType(TextField), query);
      await tester.pumpAndSettle();
    }

    testWidgets('by customer and by design number', (tester) async {
      final kept = await keepThree();
      await openTheApp(tester);

      await search(tester, 'ahm');
      expect(find.byType(DesignCard), findsOneWidget);
      expect(find.text('Ahmed'), findsOneWidget);

      await search(tester, 'SAR');
      expect(find.byType(DesignCard), findsOneWidget);
      expect(find.text('Sara'), findsOneWidget);

      final karwan = kept.first;
      await search(tester, shortIdOf(karwan.id));
      expect(find.byType(DesignCard), findsOneWidget);
      expect(find.text('Karwan'), findsOneWidget);

      await search(tester, 'nobody');
      expect(find.byType(DesignCard), findsNothing);
      expect(find.text('No designs match “nobody”'), findsOneWidget);

      // Clearing it brings them all back.
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.byType(DesignCard), findsNWidgets(3));
    });

    test('what a search matches', () {
      final design = DesignSummary.of(
        Design.empty(
          id: 'design-1727000123456-0',
          kind: DesignKind.door,
          name: 'Ahmed',
          customer: 'Ahmed',
        ),
      );
      expect(design.matches(''), isTrue);
      expect(design.matches('  ahMED '), isTrue);
      expect(design.matches('1727000123456'), isTrue);
      expect(design.matches('Sara'), isFalse);
      // The moment it was made, to the millisecond, in eight characters.
      expect(design.number, 1727000123456.toRadixString(36).toUpperCase());
      expect(design.number, hasLength(8));
      expect(design.matches(design.number.toLowerCase()), isTrue);
      // Made on a platform that counts microseconds, the same millisecond
      // reads the same.
      expect(shortIdOf('design-1727000123456789-3'), design.number);
      // Two designs a millisecond apart are told apart.
      expect(shortIdOf('design-1727000123457000-4'), isNot(design.number));
      // Kurdish names are found as they are written.
      final kurdish = DesignSummary.of(
        Design.empty(
          id: 'design-1',
          kind: DesignKind.window,
          customer: 'سۆران',
        ),
      );
      expect(kurdish.matches('سۆران'), isTrue);
      // A design kept before there was a customer is known by its name.
      final older = DesignSummary.of(
        Design.empty(id: 'd', kind: DesignKind.door, name: 'Garden door'),
      );
      expect(older.title, 'Garden door');
      expect(older.matches('garden'), isTrue);
    });

    test('how long ago, as a person says it', () {
      final at = DateTime(2026, 9, 25, 12);
      expect(editedAgo(at, at), 'Edited just now');
      expect(
        editedAgo(at.subtract(const Duration(minutes: 5)), at),
        'Edited 5 minutes ago',
      );
      expect(
        editedAgo(at.subtract(const Duration(minutes: 1)), at),
        'Edited 1 minute ago',
      );
      expect(
        editedAgo(at.subtract(const Duration(hours: 3)), at),
        'Edited 3 hours ago',
      );
      expect(
        editedAgo(at.subtract(const Duration(days: 1)), at),
        'Edited yesterday',
      );
      expect(editedAgo(DateTime(2026, 3, 2), at), 'Edited 2 Mar');
      expect(editedAgo(DateTime(2025, 3, 2), at), 'Edited 2 Mar 2025');
    });
  });

  group('opening a design', () {
    testWidgets('opens exactly what was saved, to carry on with', (
      tester,
    ) async {
      final kept = await keepThree();
      final c = await openTheApp(tester);
      await tester.tap(find.text('Karwan'));
      await tester.pumpAndSettle();

      expect(find.byType(WorkspaceScreen), findsOneWidget);
      final open = c.read(workspaceProvider).design;
      expect(
        jsonEncode(open.toJson()),
        jsonEncode(kept.first.toJson()),
        reason:
            'the sketch, the geometry, the openings and every material '
            'as they were saved — nothing read again, nothing redrawn',
      );
      expect(c.read(workspaceProvider).needsReading, isFalse);
    });

    testWidgets('looking without editing leaves it where it is in the list', (
      tester,
    ) async {
      await keepThree();
      await openTheApp(tester);
      await tester.tap(find.text('Sara'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(shownInOrder(tester, ['Ahmed', 'Karwan', 'Sara']), [
        'Ahmed',
        'Karwan',
        'Sara',
      ]);
    });

    testWidgets('an edit brings it back to the top, as edited', (tester) async {
      final kept = await keepThree();
      final c = await openTheApp(tester);
      await tester.tap(find.text('Sara'));
      await tester.pumpAndSettle();

      final sara = kept.last;
      c.read(workspaceProvider.notifier).addStroke(const [
        StrokeSample(Vec2(100, 300)),
        StrokeSample(Vec2(700, 300)),
      ], tool: Tool.pen);
      await tester.pumpAndSettle();
      // Kept without being asked, once it has stood still.
      await tester.pump(WorkspaceScreen.keepAfter);
      await tester.pumpAndSettle();

      final stored = (await tester.runAsync(DesignStore().all))!;
      expect(stored.first.id, sara.id);
      expect(stored.first.updatedAt.isAfter(sara.updatedAt), isTrue);
      expect(
        stored.first.sketch.length,
        sara.sketch.length + 1,
        reason: 'the edit is what was kept',
      );

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(shownInOrder(tester, ['Ahmed', 'Karwan', 'Sara']), [
        'Sara',
        'Ahmed',
        'Karwan',
      ]);
      expect(find.textContaining('Edited just now'), findsOneWidget);
    });

    testWidgets('leaving straight after an edit keeps it too', (tester) async {
      final kept = await keepThree();
      final c = await openTheApp(tester);
      await tester.tap(find.text('Karwan'));
      await tester.pumpAndSettle();
      c.read(workspaceProvider.notifier).rename('Back door');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      final stored = (await tester.runAsync(DesignStore().all))!;
      expect(stored.first.id, kept.first.id);
      expect(stored.first.name, 'Back door');
      expect(shownInOrder(tester, ['Ahmed', 'Karwan', 'Sara']).first, 'Karwan');
    });
  });

  group('a new design', () {
    testWidgets('who it is for, and nothing else, then door or window', (
      tester,
    ) async {
      final c = await openTheApp(tester);
      await tester.tap(find.text('New Design').first);
      await tester.pumpAndSettle();

      // One simple step, not the choice of door or window yet.
      expect(find.byType(NewDesignScreen), findsOneWidget);
      expect(find.byType(StartScreen), findsNothing);
      expect(find.text('Person / Customer'), findsOneWidget);
      expect(find.text('Design Name'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(
        find.byKey(NewDesignScreen.customerField),
        'Hawre',
      );
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.byType(StartScreen), findsOneWidget);
      for (final card in ['DOOR', 'WINDOW', 'DOOR & WINDOW', 'SLIDING']) {
        expect(find.text(card), findsOneWidget);
      }
      await chooseDesign(tester, 'WINDOW');

      expect(find.byType(WorkspaceScreen), findsOneWidget);
      final design = c.read(workspaceProvider).design;
      expect(design.customer, 'Hawre');
      expect(design.kind, DesignKind.window);
      // Known by who it is for, at the top of the drawing too.
      expect(design.name, 'Hawre');
      expect(find.text('Hawre'), findsOneWidget);

      // Back is to the designs, where it now is.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byType(DesignsScreen), findsOneWidget);
      expect(find.byType(DesignCard), findsOneWidget);
      expect(find.text('Hawre'), findsOneWidget);
    });

    testWidgets('a new design goes to the top of the others', (tester) async {
      await keepThree();
      await openTheApp(tester);
      await toTheCategories(tester, customer: 'Dilan');
      await chooseDesign(tester, 'DOOR');
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(shownInOrder(tester, ['Dilan', 'Ahmed', 'Karwan', 'Sara']), [
        'Dilan',
        'Ahmed',
        'Karwan',
        'Sara',
      ]);
    });

    testWidgets('without who it is for, it does not go on', (tester) async {
      await openTheApp(tester);
      await tester.tap(find.text('New Design').first);
      await tester.pumpAndSettle();
      FilledButton go() => tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Continue'),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
      );
      expect(go().onPressed, isNull);
      // Spaces are not a name.
      await tester.enterText(find.byKey(NewDesignScreen.customerField), '   ');
      await tester.pump();
      expect(go().onPressed, isNull);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.byType(NewDesignScreen), findsOneWidget);
      await tester.enterText(find.byKey(NewDesignScreen.customerField), 'Ari');
      await tester.pump();
      expect(go().onPressed, isNotNull);
    });

    testWidgets('back from door or window is back to the form', (tester) async {
      await openTheApp(tester);
      await toTheCategories(tester);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(NewDesignScreen), findsOneWidget);
    });
  });

  group('who a design is for is kept with it', () {
    test('through a save and a load', () {
      final design = Design.empty(
        id: 'd',
        kind: DesignKind.door,
        name: 'Main entrance',
        customer: 'Ahmed',
      );
      final back = Design.fromJson(jsonDecode(jsonEncode(design.toJson())));
      expect(back.customer, 'Ahmed');
      expect(back.copyWith(name: 'x').customer, 'Ahmed');
    });

    test('a design saved before there was a customer still loads', () {
      final older = Design.empty(id: 'd', kind: DesignKind.window).toJson();
      expect(older.containsKey('customer'), isFalse);
      final back = Design.fromJson(jsonDecode(jsonEncode(older)));
      expect(back.customer, isNull);
      expect(back.name, 'Untitled window');
    });
  });

  group('it fits the screen it is on', () {
    for (final size in const [
      Size(360, 740),
      Size(390, 844),
      Size(820, 1180),
      Size(1024, 768),
      Size(1440, 900),
    ]) {
      testWidgets('at ${size.width.toInt()} × ${size.height.toInt()}', (
        tester,
      ) async {
        await keepThree();
        await openTheApp(tester, size: size);
        final overflowing = [
          for (final r in tester.allRenderObjects)
            if (r is RenderFlex && r.toStringShort().contains('OVERFLOWING'))
              r.debugCreator.toString().split('\n').first,
        ];
        expect(overflowing, isEmpty, reason: overflowing.join('\n'));
        expect(tester.takeException(), isNull);

        final cards = tester
            .widgetList<DesignCard>(find.byType(DesignCard))
            .toList();
        expect(cards, isNotEmpty);
        final first = tester.getRect(find.byType(DesignCard).first);
        if (size.width < 600) {
          // A list a thumb works down: one card to a row, the picture
          // beside the words.
          expect(cards.every((card) => card.wide), isTrue);
          expect(first.width, greaterThan(size.width * 0.85));
        } else {
          // A grid: more than one card to a row.
          expect(cards.every((card) => !card.wide), isTrue);
          final second = tester.getRect(find.byType(DesignCard).at(1));
          expect(second.top, closeTo(first.top, 1));
        }
      });
    }
  });
}
