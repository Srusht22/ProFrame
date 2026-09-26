import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/screens/tool_bar.dart';
import 'package:proframe/app/screens/workspace_bars.dart';
import 'package:proframe/app/state/tools.dart';
import 'package:proframe/app/state/workspace.dart';

import 'new_design.dart';
import 'pause_and_take_it_back_test.dart' as sheet;

// The tools along the bottom and the views across the top are two
// navigation bars, and each has one active indicator that glides to what is
// chosen rather than jumping — so the eye follows the change. Every movement
// finishes, and a device asking for less motion gets the indicator straight
// where it belongs.

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
    final from = highlightIn(tester, ToolBar);

    await tester.tap(find.text('Rectangle'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final between = highlightIn(tester, ToolBar);

    await tester.pumpAndSettle();
    final to = highlightIn(tester, ToolBar);

    expect(to.dx, greaterThan(from.dx), reason: 'Rectangle is further on');
    expect(between.dx, greaterThan(from.dx));
    expect(between.dx, isNot(closeTo(to.dx, 1)), reason: 'still on its way');
    // Where it came to rest is behind the tool's own icon.
    final tool = tester.getCenter(
      find.descendant(
        of: find.byType(ToolBar),
        matching: find.byIcon(ToolBar.iconOf(Tool.rectangle)),
      ),
    );
    final pill = tester.getRect(
      find
          .descendant(
            of: find.byType(ToolBar),
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
    await notNowToSizes(tester);
    // Answer the kind questions so nothing covers the bar.
    for (final opening in c.read(workspaceProvider).design.openings) {
      c
          .read(workspaceProvider.notifier)
          .dismissQuestion(WorkspaceState.openingKindQuestion(opening.id));
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
            of: find.byType(ToolBar),
            matching: find.byType(AnimatedPositioned),
          )
          .first,
    );
    final icon = find.descendant(
      of: find.byType(ToolBar),
      matching: find.byIcon(ToolBar.iconOf(Tool.rectangle)),
    );
    expect(pill.contains(tester.getCenter(icon)), isTrue);
  });

  testWidgets('the tool indicator is one pill and one bar, over one tool', (
    tester,
  ) async {
    await sheet.openTheApp(tester, 'WINDOW');
    await showEverything(tester);
    await tester.tap(find.text('Polyline'));
    await tester.pumpAndSettle();
    final marks = find.descendant(
      of: find.byType(ToolBar),
      matching: find.byType(AnimatedPositioned),
    );
    expect(marks, findsNWidgets(2));
    final icon = tester.getCenter(
      find.descendant(
        of: find.byType(ToolBar),
        matching: find.byIcon(ToolBar.iconOf(Tool.polyline)),
      ),
    );
    final pill = tester.getRect(marks.at(0));
    final bar = tester.getRect(marks.at(1));
    expect(pill.center.dx, closeTo(icon.dx, 1));
    expect(bar.center.dx, closeTo(icon.dx, 1));
    // The bar is on the top edge of the navigation bar.
    expect(bar.top, closeTo(tester.getRect(find.byType(ToolBar)).top, 2));
  });

  testWidgets('off the drawing, the indicator stands on Select', (
    tester,
  ) async {
    final c = await sheet.openTheApp(tester, 'WINDOW');
    await sheet.twoLeaves(c);
    for (final opening in c.read(workspaceProvider).design.openings) {
      c
          .read(workspaceProvider.notifier)
          .dismissQuestion(WorkspaceState.openingKindQuestion(opening.id));
    }
    await tester.tap(find.text('Rectangle'));
    await tester.pumpAndSettle();
    c.read(workspaceProvider.notifier).showView(WorkspaceView.plan);
    await tester.pumpAndSettle();
    final pill = tester.getRect(
      find
          .descendant(
            of: find.byType(ToolBar),
            matching: find.byType(AnimatedPositioned),
          )
          .first,
    );
    final select = find.descendant(
      of: find.byType(ToolBar),
      matching: find.byIcon(ToolBar.iconOf(Tool.select)),
    );
    expect(pill.contains(tester.getCenter(select)), isTrue);
  });

  testWidgets('the view indicator runs along the foot of the view chosen', (
    tester,
  ) async {
    final c = await sheet.openTheApp(tester, 'WINDOW');
    await sheet.twoLeaves(c);
    for (final opening in c.read(workspaceProvider).design.openings) {
      c
          .read(workspaceProvider.notifier)
          .dismissQuestion(WorkspaceState.openingKindQuestion(opening.id));
    }
    await tester.pumpAndSettle();
    for (final view in WorkspaceView.values) {
      c.read(workspaceProvider.notifier).showView(view);
      await tester.pumpAndSettle();
      final marks = find.descendant(
        of: find.byType(ViewTabs),
        matching: find.byType(AnimatedPositioned),
      );
      final label = tester.getRect(
        find.descendant(
          of: find.byType(ViewTabs),
          matching: find.text(view.label),
        ),
      );
      final pill = tester.getRect(marks.at(0));
      final bar = tester.getRect(marks.at(1));
      expect(pill.contains(label.center), isTrue, reason: view.label);
      expect(bar.left, greaterThanOrEqualTo(pill.left), reason: view.label);
      expect(bar.right, lessThanOrEqualTo(pill.right), reason: view.label);
      expect(bar.top, greaterThan(label.bottom), reason: 'along its foot');
    }
  });
}
