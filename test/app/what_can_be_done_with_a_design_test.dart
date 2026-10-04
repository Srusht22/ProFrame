import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/screens/designs_screen.dart';
import 'package:proframe/app/screens/workspace_screen.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'the_designs_screen_test.dart' as screen;

// The user's screenshot of their designs on a phone: *why is there nothing
// here — what if I want to delete one of them, or other things?* So every
// design's card — on its customer's page, which is where designs are shown
// — has a ⋮, and pressing and holding a card does the same: open, edit
// information, duplicate and delete, each in words.

Future<List<Design>> kept(WidgetTester tester) async =>
    (await tester.runAsync(DesignStore().all))!;

/// The ⋮ on [design]'s card, on its customer's page — opened from the
/// customers the app opens on, unless that page is already showing.
Future<void> actionsFor(WidgetTester tester, Design design) async {
  if (find.byType(CustomerScreen).evaluate().isEmpty) {
    await screen.openCustomer(tester, design.customer!);
  }
  final more = find.byKey(CustomerDesignCard.moreKey(design.id));
  await tester.ensureVisible(more);
  await tester.pumpAndSettle();
  await tester.tap(more);
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

  testWidgets('every card offers open, edit information, duplicate and '
      'delete', (tester) async {
    final designs = await screen.keepThree();
    await screen.openTheApp(tester, size: const Size(390, 844));
    for (final design in designs) {
      await screen.openCustomer(tester, design.customer!);
      expect(find.byKey(CustomerDesignCard.moreKey(design.id)), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    await actionsFor(tester, designs.first);
    expect(find.byType(DesignActionsSheet), findsOneWidget);
    for (final label in ['Open', 'Edit information', 'Duplicate', 'Delete']) {
      expect(
        find.descendant(
          of: find.byType(DesignActionsSheet),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
    // Who a design is for is changed on the customer, not the design.
    expect(find.text('Rename'), findsNothing);
    expect(overflowing(tester), isEmpty);
  });

  testWidgets('pressing and holding a card offers the same', (tester) async {
    final designs = await screen.keepThree();
    await screen.openTheApp(tester, size: const Size(390, 844));
    await screen.openCustomer(tester, designs.first.customer!);
    await tester.ensureVisible(find.byType(CustomerDesignCard));
    await tester.pumpAndSettle();
    await tester.longPress(find.byType(CustomerDesignCard));
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
      expect(find.text('Delete ${designs.first.name}?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await kept(tester), hasLength(3));
      expect(screen.cardsShown(tester), [designs.first.id]);
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
      // Karwan's only design: his page stays, and says so.
      expect(find.byType(CustomerDesignCard), findsNothing);
      expect(find.text('No designs yet'), findsOneWidget);
      expect(find.text('${designs.first.name} deleted'), findsOneWidget);
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
      expect(screen.cardsShown(tester), [designs.first.id]);
    });
  });

  testWidgets('duplicate keeps a copy with a number of its own — another '
      'design of the same customer — and the original untouched', (
    tester,
  ) async {
    final designs = await screen.keepThree();
    await screen.openTheApp(tester);
    await actionsFor(tester, designs.first);
    await choose(tester, DesignAction.duplicate);

    final all = await kept(tester);
    expect(all, hasLength(4));
    final copy = all.firstWhere(
      (d) => d.name == '${designs.first.name} (copy)',
    );
    expect(copy.id, isNot(designs.first.id));
    expect(
      DesignSummary.of(copy).number,
      isNot(DesignSummary.of(designs.first).number),
    );
    // The same customer's: a second design of theirs, not a second person.
    expect(copy.customerId, designs.first.customerId);
    expect(copy.customer, designs.first.customer);
    // The same design: drawing, geometry and everything said about it.
    Map<String, Object?> content(Design d) => d.toJson()
      ..remove('id')
      ..remove('name')
      ..remove('createdAt')
      ..remove('updatedAt');
    expect(jsonEncode(content(copy)), jsonEncode(content(designs.first)));
    final original = all.firstWhere((d) => d.id == designs.first.id);
    expect(jsonEncode(original.toJson()), jsonEncode(designs.first.toJson()));
    // Both on Karwan's page, the copy and the original.
    expect(screen.cardsShown(tester), unorderedEquals([copy.id, original.id]));
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
