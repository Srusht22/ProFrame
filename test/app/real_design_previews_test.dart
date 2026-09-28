import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/design_preview.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/screens/designs_screen.dart';
import 'package:proframe/app/screens/workspace_screen.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/customer.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a_customer_s_page_test.dart' as page;
import 'customers_screen_test.dart' as customers;
import 'opening_an_existing_design_test.dart' as existing;
import 'the_designs_screen_test.dart' as screen;

// The picture on a card is the saved design, drawn from its own geometry —
// the Basement Door card shows the Basement Door, the Kitchen Window card
// the Kitchen Window — and nothing else: no photograph, no generated
// picture, no geometry made up. A design with nothing to draw says so, one
// that cannot be read says so, and opening a card reads the design itself.

const phone = Size(390, 844);

/// A window drawn the way the user draws one: an outline, a mullion, a
/// transom across the right light, and a `>` in the left.
Design kitchenWindow(Customer adam) {
  final base = Design.empty(
    id: 'kitchen-window',
    kind: DesignKind.window,
    name: 'Kitchen Window',
    customerId: adam.id,
    now: DateTime(2026, 3, 1, 10),
  );
  return SketchInterpreter.interpret(
    base.copyWith(
      sketch: Sketch(
        strokes: [
          existing.pen('outline', const [
            Vec2(0, 0),
            Vec2(1800, 0),
            Vec2(1800, 1200),
            Vec2(0, 1200),
            Vec2(0, 0),
          ]),
          existing.pen('mullion', const [Vec2(700, 0), Vec2(700, 1200)]),
          existing.pen('transom', const [Vec2(700, 500), Vec2(1800, 500)]),
          existing.pen('mark', const [
            Vec2(200, 400),
            Vec2(500, 600),
            Vec2(200, 800),
          ]),
        ],
      ),
    ),
  ).design.copyWith(updatedAt: DateTime(2026, 3, 1, 10));
}

/// Adam's drawn Basement Door and Kitchen Window; a design begun and not
/// drawn; one whose only strokes are not read yet; one whose only mark is
/// a dot; and one whose record cannot be read.
Future<Customer> keepAdam() async {
  final people = CustomerStore();
  final store = DesignStore(customers: people);
  final adam = await people.create(name: 'Adam', now: DateTime(2026, 3, 1));
  await store.save(existing.basementDoor(adam));
  await store.save(kitchenWindow(adam));
  await store.save(
    Design.empty(
      id: 'third-floor',
      kind: DesignKind.sliding,
      name: 'Third Floor Sliding',
      customerId: adam.id,
      now: DateTime(2026, 3, 1, 8),
    ),
  );
  await store.save(
    Design.empty(
      id: 'sketched',
      kind: DesignKind.door,
      name: 'Garage Door',
      customerId: adam.id,
      now: DateTime(2026, 3, 1, 7),
    ).copyWith(
      sketch: Sketch(
        strokes: [
          existing.pen('s1', const [Vec2(0, 0), Vec2(900, 0), Vec2(900, 2000)]),
        ],
      ),
      updatedAt: DateTime(2026, 3, 1, 7),
    ),
  );
  await store.save(
    Design.empty(
      id: 'dot',
      kind: DesignKind.window,
      name: 'Loft Window',
      customerId: adam.id,
      now: DateTime(2026, 3, 1, 6),
    ).copyWith(
      sketch: const Sketch(
        strokes: [
          Stroke(
            id: 'tap',
            samples: [StrokeSample(Vec2(5, 5)), StrokeSample(Vec2(5, 5))],
          ),
        ],
      ),
      updatedAt: DateTime(2026, 3, 1, 6),
    ),
  );
  await store.save(
    Design.empty(
      id: 'broken',
      kind: DesignKind.door,
      name: 'Shed Door',
      customerId: adam.id,
      now: DateTime(2026, 3, 1, 5),
    ),
  );
  // Its record spoiled on the device, its line in the index still there.
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('${DesignStore.designKeyPrefix}broken', '{"id": ');
  return adam;
}

Future<Design> stored(WidgetTester tester, String id) async =>
    (await tester.runAsync(() => DesignStore().load(id)))!;

Finder designCard(String id) => find.byWidgetPredicate(
  (w) =>
      (w is DesignCard && w.summary.id == id) ||
      (w is CustomerDesignCard && w.design.id == id),
);

/// The painter drawing the picture on the card of design [id], or null
/// where the card shows no drawing.
DesignPreviewPainter? painterOn(WidgetTester tester, String id) {
  for (final paint in tester.widgetList<CustomPaint>(
    find.descendant(of: designCard(id), matching: find.byType(CustomPaint)),
  )) {
    if (paint.painter case final DesignPreviewPainter p) return p;
  }
  return null;
}

Finder onCard(String id, String text) =>
    find.descendant(of: designCard(id), matching: find.text(text));

/// The picture on the card of [id], as the screen has it.
Future<(Size, Uint8List)> cardPixels(WidgetTester tester, String id) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find
        .ancestor(
          of: find.descendant(
            of: designCard(id),
            matching: find.byType(DesignPreview),
          ),
          matching: find.byType(RepaintBoundary),
        )
        .first,
  );
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return (boundary.size, bytes!);
}

/// [design] drawn by the preview painter alone, at [size].
Future<Uint8List> drawnAlone(
  WidgetTester tester,
  Design design,
  Size size,
) async {
  final bytes = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    DesignPreviewPainter(design).paint(Canvas(recorder), size);
    final image = await recorder.endRecording().toImage(
      size.width.round(),
      size.height.round(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the Basement Door card shows the Basement Door and the Kitchen '
      'Window card the Kitchen Window — each drawn from its saved geometry, '
      'on the designs list and on Adam\'s page', (tester) async {
    await keepAdam();
    await screen.openTheApp(tester, size: phone);
    final door = await stored(tester, 'basement-door');
    final window = await stored(tester, 'kitchen-window');

    Future<void> check() async {
      for (final design in [door, window]) {
        final painter = painterOn(tester, design.id);
        expect(painter, isNotNull, reason: design.name);
        expect(
          jsonEncode(painter!.design.toJson()),
          jsonEncode(design.toJson()),
          reason: '${design.name}: the saved design itself',
        );
      }
      // Pixel for pixel, the card is the painter drawing that design and
      // nothing laid over it.
      final (size, onScreen) = await cardPixels(tester, 'basement-door');
      expect(onScreen, await drawnAlone(tester, door, size));
      final (_, other) = await cardPixels(tester, 'kitchen-window');
      expect(other, isNot(onScreen), reason: 'two designs, two pictures');
      expect(find.byType(Image), findsNothing);
      expect(find.byType(RawImage), findsNothing);
    }

    await check();
    await customers.toCustomers(tester);
    await page.openCustomer(tester, 'Adam');
    for (final id in ['kitchen-window', 'basement-door']) {
      await tester.scrollUntilVisible(
        find.byKey(CustomerScreen.designKey(id)),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final painter = painterOn(tester, id);
      expect(
        jsonEncode(painter!.design.toJson()),
        jsonEncode((await stored(tester, id)).toJson()),
      );
    }
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('a design with nothing drawn, or only a dot, says "Nothing '
      'drawn yet" — no geometry is made up for it', (tester) async {
    await keepAdam();
    await screen.openTheApp(tester, size: phone);
    for (final id in ['third-floor', 'dot']) {
      await tester.scrollUntilVisible(
        designCard(id),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(painterOn(tester, id), isNull, reason: id);
      expect(onCard(id, PreviewPlaceholder.nothingDrawnLabel), findsOneWidget);
    }
  });

  testWidgets('strokes not read yet are drawn as the strokes themselves', (
    tester,
  ) async {
    await keepAdam();
    await screen.openTheApp(tester, size: phone);
    await tester.scrollUntilVisible(
      designCard('sketched'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final painter = painterOn(tester, 'sketched')!;
    expect(painter.design.frame, isNull);
    expect(
      jsonEncode(painter.design.sketch.toJson()),
      jsonEncode((await stored(tester, 'sketched')).sketch.toJson()),
    );
    final (size, onScreen) = await cardPixels(tester, 'sketched');
    final blank = await drawnAlone(
      tester,
      Design.empty(id: 'blank', kind: DesignKind.door, name: 'Blank'),
      size,
    );
    expect(onScreen, isNot(blank), reason: 'the strokes are drawn');
  });

  testWidgets('a design that cannot be read says "Preview unavailable" — not '
      'that it is empty — and opening it begins nothing', (tester) async {
    await keepAdam();
    final c = await screen.openTheApp(tester, size: phone);
    await tester.scrollUntilVisible(
      designCard('broken'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(painterOn(tester, 'broken'), isNull);
    expect(
      onCard('broken', PreviewPlaceholder.unavailableLabel),
      findsOneWidget,
    );
    expect(
      onCard('broken', PreviewPlaceholder.nothingDrawnLabel),
      findsNothing,
    );
    final inHand = c.read(workspaceProvider).design.id;
    await tester.tap(find.byKey(DesignCard.openKey('broken')));
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceScreen), findsNothing);
    expect(find.text('Shed Door could not be opened.'), findsOneWidget);
    expect(c.read(workspaceProvider).design.id, inHand);
  });

  testWidgets('when the saved design changes, its picture changes with it', (
    tester,
  ) async {
    final adam = await keepAdam();
    final c = await screen.openTheApp(tester, size: phone);
    final (size, before) = await cardPixels(tester, 'kitchen-window');

    // The window kept again with one more line: a second mullion.
    final window = kitchenWindow(adam);
    final changed = SketchInterpreter.interpret(
      window.copyWith(
        sketch: Sketch(
          strokes: [
            ...window.sketch.strokes,
            existing.pen('mullion2', const [Vec2(1300, 500), Vec2(1300, 1200)]),
          ],
        ),
      ),
    ).design.copyWith(updatedAt: DateTime(2026, 3, 2));
    await tester.runAsync(() => DesignStore().save(changed));
    c.read(designsRevisionProvider.notifier).changed();
    await tester.pumpAndSettle();

    final painter = painterOn(tester, 'kitchen-window')!;
    expect(
      jsonEncode(painter.design.toJson()),
      jsonEncode((await stored(tester, 'kitchen-window')).toJson()),
    );
    final (_, after) = await cardPixels(tester, 'kitchen-window');
    expect(after, isNot(before));
    expect(after, await drawnAlone(tester, painter.design, size));
  });

  testWidgets('the picture is only a picture: opening the card reads the '
      'saved design itself', (tester) async {
    await keepAdam();
    final c = await screen.openTheApp(tester, size: phone);
    final saved = await stored(tester, 'basement-door');
    await tester.scrollUntilVisible(
      find.byKey(DesignCard.openKey('basement-door')),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DesignCard.openKey('basement-door')));
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceScreen), findsOneWidget);
    final inHand = c.read(workspaceProvider).design;
    expect(jsonEncode(inHand.toJson()), jsonEncode(saved.toJson()));
    expect(inHand.openings, hasLength(1));
    expect(inHand.sections.length, greaterThan(2));
  });

  test('a preview is drawn only from what the design holds', () {
    final empty = Design.empty(id: 'e', kind: DesignKind.door, name: 'E');
    expect(DesignPreview.shows(empty), isFalse);
    expect(
      DesignPreview.shows(
        empty.copyWith(
          sketch: const Sketch(
            strokes: [
              Stroke(
                id: 'dot',
                samples: [StrokeSample(Vec2(1, 1)), StrokeSample(Vec2(1, 1))],
              ),
            ],
          ),
        ),
      ),
      isFalse,
      reason: 'a dot has nothing to draw',
    );
    expect(
      DesignPreview.shows(
        empty.copyWith(
          sketch: Sketch(
            strokes: [
              existing.pen('l', const [Vec2(0, 0), Vec2(100, 0)]),
            ],
          ),
        ),
      ),
      isTrue,
    );
  });

  testWidgets('pictures and placeholders fit a phone, a tablet and a laptop', (
    tester,
  ) async {
    await keepAdam();
    for (final size in const [
      Size(360, 740),
      phone,
      Size(820, 1180),
      Size(1280, 860),
    ]) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await screen.openTheApp(tester, size: size);
      expect(page.overflowing(tester), isEmpty, reason: 'list at $size');
      await customers.toCustomers(tester);
      await page.openCustomer(tester, 'Adam');
      expect(page.overflowing(tester), isEmpty, reason: 'page at $size');
    }
  });
}
