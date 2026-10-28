import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/inspector/edit_menu.dart';
import 'package:proframe/app/inspector/inspector_panel.dart';
import 'package:proframe/app/inspector/material_form.dart';
import 'package:proframe/app/l10n/app_localizations.dart';
import 'package:proframe/app/screens/workspace_screen.dart';
import 'package:proframe/app/state/language.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/model/infill.dart';

import 'it_fits_a_phone_and_a_tablet_test.dart';

// The user's phone screenshot, in Kurdish, with the paint roller on the bar
// at the top and the sliders on the bar of views ringed: *they are crowded,
// normal people cannot understand what is going on, so those two icons
// should open in one icon.* Where the panel is not beside the drawing they
// are one **Edit**, whose sheet says what is picked and what each choice
// does; each choice opens exactly what its icon did, and nothing in the
// design changes by looking.

final english = lookupAppLocalizations(const Locale('en'));
final kurdish = lookupAppLocalizations(const Locale('ckb'));

void main() {
  for (final size in [
    ...phones,
    ...tablets,
  ].where((s) => WorkspaceLayout.of(s.width) != WorkspaceLayout.desktop)) {
    final tag = '${size.width.round()} × ${size.height.round()}';

    testWidgets('one Edit, and neither old icon, at $tag', (tester) async {
      final (container, _) = await twoLeavesAt(tester, size);
      expect(find.byKey(EditMenu.buttonKey), findsOneWidget);
      expect(find.byTooltip('Material'), findsNothing);
      expect(find.byTooltip('Details'), findsNothing);
      expect(find.byIcon(Icons.format_paint_outlined), findsNothing);
      expect(find.byIcon(Icons.tune), findsNothing);
      final edit = tester.getRect(find.byKey(EditMenu.buttonKey));
      expect(edit.left, greaterThanOrEqualTo(0));
      expect(edit.right, lessThanOrEqualTo(size.width));

      final before = jsonEncode(container.read(workspaceProvider).design);
      await tester.tap(find.byKey(EditMenu.buttonKey));
      await tester.pumpAndSettle();
      expect(find.byType(EditMenu), findsOneWidget);
      expect(find.text(english.wsEditWhole), findsOneWidget);
      expect(find.text(english.wsGlassOrPanel), findsOneWidget);
      expect(find.text(english.wsGlassOrPanelHint), findsOneWidget);
      expect(find.text(english.wsDetails), findsOneWidget);
      expect(find.text(english.wsDetailsHint), findsOneWidget);
      expect(overflowing(tester, 'the sheet'), isEmpty);
      expect(tester.takeException(), isNull);

      // Put away, it changed nothing.
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byType(EditMenu), findsNothing);
      expect(jsonEncode(container.read(workspaceProvider).design), before);
    });
  }

  testWidgets('Glass or panel opens the Material tool on the part picked', (
    tester,
  ) async {
    final (container, controller) = await twoLeavesAt(
      tester,
      const Size(390, 844),
    );
    final part = Infill.partsOf(container.read(workspaceProvider).design).last;
    controller.select(part.id);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(EditMenu.buttonKey));
    await tester.pumpAndSettle();
    // The sheet names what is picked.
    expect(find.textContaining(english.wsEditPicked('')), findsOneWidget);
    await tester.tap(find.byKey(EditMenu.materialKey));
    await tester.pumpAndSettle();
    expect(find.byType(EditMenu), findsNothing);
    final form = tester.widget<MaterialForm>(find.byType(MaterialForm));
    expect(form.focusId, part.id);
  });

  testWidgets('Details opens the panel in the drawer', (tester) async {
    await twoLeavesAt(tester, const Size(390, 844));
    expect(find.byType(InspectorPanel), findsNothing);
    await tester.tap(find.byKey(EditMenu.buttonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(EditMenu.detailsKey));
    await tester.pumpAndSettle();
    expect(find.byType(EditMenu), findsNothing);
    expect(find.byType(InspectorPanel), findsOneWidget);
  });

  testWidgets('on a laptop the panel is beside the drawing, and Material is '
      'its own icon', (tester) async {
    await twoLeavesAt(tester, const Size(1280, 820));
    expect(find.byKey(EditMenu.buttonKey), findsNothing);
    expect(find.byType(InspectorPanel), findsOneWidget);
    await tester.tap(find.byTooltip('Material'));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialForm), findsOneWidget);
  });

  testWidgets('in Kurdish: the words, right to left, and the sizes dot over '
      'the ruler, not the next icon', (tester) async {
    final (container, _) = await twoLeavesAt(tester, const Size(390, 844));

    // Sizes are still to give, so the dot is up. How far in from the
    // ruler's end edge it sits — the right in English, the left in
    // Kurdish — is the same in both: in Kurdish it used to sit out beside
    // the ruler, over the next icon, and read as that icon's.
    double inward(TextDirection direction) {
      final badge = find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(Badge),
      );
      expect(badge, findsOneWidget);
      final ruler = tester.getRect(
        find.descendant(of: badge, matching: find.byIcon(Icons.straighten)),
      );
      final dots = tester
          .renderObjectList<RenderBox>(
            find.descendant(of: badge, matching: find.byType(Container)),
          )
          .where((r) => r.size.width <= 10 && r.size.height <= 10)
          .toList();
      expect(dots, hasLength(1));
      final dot = dots.single.localToGlobal(
        dots.single.size.center(Offset.zero),
      );
      final edit = tester.getRect(find.byKey(EditMenu.buttonKey));
      expect(edit.contains(dot), isFalse, reason: 'not on the Edit icon');
      return direction == TextDirection.ltr
          ? ruler.right - dot.dx
          : dot.dx - ruler.left;
    }

    final inEnglish = inward(TextDirection.ltr);
    await container
        .read(languageProvider.notifier)
        .choose(AppLanguage.centralKurdish);
    await tester.pumpAndSettle();
    expect(inward(TextDirection.rtl), closeTo(inEnglish, 0.5));

    await tester.tap(find.byKey(EditMenu.buttonKey));
    await tester.pumpAndSettle();
    expect(find.text(kurdish.wsEdit), findsWidgets);
    expect(find.text(kurdish.wsEditWhole), findsOneWidget);
    expect(find.text(kurdish.wsGlassOrPanel), findsOneWidget);
    expect(find.text(kurdish.wsDetailsHint), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(EditMenu))),
      TextDirection.rtl,
    );
    // The choices point on the way the screen reads.
    expect(find.byIcon(Icons.chevron_left), findsNWidgets(2));
    // The choice's mark is at the start of the line, on the right.
    final mark = tester.getRect(
      find.descendant(
        of: find.byKey(EditMenu.materialKey),
        matching: find.byIcon(Icons.format_paint_outlined),
      ),
    );
    final title = tester.getRect(find.text(kurdish.wsGlassOrPanel));
    expect(mark.left, greaterThan(title.left));
    expect(overflowing(tester, 'the sheet in Kurdish'), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
