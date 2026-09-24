import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/screens/tool_rail.dart';
import 'package:proframe/app/screens/workspace_bars.dart';
import 'package:proframe/app/state/tools.dart';
import 'package:proframe/app/state/workspace.dart';

import 'pause_and_take_it_back_test.dart' as sheet;

// The tools down the left and the views across the top each have one
// highlight, and it glides to what is chosen rather than jumping — so the
// eye follows the change. Every movement finishes, and a device asking for
// less motion gets the highlight straight where it belongs.

/// Where the highlight inside [of] is on the screen.
Offset highlightIn(WidgetTester tester, Type of) => tester.getTopLeft(
  find
      .descendant(
        of: find.byType(of),
        matching: find.byType(AnimatedPositioned),
      )
      .first,
);

void main() {
  testWidgets('the tool highlight glides to the tool chosen', (tester) async {
    await sheet.openTheApp(tester, 'WINDOW');
    final from = highlightIn(tester, ToolRail);

    await tester.tap(find.text('Rectangle'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final between = highlightIn(tester, ToolRail);

    await tester.pumpAndSettle();
    final to = highlightIn(tester, ToolRail);

    expect(to.dy, greaterThan(from.dy), reason: 'Rectangle is further down');
    expect(between.dy, greaterThan(from.dy));
    expect(between.dy, isNot(closeTo(to.dy, 1)), reason: 'still on its way');
    // Where it came to rest is the tool's own place.
    final tool = tester.getCenter(find.text('Rectangle'));
    final pill = tester.getRect(
      find
          .descendant(
            of: find.byType(ToolRail),
            matching: find.byType(AnimatedPositioned),
          )
          .first,
    );
    expect(pill.contains(tool), isTrue);
  });

  testWidgets('the view highlight glides to the view chosen', (tester) async {
    final c = await sheet.openTheApp(tester, 'WINDOW');
    await sheet.twoLeaves(c);
    await tester.pumpAndSettle();
    // Answer the kind questions so nothing covers the bar.
    for (final opening in c.read(workspaceProvider).design.openings) {
      c.read(workspaceProvider.notifier).dismissQuestion(
        WorkspaceState.openingKindQuestion(opening.id),
      );
    }
    await tester.pumpAndSettle();

    c.read(workspaceProvider.notifier).showView(WorkspaceView.draw);
    await tester.pumpAndSettle();
    final from = highlightIn(tester, ViewTabs);

    await tester.tap(find.text('3D model'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final between = highlightIn(tester, ViewTabs);
    await tester.pumpAndSettle();
    final to = highlightIn(tester, ViewTabs);

    expect(to.dx, greaterThan(from.dx));
    expect(between.dx, greaterThan(from.dx));
    expect(between.dx, isNot(closeTo(to.dx, 1)));
    expect(c.read(workspaceProvider).view, WorkspaceView.model);
  });

  testWidgets('less motion asked for: straight there', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await sheet.openTheApp(tester, 'WINDOW');
    await tester.tap(find.text('Rectangle'));
    await tester.pump();
    await tester.pump();
    final pill = tester.getRect(
      find
          .descendant(
            of: find.byType(ToolRail),
            matching: find.byType(AnimatedPositioned),
          )
          .first,
    );
    expect(pill.contains(tester.getCenter(find.text('Rectangle'))), isTrue);
  });
}
