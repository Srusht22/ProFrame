import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/inspector/measure_form.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/dimensions/measurements.dart';
import 'package:proframe/domain/dimensions/units.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/sketch/stroke.dart';

import '../domain/geometry_normalizer_test.dart' show pen;
import 'pause_and_take_it_back_test.dart' show chevron;
import 'the_sizes_are_asked_test.dart' as sizes;

// The user's words, over the sizes form saying *That does not fit the
// parts inside it* under the overall width: *don't show me the error, just
// suggest us what the thing is.* A size that cannot be made is now said as
// a suggestion — what it would do to the design, the drawing's own warning
// where it has one, and the nearest size that fits as a button that puts
// it in the field. Nothing is put into the design until Apply.

void main() {
  for (final size in const [Size(390, 844), Size(1280, 820)]) {
    testWidgets('at ${size.width.round()} wide: a width that cannot be made '
        'is suggested, never an error, and the suggestion is taken', (
      tester,
    ) async {
      final c = await sizes.openTheApp(
        tester,
        'ANGLED / ASYMMETRICAL',
        size: size,
      );
      final controller = c.read(workspaceProvider.notifier);
      // A triangle with a mullion near its low end and an opening beside
      // it: made very wide, the slope runs down onto the sill there.
      controller.state = controller.state.copyWith(
        design: controller.state.design.copyWith(
          sketch: Sketch(
            strokes: [
              pen('outline', const [
                Vec2(0, 1000),
                Vec2(0, 900),
                Vec2(1400, 0),
                Vec2(1400, 1000),
                Vec2(0, 1000),
              ]),
              pen('m', const [Vec2(420, 0), Vec2(420, 1000)]),
              pen('mark', chevron(const Vec2(560, 850))),
            ],
          ),
        ),
      );
      controller.readDrawing();
      // An angled design asks what the leaf is first; it is a window.
      controller.setOpeningKind(
        c.read(workspaceProvider).design.openings.single.id,
        DesignKind.window,
      );
      await tester.pumpAndSettle();
      expect(find.byType(MeasureForm), findsOneWidget);
      final before = c.read(workspaceProvider).design;
      expect(before.openings, hasLength(1));

      await tester.enterText(sizes.field(Measurements.widthKey), '400');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Apply'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      // Still open, with a suggestion under the width and no error on it.
      expect(find.byType(MeasureForm), findsOneWidget);
      expect(find.byType(SizeSuggestion), findsOneWidget);
      expect(find.byIcon(Icons.lightbulb_outline), findsOneWidget);
      expect(
        find.textContaining('there would be no room left for Opening 1'),
        findsOneWidget,
      );
      expect(find.textContaining('The nearest size that fits is'), findsOne);
      final widthField = tester.widget<TextField>(
        sizes.field(Measurements.widthKey),
      );
      expect(widthField.decoration!.errorText, isNull);
      expect(find.textContaining('does not fit'), findsNothing);
      expect(c.read(workspaceProvider).design.widthMm, before.widthMm);

      // Use puts the nearest that fits in the field, and nothing more.
      final use = find.byKey(SizeSuggestion.useKey);
      await tester.ensureVisible(use);
      await tester.pumpAndSettle();
      await tester.tap(use);
      await tester.pumpAndSettle();
      expect(find.byType(SizeSuggestion), findsNothing);
      final typed = Units.parse(widthField.controller!.text)!;
      expect(typed, greaterThan(before.widthMm));
      expect(typed, lessThan(4000));
      expect(c.read(workspaceProvider).design.widthMm, before.widthMm);

      await tester.ensureVisible(find.text('Apply'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      final after = c.read(workspaceProvider).design;
      expect(after.widthMm, closeTo(typed, 0.5));
      expect(after.openings, hasLength(1));
      expect(sizes.overflowing(tester), isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
