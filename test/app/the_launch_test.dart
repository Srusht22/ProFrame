import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/app.dart';
import 'package:proframe/app/screens/launch_screen.dart';
import 'package:proframe/app/screens/start_screen.dart';

// The workshop's mark plays once as the app opens, and hands over to the
// home screen. Its name is the workshop's own, in Sorani Kurdish, set right
// to left in a typeface that has every letter of it; the door in the mark
// turns on its hinge and the sliding panel only runs along its track.

Future<void> openTheApp(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const ProviderScope(child: ProFrameApp()));
}

/// The code points [font] has a glyph for, from its own cmap table.
Set<int> glyphsIn(Uint8List font) {
  final data = ByteData.sublistView(font);
  final tables = data.getUint16(4);
  var cmap = -1;
  for (var i = 0; i < tables; i++) {
    final entry = 12 + i * 16;
    final tag = String.fromCharCodes(font.sublist(entry, entry + 4));
    if (tag == 'cmap') cmap = data.getUint32(entry + 8);
  }
  expect(cmap, isNot(-1), reason: 'a font has a character map');

  final covered = <int>{};
  final subtables = data.getUint16(cmap + 2);
  for (var i = 0; i < subtables; i++) {
    final record = cmap + 4 + i * 8;
    final platform = data.getUint16(record);
    final offset = cmap + data.getUint32(record + 4);
    if (platform != 3 && platform != 0) continue;
    final format = data.getUint16(offset);
    if (format == 4) {
      final segments = data.getUint16(offset + 6) ~/ 2;
      final ends = offset + 14;
      final starts = ends + segments * 2 + 2;
      final deltas = starts + segments * 2;
      final ranges = deltas + segments * 2;
      for (var s = 0; s < segments; s++) {
        final end = data.getUint16(ends + s * 2);
        final start = data.getUint16(starts + s * 2);
        final delta = data.getInt16(deltas + s * 2);
        final range = data.getUint16(ranges + s * 2);
        for (var c = start; c <= end && c != 0xFFFF; c++) {
          int glyph;
          if (range == 0) {
            glyph = (c + delta) & 0xFFFF;
          } else {
            final at = ranges + s * 2 + range + (c - start) * 2;
            glyph = data.getUint16(at);
            if (glyph != 0) glyph = (glyph + delta) & 0xFFFF;
          }
          if (glyph != 0) covered.add(c);
        }
      }
    } else if (format == 12) {
      final groups = data.getUint32(offset + 12);
      for (var g = 0; g < groups; g++) {
        final group = offset + 16 + g * 12;
        final start = data.getUint32(group);
        final end = data.getUint32(group + 4);
        for (var c = start; c <= end; c++) {
          covered.add(c);
        }
      }
    }
  }
  return covered;
}

void main() {
  group('the name', () {
    test('is the workshop\'s own, exactly', () {
      expect(brandName, 'کارگەی وەستا سۆران شارباژێڕی');
    });

    test('its typeface has every letter of it, in both weights', () {
      for (final file in [
        'assets/fonts/NotoSansArabic-Regular.ttf',
        'assets/fonts/NotoSansArabic-Bold.ttf',
      ]) {
        final glyphs = glyphsIn(File(file).readAsBytesSync());
        for (final c in brandName.runes) {
          if (c == 0x20) continue;
          expect(
            glyphs.contains(c),
            isTrue,
            reason: '$file has U+${c.toRadixString(16).toUpperCase()}',
          );
        }
      }
    });

    testWidgets('is set in it, right to left, as text', (tester) async {
      await openTheApp(tester, const Size(390, 844));
      await tester.pump(LaunchScreen.duration);
      final name = tester.widget<Text>(find.text(brandName));
      expect(name.textDirection, TextDirection.rtl);
      expect(name.style?.fontFamily, brandFontFamily);
      await tester.pumpAndSettle();
    });
  });

  group('the motion is the real thing', () {
    test('the door turns about its hinge, which never moves', () {
      for (final angle in [0.0, 0.2, LaunchMotion.doorWidest]) {
        final leaf = LaunchMotion.doorLeaf(
          hingeX: 30,
          top: 20,
          bottom: 170,
          width: 50,
          angle: angle,
          viewer: 260,
        );
        expect(leaf[0], const Offset(30, 20));
        expect(leaf[3], const Offset(30, 170));
      }
      double freeEdge(double angle) => LaunchMotion.doorLeaf(
        hingeX: 30,
        top: 20,
        bottom: 170,
        width: 50,
        angle: angle,
        viewer: 260,
      )[1].dx;
      expect(freeEdge(0), 80, reason: 'shut, the leaf fills its bay');
      expect(freeEdge(0.4), lessThan(freeEdge(0.2)));
    });

    test('it opens, and comes to rest partly open', () {
      expect(LaunchMotion.doorAngle(0), 0);
      expect(
        LaunchMotion.doorAngle(0.45),
        closeTo(LaunchMotion.doorWidest, 1e-9),
      );
      expect(
        LaunchMotion.doorAngle(1),
        closeTo(LaunchMotion.doorResting, 1e-9),
      );
      expect(LaunchMotion.doorResting, greaterThan(0));
    });

    test('the sliding panel runs along its track and settles', () {
      var last = -1.0;
      for (var t = 0.0; t <= 1.0; t += 0.05) {
        final along = LaunchMotion.slide(t);
        expect(along, greaterThanOrEqualTo(last), reason: 'one way, no bounce');
        last = along;
      }
      expect(LaunchMotion.slide(0), 0);
      expect(LaunchMotion.slide(1), LaunchMotion.slideResting);
    });
  });

  group('it plays once, and goes on to the home screen', () {
    testWidgets('the mark, then the home screen, with nothing blank between', (
      tester,
    ) async {
      await openTheApp(tester, const Size(390, 844));
      expect(find.byType(LaunchScreen), findsOneWidget);
      expect(find.byType(StartScreen), findsNothing);

      await tester.pump(LaunchScreen.duration * 0.5);
      expect(find.byType(LaunchScreen), findsOneWidget);

      // Handing over: one screen or the other is always there.
      await tester.pump(LaunchScreen.duration * 0.5);
      for (var i = 0; i < 6; i++) {
        await tester.pump(LaunchScreen.handOver ~/ 5);
        expect(
          find.byType(LaunchScreen).evaluate().isNotEmpty ||
              find.byType(StartScreen).evaluate().isNotEmpty,
          isTrue,
        );
      }
      await tester.pumpAndSettle();
      expect(find.byType(StartScreen), findsOneWidget);
      expect(find.byType(LaunchScreen), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('going into a design and back does not play it again', (
      tester,
    ) async {
      await openTheApp(tester, const Size(1280, 820));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DOOR'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byType(StartScreen), findsOneWidget);
      expect(find.byType(LaunchScreen), findsNothing);
    });

    testWidgets('less motion asked for: a gentle fade, and on', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await openTheApp(tester, const Size(390, 844));
      await tester.pump(LaunchScreen.reducedDuration ~/ 2);
      expect(find.text(brandName), findsOneWidget);
      await tester.pump(LaunchScreen.reducedDuration);
      await tester.pump();
      expect(find.byType(StartScreen), findsOneWidget);
    });
  });

  group('it fits every phone', () {
    for (final size in const [
      Size(320, 568),
      Size(360, 640),
      Size(390, 844),
      Size(430, 932),
      Size(844, 390),
      Size(1280, 800),
    ]) {
      testWidgets('at ${size.width.toInt()} × ${size.height.toInt()}', (
        tester,
      ) async {
        await openTheApp(tester, size);
        await tester.pump(LaunchScreen.duration * 0.9);
        expect(tester.takeException(), isNull, reason: 'nothing overflows');

        final screen = Offset.zero & size;
        final name = tester.getRect(find.text(brandName));
        final mark = tester.getRect(
          find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is LaunchEmblemPainter,
          ),
        );
        for (final part in [name, mark]) {
          expect(screen.contains(part.topLeft), isTrue);
          expect(screen.contains(part.bottomRight), isTrue);
        }
        // Centred, the name under the mark.
        expect(mark.center.dx, closeTo(size.width / 2, 1));
        expect(name.center.dx, closeTo(size.width / 2, 1));
        expect(name.top, greaterThan(mark.bottom));
        await tester.pumpAndSettle();
      });
    }
  });
}
