import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/app.dart';
import 'package:proframe/app/screens/designs_screen.dart';
import 'package:proframe/app/screens/launch_screen.dart';
import 'package:proframe/app/screens/workspace_screen.dart';

import 'new_design.dart';

// The workshop's mark plays once as the app opens, and hands over to the
// home screen. Its name is the workshop's own, in Sorani Kurdish, set right
// to left in typefaces that have every letter of it; it comes in a word at
// a time and lifts away before the home screen comes up. The door in the
// mark turns on its hinge and the sliding panel only runs along its track.

/// Every piece of text the name is set in, top to bottom and, within the
/// master's name, in the order it is read.
List<String> get nameParts => [brandLines[0], ...brandMainWords, brandLines[2]];

/// How visible [finder] is: every fade it sits inside, multiplied together.
double visibility(WidgetTester tester, Finder finder) {
  var shown = 1.0;
  for (final fade in tester.widgetList<Opacity>(
    find.ancestor(of: finder, matching: find.byType(Opacity)),
  )) {
    shown *= fade.opacity;
  }
  return shown;
}

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

    test('is set on three lines, whole words, in their own order', () {
      expect(brandLines.join(' '), brandName);
      for (final line in brandLines) {
        expect(line.trim(), line, reason: 'no line starts or ends a word');
      }
    });

    test('the master\'s name is its middle line, word for word', () {
      expect(brandMainWords.join(' '), brandLines[1]);
      expect(brandMainWords, hasLength(LaunchTiming.mainWords.length));
    });

    test('its typefaces have every letter of it, in every weight used', () {
      for (final file in [
        'assets/fonts/ArefRuqaa-700.ttf',
        'assets/fonts/Vazirmatn-300.ttf',
        'assets/fonts/Vazirmatn-600.ttf',
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

    testWidgets('is set in them, right to left, as text', (tester) async {
      await openTheApp(tester, const Size(390, 844));
      await tester.pump(LaunchScreen.duration * 0.84);
      Text text(String part) => tester.widget<Text>(find.text(part));
      for (final part in nameParts) {
        expect(text(part).textDirection, TextDirection.rtl);
      }
      // The master's name is the signature, in the Ruqaa hand; the lines
      // either side of it are set plainly.
      for (final word in brandMainWords) {
        expect(text(word).style?.fontFamily, brandDisplayFamily);
      }
      for (final line in [brandLines[0], brandLines[2]]) {
        expect(text(line).style?.fontFamily, brandFontFamily);
      }
      // Read top to bottom, as the name is read, and the master's name
      // right to left.
      double top(String part) => tester.getRect(find.text(part)).top;
      expect(top(brandLines[0]), lessThan(top(brandMainWords.first)));
      expect(top(brandMainWords.first), lessThan(top(brandLines[2])));
      double right(String part) => tester.getRect(find.text(part)).right;
      expect(right(brandMainWords[0]), greaterThan(right(brandMainWords[1])));
      // The master's name is the largest of the three.
      double size(String part) => text(part).style!.fontSize!;
      expect(size(brandMainWords[0]), greaterThan(size(brandLines[0])));
      expect(size(brandMainWords[0]), greaterThan(size(brandLines[2])));
      await tester.pumpAndSettle();
    });
  });

  group('the name comes in, and goes', () {
    test('a word at a time in the order it is read, and then away', () {
      final words = LaunchTiming.mainWords;
      expect(words[0].begin, lessThan(words[1].begin), reason: 'right first');
      expect(LaunchTiming.firstLine.begin, lessThan(words[0].begin));
      expect(words.last.begin, lessThan(LaunchTiming.lastLine.begin));
      // Everything has arrived, and been lit, before anything leaves.
      final arrived = [
        LaunchTiming.firstLine.end,
        for (final w in words) w.end,
        LaunchTiming.lastLine.end,
      ].reduce(math.max);
      expect(arrived, lessThanOrEqualTo(LaunchTiming.shimmer.begin + 0.06));
      for (final leaving in [
        LaunchTiming.leaveMark,
        ...LaunchTiming.leaveLines,
      ]) {
        expect(leaving.begin, greaterThan(arrived));
        expect(leaving.end, lessThanOrEqualTo(1));
      }
      // Top line first.
      final lines = LaunchTiming.leaveLines;
      expect(lines[0].begin, lessThan(lines[1].begin));
      expect(lines[1].begin, lessThan(lines[2].begin));
    });

    testWidgets('each word appears in turn, and all of it disappears', (
      tester,
    ) async {
      await openTheApp(tester, const Size(390, 844));
      // Moves the clock on to [share] of the way through the launch.
      var now = 0.0;
      Future<void> to(double share) async {
        await tester.pump(LaunchScreen.duration * (share - now));
        now = share;
      }

      double shown(String part) => visibility(tester, find.text(part));

      await to(LaunchTiming.rules.begin - 0.02);
      for (final part in nameParts) {
        expect(shown(part), 0, reason: '$part is not there yet');
      }

      // Between the two words' arrivals: the first read is there before
      // the second.
      await to(
        (LaunchTiming.mainWords[0].begin + LaunchTiming.mainWords[1].begin) /
            2,
      );
      expect(shown(brandMainWords[0]), greaterThan(shown(brandMainWords[1])));

      await to(LaunchTiming.shimmer.end);
      for (final part in nameParts) {
        expect(shown(part), closeTo(1, 1e-6), reason: '$part is all there');
      }

      // Leaving: the top line goes first.
      await to(LaunchTiming.leaveLines[2].begin + 0.005);
      expect(shown(brandLines[0]), lessThan(shown(brandLines[2])));

      await tester.pump(
        LaunchScreen.duration * (1 - now) - const Duration(milliseconds: 1),
      );
      for (final part in nameParts) {
        expect(shown(part), lessThan(0.05), reason: '$part has gone');
      }
      await tester.pumpAndSettle();
      expect(find.byType(DesignsScreen), findsOneWidget);
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

    test('the window tilts about its bottom edge, and shuts again', () {
      const sash = Rect.fromLTRB(95, 27, 173, 85);
      for (final angle in [0.0, 0.1, LaunchMotion.windowWidest]) {
        final corners = LaunchMotion.windowSash(sash, angle, 260);
        expect(corners[2], sash.bottomRight);
        expect(corners[3], sash.bottomLeft);
      }
      final shut = LaunchMotion.windowSash(sash, 0, 260);
      expect(shut[0], sash.topLeft);
      expect(shut[1], sash.topRight);
      final tipped = LaunchMotion.windowSash(sash, 0.2, 260);
      expect(tipped[0].dy, greaterThan(sash.top), reason: 'the top drops');
      expect(tipped[1].dx - tipped[0].dx, lessThan(sash.width));
      expect(LaunchMotion.windowTilt(0), 0);
      expect(
        LaunchMotion.windowTilt(0.4),
        closeTo(LaunchMotion.windowWidest, 1e-9),
      );
      expect(LaunchMotion.windowTilt(1), 0, reason: 'it shuts again');
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
      expect(find.byType(DesignsScreen), findsNothing);

      await tester.pump(LaunchScreen.duration * 0.5);
      expect(find.byType(LaunchScreen), findsOneWidget);

      // Handing over: one screen or the other is always there.
      await tester.pump(LaunchScreen.duration * 0.5);
      for (var i = 0; i < 6; i++) {
        await tester.pump(LaunchScreen.handOver ~/ 5);
        expect(
          find.byType(LaunchScreen).evaluate().isNotEmpty ||
              find.byType(DesignsScreen).evaluate().isNotEmpty,
          isTrue,
        );
      }
      await tester.pumpAndSettle();
      expect(find.byType(DesignsScreen), findsOneWidget);
      expect(find.byType(LaunchScreen), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('going into a design and back does not play it again', (
      tester,
    ) async {
      await openTheApp(tester, const Size(1280, 820));
      await tester.pumpAndSettle();
      await toTheCategories(tester);
      await chooseDesign(tester, 'DOOR');
      expect(find.byType(WorkspaceScreen), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byType(DesignsScreen), findsOneWidget);
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
      for (final part in nameParts) {
        expect(find.text(part), findsOneWidget);
        expect(visibility(tester, find.text(part)), closeTo(1, 1e-6));
        // Nothing moves or blurs: the words are where they will rest.
        expect(
          find.ancestor(
            of: find.text(part),
            matching: find.byType(ImageFiltered),
          ),
          findsNothing,
        );
      }
      await tester.pump(LaunchScreen.reducedDuration);
      await tester.pump();
      expect(find.byType(DesignsScreen), findsOneWidget);
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
        await tester.pump(LaunchScreen.duration * 0.84);
        expect(tester.takeException(), isNull, reason: 'nothing overflows');

        final screen = Offset.zero & size;
        final name = nameParts
            .map((line) => tester.getRect(find.text(line)))
            .reduce((a, b) => a.expandToInclude(b));
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
