import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/screens/designs_screen.dart';
import 'package:proframe/app/screens/workspace_screen.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'the_designs_screen_test.dart' as screen;

// The user's screenshot of Recent Designs on a phone: *why is there nothing
// here — what if I want to delete one of them, or other things?* So every
// card has a ⋮, and pressing and holding a card does the same: open,
// rename, duplicate and delete, each in words.

Future<List<Design>> kept(WidgetTester tester) async =>
    (await tester.runAsync(DesignStore().all))!;

Future<void> actionsFor(WidgetTester tester, Design design) async {
  await tester.tap(find.byKey(DesignCard.moreKey(design.id)));
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, DesignAction action) async {
  await tester.tap(find.byKey(ValueKey('design-action-${action.name}')));
  await tester.pumpAndSettle();
}

List<String> overflowing(WidgetTester tester) => [
  for (final r in tester.allRenderObjects)
    if (r is RenderFlex && r.toStringShort().contains('OVERFLOWING'))
      r.debugCreator.toString().split('\n').first,
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('every card offers open, rename, duplicate and delete', (
    tester,
  ) async {
    final designs = await screen.keepThree();
    await screen.openTheApp(tester, size: const Size(390, 844));
    for (final design in designs) {
      expect(find.byKey(DesignCard.moreKey(design.id)), findsOneWidget);
    }
    await actionsFor(tester, designs.first);
    expect(find.byType(DesignActionsSheet), findsOneWidget);
    for (final label in ['Open', 'Rename', 'Duplicate', 'Delete']) {
      expect(
        find.descendant(
          of: find.byType(DesignActionsSheet),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
    expect(overflowing(tester), isEmpty);
  });

  testWidgets('pressing and holding a card offers the same', (tester) async {
    final designs = await screen.keepThree();
    await screen.openTheApp(tester, size: const Size(390, 844));
    await tester.longPress(find.text(designs.first.customer!));
    await tester.pumpAndSettle();
    expect(find.byType(DesignActionsSheet), findsOneWidget);
  });

  group('delete', () {
    testWidgets('is asked about first, and Cancel keeps the design', (
      tester,
    ) async {
      final designs = await screen.keepThree();
      await screen.openTheApp(tester);
      await actionsFor(tester, designs.first);
      await choose(tester, DesignAction.delete);
      expect(find.text('Delete Karwan?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await kept(tester), hasLength(3));
      expect(find.text('Karwan'), findsOneWidget);
    });

    testWidgets('removes that design and no other, from the list and the '
        'store', (tester) async {
      final designs = await screen.keepThree();
      await screen.openTheApp(tester);
      await actionsFor(tester, designs.first);
      await choose(tester, DesignAction.delete);
      await tester.tap(find.byKey(const ValueKey('confirm-delete')));
      await tester.pumpAndSettle();

      final left = await kept(tester);
      expect(left.map((d) => d.customer), unorderedEquals(['Ahmed', 'Sara']));
      expect(find.byType(DesignCard), findsNWidgets(2));
      expect(find.text('Karwan deleted'), findsOneWidget);
      // The other two are exactly as they were.
      for (final design in designs.skip(1)) {
        final now = left.firstWhere((d) => d.id == design.id);
        expect(jsonEncode(now.toJson()), jsonEncode(design.toJson()));
      }
    });

    testWidgets('can be undone straight afterwards, and the design comes '
        'back whole', (tester) async {
      final designs = await screen.keepThree();
      await screen.openTheApp(tester);
      await actionsFor(tester, designs.first);
      await choose(tester, DesignAction.delete);
      await tester.tap(find.byKey(const ValueKey('confirm-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      final back = await kept(tester);
      expect(back, hasLength(3));
      final karwan = back.firstWhere((d) => d.id == designs.first.id);
      expect(jsonEncode(karwan.toJson()), jsonEncode(designs.first.toJson()));
      expect(find.text('Karwan'), findsOneWidget);
    });
  });

  testWidgets('rename changes who it is for and nothing else', (tester) async {
    final designs = await screen.keepThree();
    await screen.openTheApp(tester);
    await actionsFor(tester, designs.first);
    await choose(tester, DesignAction.rename);
    final field = find.byKey(const ValueKey('rename-customer'));
    expect(tester.widget<TextField>(field).controller!.text, 'Karwan');
    await tester.enterText(field, '');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
      reason: 'a design is always for somebody',
    );
    await tester.enterText(field, 'Karwan Ali');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final renamed = (await kept(tester))
        .firstWhere((d) => d.id == designs.first.id);
    expect(renamed.customer, 'Karwan Ali');
    expect(find.text('Karwan Ali'), findsOneWidget);
    // Only who it is for: the drawing and the geometry are as they were.
    final before = designs.first.toJson()
      ..remove('customer')
      ..remove('updatedAt');
    final after = renamed.toJson()
      ..remove('customer')
      ..remove('updatedAt');
    expect(jsonEncode(after), jsonEncode(before));
  });

  testWidgets('duplicate keeps a copy with a number of its own, and the '
      'original untouched', (tester) async {
    final designs = await screen.keepThree();
    await screen.openTheApp(tester);
    await actionsFor(tester, designs.first);
    await choose(tester, DesignAction.duplicate);

    final all = await kept(tester);
    expect(all, hasLength(4));
    final copy = all.firstWhere((d) => d.customer == 'Karwan (copy)');
    expect(copy.id, isNot(designs.first.id));
    expect(
      DesignSummary.of(copy).number,
      isNot(DesignSummary.of(designs.first).number),
    );
    // The same design: drawing, geometry and everything said about it.
    Map<String, Object?> content(Design d) => d.toJson()
      ..remove('id')
      ..remove('customer')
      ..remove('createdAt')
      ..remove('updatedAt');
    expect(jsonEncode(content(copy)), jsonEncode(content(designs.first)));
    final original = all.firstWhere((d) => d.id == designs.first.id);
    expect(jsonEncode(original.toJson()), jsonEncode(designs.first.toJson()));
    expect(find.text('Karwan (copy)'), findsOneWidget);
  });

  testWidgets('open from the sheet opens it exactly as saved', (tester) async {
    final designs = await screen.keepThree();
    final c = await screen.openTheApp(tester);
    await actionsFor(tester, designs.last);
    await choose(tester, DesignAction.open);
    expect(find.byType(WorkspaceScreen), findsOneWidget);
    expect(
      jsonEncode(c.read(workspaceProvider).design.toJson()),
      jsonEncode(designs.last.toJson()),
    );
  });
}
