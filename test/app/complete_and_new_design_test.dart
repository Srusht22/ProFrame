import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/screens/complete_bar.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/screens/design_name_screen.dart';
import 'package:proframe/app/screens/workspace_screen.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_completion.dart';
import 'package:proframe/domain/pricing/pricing_access.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/flexible_factory_pricing_test.dart' show factoryList;
import '../domain/pricing_engine_test.dart' show acceptance, door;
import 'flexible_pricing_on_screen_test.dart' show seedWith, toAdam;
import 'new_design.dart';

// Phase 33's workflow on the real app: **Complete!** reads, checks, completes
// and saves the design in hand; only a save that succeeded is said to be
// done; and **New Design** then begins another design for the same customer
// without going back through the customers.

Future<Design?> kept(WidgetTester tester, String id) =>
    tester.runAsync(() => DesignStore().load(id)).then((d) => d);

Future<List<Design>> adamsDesigns(WidgetTester tester) async {
  final all = await tester.runAsync(() async {
    final adam = (await CustomerStore().named('Adam'))!;
    final store = DesignStore();
    final page = await store.page(customerId: adam.id, limit: 100);
    return [for (final s in page.items) (await store.load(s.id))!];
  });
  return all!;
}

/// Adam's design [id] opened from its card.
Future<void> openFromCard(WidgetTester tester, String id) async {
  final open = find.byKey(CustomerDesignCard.openKey(id));
  await tester.scrollUntilVisible(
    open,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(open);
  await tester.pumpAndSettle();
  expect(find.byType(WorkspaceScreen), findsOneWidget);
}

Future<void> pressComplete(WidgetTester tester) async {
  await tester.tap(find.byKey(CompleteBar.buttonKey));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('acceptance C: Front Entrance Door completed and saved; New '
      'Design for Adam names Kitchen Window, chooses Window and draws it — '
      'a new design, Adam kept, the first one as it was', (tester) async {
    await seedWith(tester, [
      acceptance().copyWith(name: 'Front Entrance Door'),
    ], factoryList());
    await toAdam(tester);
    await openFromCard(tester, 'acceptance');

    // A draft, until it is completed.
    expect(
      find.text('Draft — press Complete! when the design is finished'),
      findsOneWidget,
    );
    expect(
      DesignCompletion.isCompleted((await kept(tester, 'acceptance'))!),
      isFalse,
    );

    await pressComplete(tester);
    expect(find.byKey(CompletedDialog.dialogKey), findsOneWidget);
    expect(find.text(CompletedDialog.success), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(CompletedDialog.nameKey)).data,
      'Front Entrance Door',
    );
    // Saved: the design on the device is completed, as it is in hand.
    final saved = (await kept(tester, 'acceptance'))!;
    expect(DesignCompletion.isCompleted(saved), isTrue);
    final adamId = saved.customerId!;

    // New Design: the same customer, asked only the name and the category.
    await tester.tap(find.byKey(CompletedDialog.newDesignKey));
    await tester.pumpAndSettle();
    expect(find.byType(DesignNameScreen), findsOneWidget);
    final screen = tester.widget<DesignNameScreen>(
      find.byType(DesignNameScreen),
    );
    expect(screen.setup.customerId, adamId);
    expect(screen.setup.name, isNull, reason: 'nothing carried over');
    await nameTheDesign(tester, 'Kitchen Window');
    await chooseDesign(tester, 'WINDOW');
    expect(find.byType(WorkspaceScreen), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(WorkspaceScreen)),
    );
    final now = container.read(workspaceProvider).design;
    expect(now.name, 'Kitchen Window');
    expect(now.kind, DesignKind.window);
    expect(now.customerId, adamId);
    expect(now.id, isNot('acceptance'));
    // Nothing of the first design: no geometry, extras or choices.
    expect(now.frame, isNull);
    expect(now.dividers, isEmpty);
    expect(now.pricing.isNone, isTrue);
    expect(DesignCompletion.isCompleted(now), isFalse);

    // Both Adam's, and the first exactly as it was completed.
    final designs = await adamsDesigns(tester);
    expect(
      {for (final d in designs) d.name},
      {'Front Entrance Door', 'Kitchen Window'},
    );
    expect({for (final d in designs) d.id}.length, 2);
    final first = designs.singleWhere((d) => d.id == 'acceptance');
    expect(first.toJson(), saved.toJson());
    expect(DesignCompletion.isCompleted(first), isTrue);

    // Back from the new design is Adam's page, never the customers list.
    Navigator.of(tester.element(find.byType(WorkspaceScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(CustomerScreen), findsOneWidget);
    expect(
      tester.widget<CustomerScreen>(find.byType(CustomerScreen)).customerId,
      adamId,
    );
  });

  testWidgets('an incomplete design is said to be so, and nothing is saved', (
    tester,
  ) async {
    // A door with its sizes not given.
    final d = door(id: 'unsized')
        .copyWith(name: 'Basement Door', measured: const {});
    await seedWith(tester, [d], factoryList());
    final before = (await kept(tester, 'unsized'))!.toJson();
    await toAdam(tester);
    await openFromCard(tester, 'unsized');
    await notNowToSizes(tester);
    await pressComplete(tester);
    expect(find.byKey(NotCompleteDialog.dialogKey), findsOneWidget);
    expect(
      find.text(
        'This design is not complete yet. Please finish the required parts '
        'before completing it.',
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(NotCompleteDialog.dialogKey),
        matching: find.textContaining('Please give the'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(CompletedDialog.dialogKey), findsNothing);
    expect((await kept(tester, 'unsized'))!.toJson(), before);
  });

  testWidgets('pressed twice, and New Design pressed twice: one completion, '
      'one new design', (tester) async {
    await seedWith(tester, [
      acceptance().copyWith(name: 'Front Entrance Door'),
    ], factoryList());
    await toAdam(tester);
    await openFromCard(tester, 'acceptance');
    await tester.tap(find.byKey(CompleteBar.buttonKey));
    await tester.tap(find.byKey(CompleteBar.buttonKey), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byKey(CompletedDialog.dialogKey), findsOneWidget);
    await tester.tap(find.byKey(CompletedDialog.newDesignKey));
    await tester.tap(
      find.byKey(CompletedDialog.newDesignKey),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.byType(DesignNameScreen), findsOneWidget);
    expect(await adamsDesigns(tester), hasLength(1));
  });

  testWidgets('View Completed Design stays on it; Back to Customer goes to '
      "the customer's page", (tester) async {
    await seedWith(tester, [
      acceptance().copyWith(name: 'Front Entrance Door'),
    ], factoryList());
    await toAdam(tester);
    await openFromCard(tester, 'acceptance');
    await pressComplete(tester);
    await tester.tap(find.byKey(CompletedDialog.viewKey));
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceScreen), findsOneWidget);
    expect(find.text('Completed and saved'), findsOneWidget);
    await pressComplete(tester);
    await tester.tap(find.byKey(CompletedDialog.backKey));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerScreen), findsOneWidget);
    // Its card says so.
    await tester.scrollUntilVisible(
      find.byKey(CustomerDesignCard.statusKey('acceptance')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<Text>(find.byKey(CustomerDesignCard.statusKey('acceptance')))
          .data,
      'Completed',
    );
  });

  test('a save that fails is no completion: the design goes back, and '
      'nothing is said to be done', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [designStoreProvider.overrideWithValue(_Failing())],
    );
    addTearDown(container.dispose);
    final controller = container.read(workspaceProvider.notifier);
    final d = acceptance().copyWith(name: 'Front Entrance Door');
    controller.openDesign(d);
    final outcome = await controller.complete();
    expect(outcome.result, CompletionResult.failed);
    expect(outcome.message, contains('could not be saved'));
    expect(outcome.design, isNull);
    expect(container.read(workspaceProvider).design.completedAs, isNull);
    expect(controller.completing, isFalse);
  });

  test('an edit after completing makes it a draft again; undoing the edit '
      'does not need completing again', () {
    final d = DesignCompletion.complete(acceptance());
    expect(DesignCompletion.isCompleted(d), isTrue);
    final renamed = d.copyWith(name: 'Another name');
    expect(
      DesignCompletion.isCompleted(renamed),
      isTrue,
      reason: 'a name is not the design',
    );
    final deeper = d.copyWith(depthMm: d.depthMm + 10);
    expect(DesignCompletion.isCompleted(deeper), isFalse);
    final back = deeper.copyWith(depthMm: d.depthMm);
    expect(DesignCompletion.isCompleted(back), isTrue);
    final unread = d.copyWith(sketchUnread: true);
    expect(DesignCompletion.isCompleted(unread), isFalse);
    // Kept and read back, it is still completed.
    final again = Design.fromJson(d.toJson());
    expect(DesignCompletion.isCompleted(again), isTrue);
  });
}

/// A store whose every save fails, as a full device's would.
class _Failing extends DesignStore {
  @override
  Future<Design> save(Design unowned, {required Authority by}) async =>
      throw StateError('The device has no room left.');
}
