import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/inspector/alert_layer.dart';
import 'package:proframe/app/inspector/outline_gap_alert.dart';

import 'pause_and_take_it_back_test.dart' as sheet;
import 'the_design_is_not_closed_test.dart' as gap;

// The alerts come and go: the work behind blurs back over a moment, the card
// rises into place and its parts follow one another in; answered, it goes
// again, quicker than it came. Every movement finishes — nothing loops — and
// a device that has asked for less motion gets the alert already in place.

/// How visible [text] is: every fade above it, taken together.
double shownOf(WidgetTester tester, String text) => tester
    .widgetList<FadeTransition>(
      find.ancestor(of: find.text(text), matching: find.byType(FadeTransition)),
    )
    .fold(1.0, (seen, fade) => seen * fade.opacity.value);

/// How visible the alert's card is, by its title.
double cardOpacity(WidgetTester tester) => shownOf(tester, 'Design not closed');

void main() {
  testWidgets('it arrives over a moment, and then it is still', (tester) async {
    final c = await sheet.openTheApp(tester, 'DOOR');
    await gap.noFoot(c);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.byType(OutlineGapAlert), findsOneWidget);
    expect(cardOpacity(tester), lessThan(1), reason: 'still arriving');

    await tester.pump(AlertLayer.arriving);
    expect(cardOpacity(tester), 1);
    // Nothing loops: once arrived, the screen settles.
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('its parts come in one after another', (tester) async {
    final c = await sheet.openTheApp(tester, 'DOOR');
    await gap.noFoot(c);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    double shown(String text) => shownOf(tester, text);

    // The question before the choices, and the first choice before the last.
    expect(shown('Keep it open'), greaterThan(shown('I will change it')));
    await tester.pumpAndSettle();
    expect(shown('I will change it'), 1);
  });

  testWidgets('answered, it goes — and is not answerable on its way out', (
    tester,
  ) async {
    final c = await sheet.openTheApp(tester, 'DOOR');
    await gap.noFoot(c);
    await tester.pumpAndSettle();

    await tester.tap(find.text('I will change it'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // Still there, fading, and it takes no second answer.
    expect(find.text('Design not closed'), findsOneWidget);
    expect(cardOpacity(tester), lessThan(1));
    expect(
      find.ancestor(
        of: find.text('I will change it'),
        matching: find.byWidgetPredicate(
          (w) => w is IgnorePointer && w.ignoring,
        ),
      ),
      findsWidgets,
    );

    await tester.pump(AlertLayer.leaving);
    await tester.pump();
    expect(find.text('Design not closed'), findsNothing);
  });

  testWidgets('less motion asked for: already in place', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final c = await sheet.openTheApp(tester, 'DOOR');
    await gap.noFoot(c);
    await tester.pump();
    expect(cardOpacity(tester), 1);
  });
}
