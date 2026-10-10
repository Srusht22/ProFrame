import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/app.dart';
import 'package:proframe/app/canvas/design_preview.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/screens/customers_screen.dart';
import 'package:proframe/app/screens/design_name_screen.dart';
import 'package:proframe/app/screens/designs_screen.dart';
import 'package:proframe/app/screens/new_design_screen.dart';
import 'package:proframe/app/screens/start_screen.dart';
import 'package:proframe/app/screens/workspace_screen.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/dimensions/measurements.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/pricing/pricing_access.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'new_design.dart';
import 'pause_and_take_it_back_test.dart' as sheet;

// The app opens on the customers, not on "door or window" and not on a
// list of designs: the user's words, *only the name of the customer with
// its info; when I click the customer name it goes to the design cards,
// even if there is only one design, and I pick which design I want.* So a
// tap on a customer is never a drawing. Their designs are on their page,
// each shown by its own saved geometry and opened exactly as it was left.
// The drawing, the CAD drawing and the model are what they always were —
// this is only the way in to them.

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
  final controller = c.read(
    workspaceProvider.notifier,
  )..startDesign(kind, name: '${kind.label} for $customer', customer: customer);
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
  // Kept with every size given, as a design is once the user has measured
  // it: these are about the list, not about being asked for sizes.
  final read = controller.state.design;
  final measured = Measurements.apply(read, {
    for (final m in Measurements.of(read))
      if (m.asked) m.key: m.currentMm(read),
  }).design;
  final design = measured.copyWith(updatedAt: edited);
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
  // What the store kept — each design now belonging to its customer — which
  // is what everything afterwards is compared with.
  final store = DesignStore();
  return [
    for (final design in designs)
      await store.save(design, by: WorkshopRole.owner),
  ];
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
List<String> shownInOrder(WidgetTester tester) {
  final cards = tester
      .widgetList<CustomerCard>(find.byType(CustomerCard))
      .toList();
  final at = {
    for (final card in cards)
      card.customer.name: tester.getTopLeft(
        find.byKey(CustomerCard.keyOf(card.customer.id)),
      ),
  };
  return at.keys.toList()..sort((a, b) {
    final dy = at[a]!.dy.compareTo(at[b]!.dy);
    return dy != 0 ? dy : at[a]!.dx.compareTo(at[b]!.dx);
  });
}

/// A tap on the customer called [name], on the screen the app opens on.
Future<void> openCustomer(WidgetTester tester, String name) async {
  await tester.tap(
    find.ancestor(of: find.text(name), matching: find.byType(CustomerCard)),
  );
  await tester.pumpAndSettle();
}

/// The designs shown as cards on the customer's page, by their ids.
List<String> cardsShown(WidgetTester tester) => [
  for (final card in tester.widgetList<CustomerDesignCard>(
    find.byType(CustomerDesignCard),
  ))
    card.design.id,
];

Future<void> openCard(WidgetTester tester, String id) async {
  await tester.ensureVisible(find.byKey(CustomerDesignCard.openKey(id)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(CustomerDesignCard.openKey(id)));
  await tester.pumpAndSettle();
}

// Since Phase 32 the stores ask who is writing (`by:`) and refuse anybody
// without the capability; the writes here are the owner's, who may do
// everything, because what these tests hold is not about permissions.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the app opens on the customers', () {
    testWidgets('with nobody kept yet, it says so and offers a new customer '
        'and a new design', (tester) async {
      await openTheApp(tester);
      expect(find.byType(CustomersScreen), findsOneWidget);
      expect(find.text('No customers yet'), findsOneWidget);
      expect(find.byKey(CustomersScreen.newCustomerButton), findsOneWidget);
      expect(find.byKey(CustomersScreen.newDesignButton), findsOneWidget);
      // Not door or window, yet, and nowhere to go back to.
      expect(find.byType(StartScreen), findsNothing);
      expect(find.text('DOOR'), findsNothing);
      expect(find.byTooltip('Back'), findsNothing);
    });

    testWidgets('each customer by their name and their information, and no '
        'design on it', (tester) async {
      final kept = await keepThree();
      await openTheApp(tester);
      expect(find.byType(CustomerCard), findsNWidgets(3));
      expect(find.text('3 customers'), findsOneWidget);
      for (final who in ['Ahmed', 'Karwan', 'Sara']) {
        expect(find.text(who), findsOneWidget);
      }
      expect(find.text('1 design'), findsNWidgets(3));
      // Not one design is on the screen: no card, no picture, no name.
      expect(find.byType(CustomerDesignCard), findsNothing);
      expect(find.byType(DesignPicture), findsNothing);
      expect(find.byType(DesignPreview), findsNothing);
      for (final design in kept) {
        expect(find.text(design.name), findsNothing);
      }
      expect(find.text('Recent Designs'), findsNothing);
      expect(find.byType(Image), findsNothing);
    });
  });

  group('a customer opens on their designs, never on a drawing', () {
    testWidgets('one design is still a card to pick, and picking it opens '
        'exactly what was saved', (tester) async {
      final kept = await keepThree();
      final c = await openTheApp(tester);
      await openCustomer(tester, 'Karwan');

      expect(find.byType(CustomerScreen), findsOneWidget);
      expect(find.byType(WorkspaceScreen), findsNothing);
      expect(find.byType(StartScreen), findsNothing);
      final karwan = kept.first;
      expect(cardsShown(tester), [karwan.id]);
      // Its picture is the saved design itself.
      final painters = [
        for (final paint in tester.widgetList<CustomPaint>(
          find.descendant(
            of: find.byType(CustomerDesignCard),
            matching: find.byType(CustomPaint),
          ),
        ))
          if (paint.painter case final DesignPreviewPainter p) p,
      ];
      expect(painters, hasLength(1));
      expect(
        jsonEncode(painters.single.design.toJson()),
        jsonEncode(karwan.toJson()),
      );

      await openCard(tester, karwan.id);
      expect(find.byType(WorkspaceScreen), findsOneWidget);
      final open = c.read(workspaceProvider).design;
      expect(
        jsonEncode(open.toJson()),
        jsonEncode(karwan.toJson()),
        reason:
            'the sketch, the geometry, the openings and every material '
            'as they were saved — nothing read again, nothing redrawn',
      );
      expect(c.read(workspaceProvider).needsReading, isFalse);

      // Back is to the customer's page, then to the customers.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(CustomersScreen), findsOneWidget);
    });

    testWidgets('several designs are several cards, and the one picked is '
        'the one opened', (tester) async {
      final kept = await keepThree();
      final karwan = kept.first;
      final second = await DesignStore().save(
        drawn(
          customer: 'Karwan',
          kind: DesignKind.window,
          edited: now,
          wide: 1800,
        ).copyWith(customerId: karwan.customerId),
        by: WorkshopRole.owner,
      );
      final c = await openTheApp(tester);
      expect(find.text('2 designs'), findsOneWidget);
      await openCustomer(tester, 'Karwan');
      expect(cardsShown(tester), [second.id, karwan.id]);
      expect(find.byType(WorkspaceScreen), findsNothing);

      await openCard(tester, karwan.id);
      expect(c.read(workspaceProvider).design.id, karwan.id);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await openCard(tester, second.id);
      expect(c.read(workspaceProvider).design.id, second.id);
    });

    testWidgets('leaving straight after an edit keeps it, and it is the '
        'first of the customer\'s cards', (tester) async {
      final kept = await keepThree();
      final second = await DesignStore().save(
        drawn(
          customer: 'Sara',
          kind: DesignKind.door,
          edited: now,
        ).copyWith(customerId: kept.last.customerId),
        by: WorkshopRole.owner,
      );
      final c = await openTheApp(tester);
      await openCustomer(tester, 'Sara');
      expect(cardsShown(tester), [second.id, kept.last.id]);
      await openCard(tester, kept.last.id);
      c.read(workspaceProvider.notifier).rename('Back door');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      final stored = (await tester.runAsync(DesignStore().all))!;
      expect(stored.first.id, kept.last.id);
      expect(stored.first.name, 'Back door');
      expect(cardsShown(tester), [kept.last.id, second.id]);
      expect(find.text('Back door'), findsOneWidget);
    });
  });

  group('search', () {
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
  });

  group('a new design', () {
    testWidgets('who it is for, then its name, then door or window', (
      tester,
    ) async {
      final c = await openTheApp(tester);
      await tester.tap(find.byKey(CustomersScreen.newDesignButton));
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

      // Then the design's own name — the person is not what it is called.
      expect(find.byType(DesignNameScreen), findsOneWidget);
      await nameTheDesign(tester, 'Kitchen Window');

      expect(find.byType(StartScreen), findsOneWidget);
      for (final card in ['DOOR', 'WINDOW', 'DOOR & WINDOW', 'SLIDING']) {
        expect(find.text(card), findsOneWidget);
      }
      await chooseDesign(tester, 'WINDOW');

      expect(find.byType(WorkspaceScreen), findsOneWidget);
      final design = c.read(workspaceProvider).design;
      expect(design.customer, 'Hawre');
      expect(design.kind, DesignKind.window);
      // Its own name, at the top of the drawing too.
      expect(design.name, 'Kitchen Window');
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Kitchen Window'),
        ),
        findsOneWidget,
      );

      // Back is to the customers, where Hawre now is, with one design.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byType(CustomersScreen), findsOneWidget);
      expect(shownInOrder(tester), ['Hawre']);
      expect(find.text('1 design'), findsOneWidget);
      await openCustomer(tester, 'Hawre');
      expect(cardsShown(tester), [design.id]);
    });

    testWidgets('a new customer goes to the top of the others', (tester) async {
      await keepThree();
      await openTheApp(tester);
      await toTheCategories(tester, customer: 'Dilan');
      await chooseDesign(tester, 'DOOR');
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(shownInOrder(tester).first, 'Dilan');
      expect(shownInOrder(tester), hasLength(4));
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

    testWidgets('back from door or window is back through the name to the '
        'form', (tester) async {
      await openTheApp(tester);
      await toTheCategories(tester);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(DesignNameScreen), findsOneWidget);
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
        List<String> overflowing() => [
          for (final r in tester.allRenderObjects)
            if (r is RenderFlex && r.toStringShort().contains('OVERFLOWING'))
              r.debugCreator.toString().split('\n').first,
        ];
        expect(overflowing(), isEmpty, reason: overflowing().join('\n'));
        expect(tester.takeException(), isNull);

        final first = tester.getRect(find.byType(CustomerCard).first);
        if (size.width < 600) {
          // A list a thumb works down: one customer to a row.
          expect(first.width, greaterThan(size.width * 0.85));
        } else {
          // A grid: more than one customer to a row.
          final second = tester.getRect(find.byType(CustomerCard).at(1));
          expect(second.top, closeTo(first.top, 1));
        }

        // And their page, with their one design as a card.
        await openCustomer(tester, 'Ahmed');
        expect(find.byType(CustomerDesignCard), findsOneWidget);
        expect(overflowing(), isEmpty, reason: overflowing().join('\n'));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
