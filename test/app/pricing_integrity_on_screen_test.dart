import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/inspector/price_panel.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/state/tools.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/pricing/price_list.dart';
import 'package:proframe/domain/pricing/pricing_engine.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:proframe/infrastructure/price_record_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/geometry_normalizer_test.dart' show pen;
import '../domain/pricing_engine_test.dart' show door;
import 'angled_geometry_feedback_on_screen_test.dart' show openFor;
import 'deleting_a_design_test.dart' show askToDelete, confirm;
import 'new_design.dart' show notNowToSizes;
import 'the_price_button_test.dart'
    show
        adams,
        barButton,
        cardButton,
        closeSheet,
        enabledAt,
        records,
        said,
        seed,
        textOf,
        toAdam;

// The price on the screen is never of something other than what is drawn:
// lines drawn and not read keep it from being calculated, here and on the
// card; a design deleted takes its price with it, and Undo brings both
// back; and a card says everything it offers in full.

const notReadMessage =
    'The drawing has changes that have not been read. Please Read the '
    'drawing before calculating the price.';

/// A line drawn across the door's foot, touching nothing — not read.
void drawALine(WorkspaceController controller) => controller.addStroke(
  pen('loose', const [Vec2(250, 1500), Vec2(650, 1750)]).samples,
  tool: Tool.line,
);

Future<void> readIt(WidgetTester tester) async {
  final read = find.text('Read my drawing').evaluate().isNotEmpty
      ? find.text('Read my drawing')
      : find.text('Read it');
  await tester.tap(read);
  await tester.pumpAndSettle();
  await notNowToSizes(tester);
}

/// The application's own typeface, so a label measures as it will on the
/// screen rather than in the test font, which draws every letter as a
/// square a whole em wide.
Future<void> loadTheAppsTypeface() async {
  final loader = FontLoader('Noto Sans');
  for (final file in ['NotoSans-Regular.ttf', 'NotoSans-Bold.ttf']) {
    final bytes = File('assets/fonts/$file').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

void main() {
  setUpAll(loadTheAppsTypeface);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('30. in the workspace: lines drawn after the price was '
      'calculated keep Calculate price disabled, saying to Read first, and '
      'the old figure is only the previous one; read, it is enabled again', (
    tester,
  ) async {
    final c = await openFor(tester, door());
    final controller = c.read(workspaceProvider.notifier);
    await tester.tap(barButton);
    await tester.pumpAndSettle();
    await closeSheet(tester);
    expect(enabledAt(tester, barButton), isTrue);
    final kept = await records(tester);
    expect(kept, hasLength(1));

    drawALine(controller);
    await tester.pumpAndSettle();
    expect(c.read(workspaceProvider).needsReading, isTrue);
    expect(c.read(workspaceProvider).design.sketchUnread, isTrue);
    expect(enabledAt(tester, barButton), isFalse);
    expect(
      textOf(tester, PricePanel.stateKey),
      'Price unavailable until drawing is read',
    );
    expect(find.byKey(PricePanel.totalKey, skipOffstage: false), findsNothing);
    await tester.tap(barButton);
    await tester.pumpAndSettle();
    expect(said(tester), notReadMessage);
    // Nothing was priced from the unread sheet.
    expect(await records(tester), kept);

    // A figure drawn is not structure: it does not unblock the price, and
    // drawn on a read sheet it would not block it.
    controller.addStroke(
      pen('figure', const [Vec2(0, 2100), Vec2(900, 2100)]).samples,
      tool: Tool.dimension,
    );
    await tester.pumpAndSettle();
    expect(c.read(workspaceProvider).needsReading, isTrue);

    // Undo the figure and the line: the sheet is as it was read, and the
    // price is the price again.
    controller
      ..undo()
      ..undo();
    await tester.pumpAndSettle();
    expect(c.read(workspaceProvider).needsReading, isFalse);
    expect(enabledAt(tester, barButton), isTrue);
    expect(find.byKey(PricePanel.totalKey, skipOffstage: false), findsOne);

    // Drawn again, and read: enabled, and asking to be calculated afresh,
    // because the reading found a new line.
    drawALine(controller);
    await tester.pumpAndSettle();
    expect(enabledAt(tester, barButton), isFalse);
    await readIt(tester);
    expect(c.read(workspaceProvider).needsReading, isFalse);
    final design = c.read(workspaceProvider).design;
    if (const PricingEngine().price(design, PriceList.starter).isPriced) {
      expect(enabledAt(tester, barButton), isTrue);
    }
    expect(
      textOf(tester, PricePanel.stateKey),
      isNot('Price unavailable until drawing is read'),
    );

    // A figure drawn on a read sheet keeps it read.
    controller.addStroke(
      pen('figure2', const [Vec2(0, 2150), Vec2(900, 2150)]).samples,
      tool: Tool.dimension,
    );
    await tester.pumpAndSettle();
    expect(c.read(workspaceProvider).needsReading, isFalse);
  });

  testWidgets('30. on the card: a design kept with lines not read says '
      'its price needs update, and its Price is disabled, saying why', (
    tester,
  ) async {
    final c = await openFor(tester, door());
    await tester.tap(barButton);
    await tester.pumpAndSettle();
    await closeSheet(tester);
    drawALine(c.read(workspaceProvider.notifier));
    await tester.pumpAndSettle();
    // Back to the customer's page: the design is kept as it is, unread.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerScreen), findsOneWidget);
    final id = door().id;
    final kept = await tester.runAsync(() => DesignStore().load(id));
    expect(kept!.sketchUnread, isTrue);

    final button = await cardButton(tester, id);
    expect(
      textOf(tester, CustomerDesignCard.priceValueKey(id)),
      'Price: needs update',
    );
    expect(enabledAt(tester, button), isFalse);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(said(tester), notReadMessage);
  });

  testWidgets('32. a design deleted takes its price with it; Undo puts '
      'both back; the other designs\' prices are untouched', (tester) async {
    await seed(tester, adams());
    await toAdam(tester);
    for (final id in ['front', 'kitchen']) {
      await tester.tap(await cardButton(tester, id));
      await tester.pumpAndSettle();
      await closeSheet(tester);
    }
    final before = await records(tester);
    expect(before.keys, {
      PriceRecordStore.keyOf('front'),
      PriceRecordStore.keyOf('kitchen'),
    });
    final frontPrice = textOf(
      tester,
      CustomerDesignCard.priceValueKey('front'),
    );

    await askToDelete(tester, 'front');
    await confirm(tester);
    expect(await records(tester), {
      PriceRecordStore.keyOf('kitchen'):
          before[PriceRecordStore.keyOf('kitchen')],
    });

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(await records(tester), before);
    await cardButton(tester, 'front');
    expect(
      textOf(tester, CustomerDesignCard.priceValueKey('front')),
      frontPrice,
    );
    expect(frontPrice, startsWith('Price: '));
    expect(frontPrice, isNot(contains('not calculated')));
  });

  for (final size in const [
    Size(1024, 768),
    Size(1280, 900),
    Size(1440, 900),
    Size(1920, 1080),
    Size(800, 1000),
  ]) {
    testWidgets('a card says Edit information in full, beside Open, at '
        '${size.width.toInt()} × ${size.height.toInt()}', (tester) async {
      await seed(tester, adams());
      await toAdam(tester);
      await tester.binding.setSurfaceSize(size);
      await tester.pumpAndSettle();
      for (final d in adams()) {
        final edit = find.byKey(CustomerDesignCard.editKey(d.id));
        await tester.scrollUntilVisible(
          edit.hitTestable(),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        final label = find.descendant(
          of: edit,
          matching: find.text('Edit information'),
        );
        expect(label, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(label);
        // ignore: avoid_print
        print(
          'DBG ${d.name} label=${paragraph.size} text=${paragraph.getMaxIntrinsicWidth(100)} edit=${tester.getRect(edit)} open=${tester.getRect(find.byKey(CustomerDesignCard.openKey(d.id)))}',
        );
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: 'Edit information cut short on ${d.name}',
        );
        final open = tester.getRect(
          find.byKey(CustomerDesignCard.openKey(d.id)),
        );
        final edits = tester.getRect(edit);
        expect(edits.right, lessThanOrEqualTo(open.left), reason: d.name);
        final card = tester.getRect(
          find
              .ancestor(of: edit, matching: find.byType(CustomerDesignCard))
              .first,
        );
        expect(card.contains(edits.topLeft), isTrue);
        expect(card.right, greaterThanOrEqualTo(open.right));
        // The price row stands apart from the buttons.
        final price = tester.getRect(
          find.byKey(CustomerDesignCard.priceKey(d.id)),
        );
        expect(price.bottom, lessThanOrEqualTo(edits.top + 1));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
