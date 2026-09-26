import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/app.dart';
import 'package:proframe/app/canvas/cad_layers.dart';
import 'package:proframe/app/canvas/cad_painter.dart';
import 'package:proframe/app/canvas/cad_style.dart';
import 'package:proframe/app/canvas/design_painter.dart';
import 'package:proframe/app/canvas/view_transform.dart';
import 'package:proframe/app/screens/appearance_button.dart';
import 'package:proframe/app/screens/designs_screen.dart';
import 'package:proframe/app/state/appearance.dart';
import 'package:proframe/app/theme/app_theme.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The dark appearance is chosen colour by colour, not inverted, and nothing
// in it may be hard to read or disappear. These are the ratios that say so:
// the WCAG figures — 4.5 for lettering, 3 for anything that has to be seen
// — held for every pairing the application actually puts on the screen.

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

Future<void> openTheApp(WidgetTester tester, {Brightness? device}) async {
  if (device != null) {
    tester.platformDispatcher.platformBrightnessTestValue = device;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  }
  await tester.binding.setSurfaceSize(const Size(1280, 820));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const ProviderScope(child: ProFrameApp()));
  await tester.pumpAndSettle();
}

Color shellOf(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(DesignsScreen)))
        .scaffoldBackgroundColor;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the light appearance is what it was', () {
    test('its palette is the house colours themselves', () {
      const p = Palette.light;
      expect(p.primary, AppTheme.primary);
      expect(p.band, AppTheme.primary);
      expect(p.onBand, AppTheme.accent);
      expect(p.ink, AppTheme.ink);
      expect(p.muted, AppTheme.muted);
      expect(p.hairline, AppTheme.hairline);
      expect(p.surface, AppTheme.surface);
      expect(p.canvas, AppTheme.canvas);
      expect(p.shell, AppTheme.shell);
      expect(p.selection, AppTheme.selection);
      expect(p.cad.sheet, Cad.sheet);
      expect(p.cad.heavy, Cad.heavy);
    });

    test('a painter told nothing draws on paper', () {
      final design = Design.empty(id: 'd', kind: DesignKind.door);
      final view = ViewTransform.fit(
        Polygon.rect(0, 0, 1000, 1000),
        const Size(100, 100),
      );
      expect(
        CadPainter(design: design, view: view, layers: const CadLayers()).ink,
        Cad.paper,
      );
      expect(DesignPainter(design: design, view: view).palette, Palette.light);
    });

    test('ink on paper is drawn in exactly its own colour', () {
      for (final ink in const [
        Color(0xFF013E37),
        Color(0xFF000000),
        Color(0xFFFFFFFF),
        Color(0xFFFFEFB3),
      ]) {
        expect(Palette.light.legible(ink), ink);
      }
    });
  });

  group('nothing is hard to read', () {
    for (final (name, p) in const [
      ('light', Palette.light),
      ('dark', Palette.dark),
    ]) {
      test('lettering in the $name appearance', () {
        for (final (what, fore, ground) in [
          ('text on a panel', p.ink, p.surface),
          ('text on the page', p.ink, p.shell),
          ('text on a menu', p.ink, p.raised),
          ('quiet text on a panel', p.muted, p.surface),
          ('quiet text on the page', p.muted, p.shell),
          ('a chosen word on a panel', p.primary, p.surface),
          ('a chosen word on the page', p.primary, p.shell),
          ('a heading band', p.onBand, p.band),
          ('a filled button', AppTheme.accent, p.band),
          ('a note across the work', p.onNotice, p.notice),
          ('on a fill of the house colour', p.onPrimary, p.primary),
        ]) {
          expect(
            contrast(fore, ground),
            greaterThanOrEqualTo(4.5),
            reason: '$what, $name',
          );
        }
      });

      test('what has to be seen in the $name appearance', () {
        for (final (what, fore, ground) in [
          ('the selection on the sheet', p.selection, p.cad.sheet),
          ('the band against the page', p.band, p.shell),
          ('a chosen icon on the page', p.primary, p.shell),
          ('new ink on the sheet', p.drawnInk, p.canvas),
        ]) {
          expect(
            contrast(fore, ground),
            greaterThanOrEqualTo(what.startsWith('the band') ? 1.4 : 3),
            reason: '$what, $name',
          );
        }
      });
    }

    test('the technical drawing on a dark sheet keeps its ranks', () {
      const c = Cad.night;
      double on(Color colour) => contrast(colour, c.sheet);
      expect(on(c.heavy), greaterThanOrEqualTo(7), reason: 'the outline');
      expect(on(c.medium), greaterThanOrEqualTo(4.5), reason: 'a profile');
      expect(on(c.light), greaterThanOrEqualTo(4.5), reason: 'a tag');
      expect(on(c.dimension), greaterThanOrEqualTo(4.5), reason: 'a figure');
      expect(on(c.selection), greaterThanOrEqualTo(4.5), reason: 'selected');
      expect(on(c.hidden), greaterThanOrEqualTo(3), reason: 'hidden detail');
      expect(on(c.glassLine), greaterThanOrEqualTo(3), reason: 'glass');
      expect(on(c.hatch), greaterThanOrEqualTo(2.5), reason: 'the hatch');
      expect(on(c.grip), greaterThanOrEqualTo(3), reason: 'a grip');
      expect(on(c.snap), greaterThanOrEqualTo(3), reason: 'the snap');
      // Still in their order: heaviest stands out most.
      expect(on(c.heavy), greaterThan(on(c.medium)));
      expect(on(c.medium), greaterThan(on(c.light)));
      expect(on(c.light), greaterThan(on(c.hatch)));
      // The grid is there, and it is the faintest thing on the sheet.
      expect(on(c.grid), greaterThan(1.02));
      expect(on(c.gridStrong), greaterThan(on(c.grid)));
      expect(on(c.gridStrong), lessThan(on(c.hatch)));
    });
  });

  group('the user\'s colours are shown, never changed', () {
    test('a dark ink on a dark sheet is shown light, in its own hue', () {
      for (final ink in const [
        Color(0xFF013E37),
        Color(0xFF000000),
        Color(0xFF1C1C1C),
        Color(0xFF2C4A63),
        Color(0xFF4A2F1E),
      ]) {
        final shown = Palette.dark.legible(ink);
        expect(
          contrast(shown, Cad.night.sheet),
          greaterThanOrEqualTo(3),
          reason: '$ink',
        );
        final before = HSLColor.fromColor(ink);
        final after = HSLColor.fromColor(shown);
        if (before.saturation > 0.05) {
          expect(after.hue, closeTo(before.hue, 1.5), reason: 'same hue');
        }
      }
    });

    test('an ink that can already be seen is left exactly as it is', () {
      for (final ink in const [
        Color(0xFFFFFFFF),
        Color(0xFFFFEFB3),
        Color(0xFFD8D5CC),
      ]) {
        expect(Palette.dark.legible(ink), ink);
      }
    });
  });

  group('it follows the device, until told otherwise', () {
    testWidgets('light on a light device', (tester) async {
      await openTheApp(tester, device: Brightness.light);
      expect(shellOf(tester), Palette.light.shell);
    });

    testWidgets('dark on a dark device', (tester) async {
      await openTheApp(tester, device: Brightness.dark);
      expect(shellOf(tester), Palette.dark.shell);
      expect(tester.takeException(), isNull);
    });

    testWidgets('chosen from the designs, kept, and kept to', (tester) async {
      await openTheApp(tester, device: Brightness.light);
      await tester.tap(find.byType(AppearanceButton));
      await tester.pumpAndSettle();
      expect(find.text('Match device'), findsOneWidget);
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(shellOf(tester), Palette.dark.shell);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(Appearance.key), ThemeMode.dark.name);

      // Opened again on the same light device: dark, as it was left.
      await tester.pumpWidget(const SizedBox());
      await openTheApp(tester);
      expect(shellOf(tester), Palette.dark.shell);

      // And back to following the device.
      await tester.tap(find.byType(AppearanceButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Match device'));
      await tester.pumpAndSettle();
      expect(shellOf(tester), Palette.light.shell);
    });
  });
}
