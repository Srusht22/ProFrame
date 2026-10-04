import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/cad_painter.dart';
import 'package:proframe/app/canvas/design_painter.dart';
import 'package:proframe/app/inspector/geometry_check_panel.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/state/tools.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/an_angled_design_keeps_its_geometry_test.dart'
    show rakedWithOpening;
import '../domain/geometry_normalizer_test.dart' show pen;
import 'a_customer_s_page_test.dart' as page;
import 'a_design_in_every_view_test.dart' as every;
import 'customers_screen_test.dart' as customers;
import 'new_design.dart' show notNowToSizes;
import 'the_designs_screen_test.dart' as screen;

// What the check of an angled design finds is shown on the real app: under
// the drawing, in words, with how much it matters and a way to see the part
// — and only for an angled design, only while the geometry on the screen
// has the problem, and without anything in the design changing.

const phone = Size(390, 844);
const tablet = Size(800, 1100);

/// [strokes] read as a design of [kind] kept under [id].
Design read(List<Stroke> strokes, String id, {required DesignKind kind}) =>
    SketchInterpreter.interpret(
      Design.empty(
        id: id,
        kind: kind,
      ).copyWith(sketch: Sketch(strokes: strokes)),
    ).design;

/// A raked window with a mullion and a leaf, read, its leaf said to be a
/// window — so nothing is asked when it is opened.
Design raked({DesignKind kind = DesignKind.angled, String id = 'raked'}) {
  final d = read(rakedWithOpening(), id, kind: kind);
  final opening = d.openings.single;
  return d
      .withElement(opening.copyWith(kind: DesignKind.window))
      .copyWith(name: 'Stair Window');
}

/// The same window drawn crossing itself: an error.
Design bowTie() => read(
  [
    pen('outline', const [
      Vec2(0, 0),
      Vec2(1200, 2000),
      Vec2(1200, 0),
      Vec2(0, 2000),
      Vec2(0, 0),
    ]),
  ],
  'bow',
  kind: DesignKind.angled,
).copyWith(name: 'Crossed Window');

/// [design] kept for Adam, the app opened, and the design opened from its
/// card.
Future<ProviderContainer> openFor(
  WidgetTester tester,
  Design design, {
  Size size = every.laptop,
}) async {
  await tester.runAsync(() async {
    final people = CustomerStore();
    final adam = await people.create(name: 'Adam', now: DateTime(2026, 3, 1));
    await DesignStore(customers: people)
        .save(design.copyWith(customerId: adam.id));
  });
  final c = await screen.openTheApp(tester, size: size);
  await customers.toCustomers(tester);
  await page.openCustomer(tester, 'Adam');
  final open = find.byKey(CustomerDesignCard.openKey(design.id)).hitTestable();
  await tester.scrollUntilVisible(
    open,
    100,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(open);
  await tester.pumpAndSettle();
  await notNowToSizes(tester);
  return c;
}

/// A sloped line drawn in the fixed light, touching nothing, then **Read**
/// pressed the way the user presses it.
Future<void> drawLooseLineAndRead(
  WidgetTester tester,
  ProviderContainer c,
) async {
  c
      .read(workspaceProvider.notifier)
      .addStroke(
        pen('x', const [Vec2(800, 1100), Vec2(1050, 1500)]).samples,
        tool: Tool.line,
      );
  await tester.pumpAndSettle();
  final readIt = find.text('Read my drawing').evaluate().isNotEmpty
      ? find.text('Read my drawing')
      : find.text('Read it');
  await tester.tap(readIt);
  await tester.pumpAndSettle();
  await notNowToSizes(tester);
}

Finder get panel => find.byKey(GeometryCheckPanel.panelKey);

String textOf(Design d) => jsonEncode(d.toJson());

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a valid angled design shows nothing; a problem the reading '
      'finds is shown, in words, with the part to see; put right, it goes', (
    tester,
  ) async {
    final c = await openFor(tester, raked());
    final controller = c.read(workspaceProvider.notifier);
    expect(c.read(workspaceProvider).design.kind, DesignKind.angled);
    expect(panel, findsNothing, reason: 'no false error');

    final barsBefore = {
      for (final b in c.read(workspaceProvider).design.dividers) b.id,
    };
    await drawLooseLineAndRead(tester, c);
    final read = c.read(workspaceProvider).design;
    expect(c.read(workspaceProvider).needsReading, isFalse, reason: 'read');
    final loose = read.dividers.singleWhere((b) => !barsBefore.contains(b.id));
    expect(panel, findsOneWidget);
    expect(find.text('Geometry may need review'), findsOneWidget);
    expect(find.text('1 warning'), findsOneWidget);
    expect(
      find.textContaining('A sloped bar is not connected to the frame'),
      findsOneWidget,
      reason: 'the first problem said even folded',
    );
    expect(find.textContaining(loose.id), findsNothing, reason: 'no ids');

    // Opened, then shown on the drawing — for a moment, not in the design.
    await every.showView(tester, WorkspaceView.draw);
    await tester.tap(find.byKey(GeometryCheckPanel.toggleKey));
    await tester.pumpAndSettle();
    expect(find.text('Warning'), findsOneWidget);
    expect(find.text('Error'), findsNothing, reason: 'a warning, not an error');
    final before = textOf(c.read(workspaceProvider).design);
    await tester.tap(find.byKey(GeometryCheckPanel.showKey(0)));
    await tester.pumpAndSettle();
    expect(every.painterOf<DesignPainter>(tester).highlighted, {loose.id});
    expect(textOf(c.read(workspaceProvider).design), before);
    expect(c.read(workspaceProvider).selectedId, isNull);

    // And on the technical drawing.
    await every.showView(tester, WorkspaceView.plan);
    expect(every.painterOf<CadPainter>(tester).highlighted, {loose.id});
    expect(panel, findsOneWidget, reason: 'under every view');

    // Put right: the bar the user drew connecting nothing, taken out.
    controller
      ..select(loose.id)
      ..deleteSelected();
    await tester.pumpAndSettle();
    expect(panel, findsNothing, reason: 'the stale problem is gone');
    expect(every.painterOf<CadPainter>(tester).highlighted, isEmpty);

    // Undone, the problem is back — it is the geometry's, not a record.
    controller.undo();
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);
  });

  testWidgets('an outline drawn crossing itself is an error, the two sides '
      'shown, and nothing is straightened for the user', (tester) async {
    final crossed = bowTie();
    final c = await openFor(tester, crossed);
    expect(find.text('Geometry needs attention'), findsOneWidget);
    expect(find.textContaining('error'), findsWidgets);
    await tester.tap(find.byKey(GeometryCheckPanel.toggleKey));
    await tester.pumpAndSettle();
    expect(find.text('Error'), findsWidgets);
    final crossing = find.textContaining(
      RegExp(r'cross(es)? (each other|the)'),
    );
    expect(crossing, findsOneWidget);
    await tester.tap(find.byKey(GeometryCheckPanel.showKey(0)));
    await tester.pumpAndSettle();
    final shown = every.painterOf<DesignPainter>(tester).highlighted;
    expect(shown, hasLength(2));
    final design = c.read(workspaceProvider).design;
    expect({for (final m in design.frameMembers) m.id}, containsAll(shown));
    expect(design.frame!.outline.isSimple, isFalse, reason: 'not mended');
    expect(
      textOf(design),
      textOf(
        (await tester.runAsync(
          () async => (await DesignStore().load('bow'))!,
        ))!,
      ),
      reason: 'nothing written into the design',
    );
  });

  testWidgets('from the model, Show me goes to the technical drawing to '
      'point the part out', (tester) async {
    final c = await openFor(tester, raked());
    await drawLooseLineAndRead(tester, c);
    await every.showView(tester, WorkspaceView.model);
    expect(panel, findsOneWidget);
    await tester.tap(find.byKey(GeometryCheckPanel.toggleKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(GeometryCheckPanel.showKey(0)));
    await tester.pumpAndSettle();
    expect(c.read(workspaceProvider).view, WorkspaceView.plan);
    expect(every.painterOf<CadPainter>(tester).highlighted, hasLength(1));
  });

  testWidgets('a standard design reads the same drawing exactly as before, '
      'and shows nothing', (tester) async {
    final c = await openFor(
      tester,
      raked(kind: DesignKind.window, id: 'square'),
    );
    await drawLooseLineAndRead(tester, c);
    expect(c.read(workspaceProvider).design.kind, DesignKind.window);
    expect(panel, findsNothing);
  });

  for (final (name, size) in [
    ('a phone', phone),
    ('a tablet', tablet),
    ('a laptop', every.laptop),
  ]) {
    testWidgets('it fits $name, folded and open, with several problems', (
      tester,
    ) async {
      final opening = raked().openings.single;
      final many = raked().copyWith(
        openings: [opening.copyWith(markAt: const Vec2(1000, 1500))],
        dimensions: const [
          DimensionElement(
            id: 'left',
            a: Vec2(0, 0),
            b: Vec2(0, 2000),
            statedMm: 1500,
          ),
        ],
      );
      await openFor(tester, many, size: size);
      expect(panel, findsOneWidget);
      expect(find.text('2 warnings'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(GeometryCheckPanel.toggleKey));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Warning'), findsNWidgets(2));
      final box = tester.getRect(panel);
      expect(box.left, greaterThanOrEqualTo(0));
      expect(box.right, lessThanOrEqualTo(size.width + 0.5));
      // Never more than half the screen: the drawing keeps its room.
      expect(box.height, lessThan(size.height / 2));
    });
  }
}
