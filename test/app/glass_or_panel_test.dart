import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/app.dart';
import 'package:proframe/app/inspector/material_form.dart';
import 'package:proframe/app/state/tools.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/infill.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'new_design.dart';
import 'pause_and_take_it_back_test.dart' as sheet;

// Glass or panel, on the real app, category by category. The user's words:
// *door and door & window — ask at startup. Window and sliding — a material
// tool in the workspace. In every category the user decides panel versus
// glass, and the application does not decide for them.*

Future<ProviderContainer> start(
  WidgetTester tester,
  String card, {
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
  await toTheCategories(tester);
  await chooseDesign(tester, card, answerConstruction: true);
  return container;
}

/// Draws the door the way the user draws it, as strokes on the sheet, and
/// reads it: an outline and — unless [transom] is false — a line across it.
Future<void> drawDoor(
  WidgetTester tester,
  ProviderContainer c, {
  bool transom = true,
  List<Stroke> more = const [],
}) async {
  final controller = c.read(workspaceProvider.notifier);
  controller.state = controller.state.copyWith(
    design: controller.state.design.copyWith(
      sketch: Sketch(
        strokes: [
          sheet.pen('outline', const [
            Vec2(0, 0),
            Vec2(1000, 0),
            Vec2(1000, 2100),
            Vec2(0, 2100),
            Vec2(0, 0),
          ]),
          if (transom)
            sheet.pen('transom', const [Vec2(0, 700), Vec2(1000, 700)]),
          ...more,
        ],
      ),
    ),
  );
  controller.readDrawing();
  await tester.pumpAndSettle();
}

Future<void> tapIn(WidgetTester tester, Finder within, Finder what) async {
  final target = find.descendant(of: within, matching: what).first;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key)).first;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Finder partRow(String id) => find.byKey(ValueKey('part-$id'));

Design designOf(ProviderContainer c) => c.read(workspaceProvider).design;

(SectionElement, SectionElement) upperAndLower(Design design) {
  final parts = [...Infill.partsOf(design)]
    ..sort((a, b) => a.outline.top.compareTo(b.outline.top));
  return (parts.first, parts.last);
}

String geometryOf(Design design) => jsonEncode({
  'frame': design.frame?.toJson(),
  'dividers': [for (final d in design.dividers) d.toJson()],
  'sections': [
    for (final s in design.sections)
      {'id': s.id, 'outline': s.outline.toJson(), 'parent': s.parentId},
  ],
});

const alertKey = ValueKey('construction-panel');

List<String> overflowing(WidgetTester tester) => [
  for (final r in tester.allRenderObjects)
    if (r is RenderFlex && r.toStringShort().contains('OVERFLOWING'))
      r.debugCreator.toString().split('\n').first,
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('a door is asked as it starts', () {
    testWidgets('the question is put, with the three choices', (tester) async {
      await start(tester, 'DOOR');
      expect(find.text('How should this door be constructed?'), findsOneWidget);
      expect(find.text('Entire design = Panel'), findsOneWidget);
      expect(find.text('Entire design = Glass'), findsOneWidget);
      expect(find.text('Both Panel + Glass'), findsOneWidget);
    });

    testWidgets('1 — entire design = panel: every part drawn is a panel in '
        'the colour chosen', (tester) async {
      final c = await start(tester, 'DOOR');
      await tapKey(tester, 'construction-panel');
      expect(find.text('What colour is the panel?'), findsOneWidget);
      // Nothing is chosen for the user: Continue waits for a colour.
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('construction-continue')),
            )
            .onPressed,
        isNull,
      );
      await tapKey(tester, 'look-panel-White');
      await tapKey(tester, 'construction-continue');
      expect(find.byKey(alertKey), findsNothing);
      expect(designOf(c).construction, Construction.panel);

      await drawDoor(tester, c);
      await notNowToSizes(tester);
      final parts = Infill.partsOf(designOf(c));
      expect(parts, hasLength(2), reason: 'the two parts drawn, and no more');
      for (final part in parts) {
        expect(part.finish, PanelColour.white.finish);
      }
    });

    testWidgets('2 — entire design = glass: every part drawn is the glass '
        'chosen', (tester) async {
      final c = await start(tester, 'DOOR');
      await tapKey(tester, 'construction-glass');
      expect(find.text('What glass is it?'), findsOneWidget);
      await tapKey(tester, 'look-glass-Frosted');
      await tapKey(tester, 'construction-continue');
      await drawDoor(tester, c);
      await notNowToSizes(tester);
      for (final part in Infill.partsOf(designOf(c))) {
        expect(part.finish, GlassLook.frosted.finish);
      }
    });

    testWidgets('3 — both: exactly the parts the user names receive what '
        'they say, and nothing is chosen for them', (tester) async {
      final c = await start(tester, 'DOOR');
      await tapKey(tester, 'construction-both');
      // Both goes straight to the drawing; nothing is divided for them.
      expect(find.byKey(alertKey), findsNothing);
      expect(designOf(c).construction, Construction.both);

      await drawDoor(tester, c);
      final drawn = designOf(c);
      final (upper, lower) = upperAndLower(drawn);
      expect(
        find.text('Which parts should be glass and which should be panel?'),
        findsOneWidget,
      );
      // Neither part is said until the user says it, and Done waits.
      Finder done() => find.byKey(const ValueKey('parts-done'));
      expect(tester.widget<FilledButton>(done()).onPressed, isNull);

      await tapIn(tester, partRow(upper.id), find.text('Glass'));
      await tapIn(
        tester,
        partRow(upper.id),
        find.byKey(const ValueKey('look-glass-Frosted')),
      );
      expect(tester.widget<FilledButton>(done()).onPressed, isNull);
      await tapIn(tester, partRow(lower.id), find.text('Panel'));
      await tapIn(
        tester,
        partRow(lower.id),
        find.byKey(const ValueKey('look-panel-White')),
      );
      await tapKey(tester, 'parts-done');

      final said = designOf(c);
      expect(said.sectionById(upper.id)!.finish, GlassLook.frosted.finish);
      expect(said.sectionById(lower.id)!.finish, PanelColour.white.finish);
      expect(geometryOf(said), geometryOf(drawn), reason: 'nothing moved');
      expect(said.partsAsked, isTrue);
      await notNowToSizes(tester);
      expect(
        find.text('Which parts should be glass and which should be panel?'),
        findsNothing,
        reason: 'asked once',
      );

      // It lasts through every view.
      final controller = c.read(workspaceProvider.notifier);
      for (final view in WorkspaceView.values) {
        controller.showView(view);
        await tester.pumpAndSettle();
        expect(
          designOf(c).sectionById(upper.id)!.finish,
          GlassLook.frosted.finish,
        );
        expect(
          designOf(c).sectionById(lower.id)!.finish,
          PanelColour.white.finish,
        );
      }
    });

    testWidgets('one part only: nothing is divided — it says so, and Draw '
        'divider puts the user back on the drawing', (tester) async {
      final c = await start(tester, 'DOOR');
      await tapKey(tester, 'construction-both');
      await drawDoor(tester, c, transom: false);
      expect(Infill.partsOf(designOf(c)), hasLength(1));
      expect(
        find.text('Your design has no internal division yet'),
        findsOneWidget,
      );
      final before = geometryOf(designOf(c));

      await tapKey(tester, 'draw-divider');
      final state = c.read(workspaceProvider);
      expect(state.tool, Tool.line);
      expect(state.view, WorkspaceView.draw);
      expect(geometryOf(designOf(c)), before, reason: 'nothing divided');
      expect(state.partsQuestion, isNull);

      // The user draws their divider and reads it: now the parts are asked.
      await drawDoor(tester, c);
      expect(Infill.partsOf(designOf(c)), hasLength(2));
      expect(
        find.text('Which parts should be glass and which should be panel?'),
        findsOneWidget,
      );
    });

    testWidgets('Not now puts it away for good, and the drawing is read as '
        'it always was', (tester) async {
      final c = await start(tester, 'DOOR');
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.byKey(alertKey), findsNothing);
      expect(designOf(c).construction, isNull);
      await drawDoor(tester, c);
      expect(find.byKey(alertKey), findsNothing);
      expect(c.read(workspaceProvider).partsQuestion, isNull);
    });
  });

  testWidgets('a door & window set is asked the same, about the whole '
      'design', (tester) async {
    final c = await start(tester, 'DOOR & WINDOW');
    expect(find.text('How should this design be constructed?'), findsOneWidget);
    await tapKey(tester, 'construction-both');
    expect(designOf(c).construction, Construction.both);
  });

  testWidgets('a door & window set: a leaf is still asked whether it is a '
      'door or a window, and the parts are asked after', (tester) async {
    final c = await start(tester, 'DOOR & WINDOW');
    await tapKey(tester, 'construction-both');
    await sheet.twoLeaves(c);
    await tester.pumpAndSettle();
    // The opening rule is untouched: the leaves are asked about first.
    expect(find.text('Opening type'), findsOneWidget);
    expect(c.read(workspaceProvider).partsQuestion, isNull);
    for (final opening in designOf(c).openingsInOrder) {
      c
          .read(workspaceProvider.notifier)
          .answer(WorkspaceState.openingKindQuestion(opening.id), 'door');
    }
    await tester.pumpAndSettle();
    expect(
      find.text('Which parts should be glass and which should be panel?'),
      findsOneWidget,
    );
  });

  group('a window and a sliding set are not asked; the Material tool is '
      'there instead', () {
    Future<void> useMaterial(
      WidgetTester tester,
      ProviderContainer c,
      String partId,
      String fill,
      String look,
    ) async {
      await tapIn(
        tester,
        find.byKey(ValueKey('material-$partId')),
        find.text(fill),
      );
      await tapIn(
        tester,
        find.byKey(ValueKey('material-$partId')),
        find.byKey(ValueKey('look-${fill.toLowerCase()}-$look')),
      );
    }

    testWidgets('5 — window: no alert; pick a part, Material, Glass', (
      tester,
    ) async {
      final c = await start(tester, 'WINDOW');
      expect(find.byKey(alertKey), findsNothing);
      expect(designOf(c).construction, isNull);
      await sheet.twoLeaves(c);
      await notNowToSizes(tester);
      expect(find.byKey(alertKey), findsNothing);

      final part = Infill.partsOf(designOf(c)).first;
      final before = geometryOf(designOf(c));
      c.read(workspaceProvider.notifier).select(part.id);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Material'));
      await tester.pumpAndSettle();
      expect(find.byType(MaterialForm), findsOneWidget);

      // Made a panel, then glass: whichever it was, it is what they say.
      await useMaterial(tester, c, part.id, 'Panel', 'Black');
      expect(
        designOf(c).sectionById(part.id)!.finish,
        PanelColour.black.finish,
      );
      await useMaterial(tester, c, part.id, 'Glass', 'Tinted');
      expect(designOf(c).sectionById(part.id)!.finish, GlassLook.tinted.finish);
      expect(geometryOf(designOf(c)), before);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.byType(MaterialForm), findsNothing);
    });

    testWidgets('6 — sliding: no alert; Material, Panel', (tester) async {
      final c = await start(tester, 'SLIDING');
      expect(find.byKey(alertKey), findsNothing);
      await sheet.twoLeaves(c);
      await notNowToSizes(tester);
      expect(find.byKey(alertKey), findsNothing);
      final parts = Infill.partsOf(designOf(c));
      final part = parts.last;
      final others = {
        for (final p in parts)
          if (p.id != part.id) p.id: jsonEncode(p.toJson()),
      };
      await tester.tap(find.byTooltip('Material'));
      await tester.pumpAndSettle();
      await useMaterial(tester, c, part.id, 'Panel', 'Grey');
      expect(designOf(c).sectionById(part.id)!.finish, PanelColour.grey.finish);
      for (final entry in others.entries) {
        expect(
          jsonEncode(designOf(c).sectionById(entry.key)!.toJson()),
          entry.value,
          reason: 'every other part as it was',
        );
      }
    });

    testWidgets('4 — the door said at the start is changed later with the '
        'same tool, upper glass to panel and lower panel to glass', (
      tester,
    ) async {
      final c = await start(tester, 'DOOR');
      await tapKey(tester, 'construction-both');
      await drawDoor(tester, c);
      final drawn = designOf(c);
      final (upper, lower) = upperAndLower(drawn);
      c.read(workspaceProvider.notifier).assignParts({
        upper.id: GlassLook.clear.finish,
        lower.id: PanelColour.white.finish,
      });
      await tester.pumpAndSettle();
      await notNowToSizes(tester);

      await tester.tap(find.byTooltip('Material'));
      await tester.pumpAndSettle();
      await useMaterial(tester, c, upper.id, 'Panel', 'Brown');
      await useMaterial(tester, c, lower.id, 'Glass', 'Clear');
      final changed = designOf(c);
      expect(Infill.isPanel(changed.sectionById(upper.id)!.finish), isTrue);
      expect(Infill.isGlass(changed.sectionById(lower.id)!.finish), isTrue);
      expect(geometryOf(changed), geometryOf(drawn), reason: 'only material');
    });
  });

  for (final size in const [Size(360, 740), Size(820, 1180), Size(1280, 820)]) {
    testWidgets('the alerts and the tool fit at ${size.width.toInt()} × '
        '${size.height.toInt()}', (tester) async {
      final c = await start(tester, 'DOOR', size: size);
      expect(overflowing(tester), isEmpty);
      await tapKey(tester, 'construction-both');
      await drawDoor(tester, c);
      expect(overflowing(tester), isEmpty);
      final (upper, _) = upperAndLower(designOf(c));
      await tapIn(tester, partRow(upper.id), find.text('Panel'));
      expect(overflowing(tester), isEmpty);
      await tester.ensureVisible(find.text('Later'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(designOf(c).partsAsked, isTrue);
      await notNowToSizes(tester);
      await tester.tap(find.byTooltip('Material'));
      await tester.pumpAndSettle();
      expect(overflowing(tester), isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
