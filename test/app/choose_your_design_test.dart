import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/app.dart';
import 'package:proframe/app/screens/designs_screen.dart';
import 'package:proframe/app/screens/new_design_screen.dart';
import 'package:proframe/app/screens/start_screen.dart';
import 'package:proframe/app/screens/workspace_screen.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'new_design.dart';
import 'pause_and_take_it_back_test.dart' as sheet;

// After naming a new design, the user says what it is: a door or a window,
// the two main choices, with a frame holding both and a sliding set under
// "More types". That is where the design starts, not a limit on it — any
// opening can still be made a door or a window later. Opening a saved
// design never comes here.

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

/// Whether the card called [label] is the chosen one, as a screen reader
/// is told it.
bool chosen(WidgetTester tester, String label) => tester
    .widget<Semantics>(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == label,
      ),
    )
    .properties
    .selected!;

FilledButton startButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.ancestor(
    of: find.text(StartScreen.startLabel),
    matching: find.byWidgetPredicate((w) => w is FilledButton),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('New Design, who and what, Continue: choose your design', (
    tester,
  ) async {
    await openTheApp(tester);
    expect(find.byType(DesignsScreen), findsOneWidget);
    await toTheCategories(tester, customer: 'Ahmed', name: 'Main entrance');

    expect(find.byType(StartScreen), findsOneWidget);
    expect(find.text('Choose your design'), findsOneWidget);
    expect(
      find.text('Select the type of product you want to create.'),
      findsOneWidget,
    );
    // The two main choices, with what each is for.
    expect(find.text('DOOR'), findsOneWidget);
    expect(find.text('WINDOW'), findsOneWidget);
    expect(find.text('Create a custom door design'), findsOneWidget);
    expect(find.text('Create a custom window design'), findsOneWidget);
    // And the other two, under More types.
    expect(find.text('MORE TYPES'), findsOneWidget);
    expect(find.text('DOOR & WINDOW'), findsOneWidget);
    expect(find.text('SLIDING'), findsOneWidget);
    // Who it is for, so nobody has to remember.
    expect(find.textContaining('Ahmed'), findsOneWidget);
    expect(find.textContaining('Main entrance'), findsOneWidget);
    // Nothing else is asked: no field to fill in.
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('nothing is begun until a kind is chosen', (tester) async {
    final c = await openTheApp(tester);
    await toTheCategories(tester);
    final before = c.read(workspaceProvider).design.id;
    expect(startButton(tester).onPressed, isNull);
    expect(find.text('Choose a type to continue'), findsOneWidget);
    await tester.tap(find.text(StartScreen.startLabel));
    await tester.pumpAndSettle();
    expect(find.byType(StartScreen), findsOneWidget);
    expect(c.read(workspaceProvider).design.id, before);
  });

  testWidgets('the chosen card is plainly the chosen one, and only it', (
    tester,
  ) async {
    await openTheApp(tester);
    await toTheCategories(tester);
    for (final label in ['Door', 'Window', 'Door & window', 'Sliding']) {
      expect(chosen(tester, label), isFalse);
    }

    await tester.tap(find.text('DOOR'));
    await tester.pumpAndSettle();
    expect(chosen(tester, 'Door'), isTrue);
    expect(chosen(tester, 'Window'), isFalse);
    expect(find.text('Door selected'), findsOneWidget);
    expect(startButton(tester).onPressed, isNotNull);

    // Changing one's mind moves the choice; it does not add to it.
    await tester.tap(find.text('WINDOW'));
    await tester.pumpAndSettle();
    expect(chosen(tester, 'Door'), isFalse);
    expect(chosen(tester, 'Window'), isTrue);
    expect(find.text('Window selected'), findsOneWidget);
  });

  for (final (card, kind) in const [
    ('DOOR', DesignKind.door),
    ('WINDOW', DesignKind.window),
    ('DOOR & WINDOW', DesignKind.both),
    ('SLIDING', DesignKind.sliding),
  ]) {
    testWidgets('$card goes into the drawing, kept as a ${kind.label}', (
      tester,
    ) async {
      final c = await openTheApp(tester);
      await toTheCategories(tester, customer: 'Sara', name: 'Kitchen');
      await chooseDesign(tester, card);

      // The existing drawing, not a new screen.
      expect(find.byType(WorkspaceScreen), findsOneWidget);
      expect(find.byType(StartScreen), findsNothing);
      final design = c.read(workspaceProvider).design;
      expect(design.kind, kind);
      expect(design.customer, 'Sara');
      expect(design.name, 'Kitchen');
      expect(find.text('Read my drawing'), findsNothing);

      // The kind chosen is kept with the design.
      final kept = (await tester.runAsync(DesignStore().all))!;
      expect(kept.single.id, design.id);
      expect(kept.single.kind, kind);
    });
  }

  testWidgets('back from the choice is back to the form', (tester) async {
    await openTheApp(tester);
    await toTheCategories(tester);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(NewDesignScreen), findsOneWidget);
  });

  testWidgets('a saved design opens straight into itself, never asked again', (
    tester,
  ) async {
    // Made the way a user makes one: named, chosen, drawn.
    final c = await openTheApp(tester);
    await toTheCategories(tester, customer: 'Karwan', name: 'Garden door');
    await chooseDesign(tester, 'DOOR');
    await sheet.twoLeaves(c);
    await tester.pumpAndSettle();
    final made = c.read(workspaceProvider).design;
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(DesignsScreen), findsOneWidget);

    // Every frame on the way in, not only where it ends up.
    final shown = <String>{};
    await tester.tap(find.text('Karwan'));
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.byType(StartScreen).evaluate().isNotEmpty) shown.add('choice');
      if (find.byType(NewDesignScreen).evaluate().isNotEmpty) {
        shown.add('form');
      }
    }
    await tester.pumpAndSettle();

    expect(shown, isEmpty, reason: 'no form and no choice on the way in');
    expect(find.byType(StartScreen), findsNothing);
    expect(find.byType(WorkspaceScreen), findsOneWidget);
    final open = c.read(workspaceProvider).design;
    expect(open.id, made.id);
    expect(open.kind, DesignKind.door);
    expect(open.openings, hasLength(made.openings.length));
  });

  testWidgets('a door design can still hold a window opening, and a fixed '
      'area beside it', (tester) async {
    final c = await openTheApp(tester);
    await toTheCategories(tester, customer: 'Dilan', name: 'Shop front');
    await chooseDesign(tester, 'DOOR');
    final controller = await sheet.twoLeaves(c);
    await tester.pumpAndSettle();

    final design = c.read(workspaceProvider).design;
    expect(design.kind, DesignKind.door);
    final order = design.openingsInOrder;
    expect(order, hasLength(2));
    controller
      ..setOpeningKind(order[0].id, DesignKind.window)
      ..setOpeningKind(order[1].id, DesignKind.door);
    await tester.pumpAndSettle();

    final mixed = c.read(workspaceProvider).design;
    expect(mixed.kindOf(mixed.openingsInOrder[0]), DesignKind.window);
    expect(mixed.kindOf(mixed.openingsInOrder[1]), DesignKind.door);
    expect(mixed.kind, DesignKind.door, reason: 'where it started');
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
        await openTheApp(tester, size: size);
        await toTheCategories(tester);
        await tester.tap(find.text('DOOR'));
        await tester.pumpAndSettle();

        final overflowing = [
          for (final r in tester.allRenderObjects)
            if (r is RenderFlex && r.toStringShort().contains('OVERFLOWING'))
              r.debugCreator.toString().split('\n').first,
        ];
        expect(overflowing, isEmpty, reason: overflowing.join('\n'));
        expect(tester.takeException(), isNull);

        final door = tester.getRect(find.text('DOOR'));
        final window = tester.getRect(find.text('WINDOW'));
        if (size.width < 600) {
          // One above the other, each most of the width: a thumb's target.
          expect(window.top, greaterThan(door.bottom));
          final card = tester.getRect(
            find
                .ancestor(of: find.text('DOOR'), matching: find.byType(InkWell))
                .first,
          );
          expect(card.width, greaterThan(size.width * 0.85));
          expect(card.height, greaterThan(200));
        } else {
          // Side by side.
          expect(window.top, closeTo(door.top, 1));
          expect(window.left, greaterThan(door.right));
        }
        // The way in is always on screen, whatever has scrolled.
        final start = tester.getRect(find.text(StartScreen.startLabel));
        expect(start.bottom, lessThanOrEqualTo(size.height));
      });
    }
  });
}
