import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/app.dart';
import 'package:proframe/app/canvas/cad_view.dart';
import 'package:proframe/app/state/tools.dart';
import 'package:proframe/app/state/workspace.dart';

import '../final_visual_and_3d_test.dart' as fin;
import 'new_design.dart';

// The strip of tools that appears when any part of an opening is picked.
//
// It is a row of ten tools and a caption, and it used to be a `Row` with no
// answer to running out of room: on any ordinary screen it overflowed, and
// the render error covered the whole view. Picking an opening is how a user
// reaches the tools for drawing inside one, and choosing **Divides → inside
// the opening** picks one too, so both ways of giving a line to an opening
// hit it.
//
// The window is wide, and then narrow, and the tools have to be on it and
// within it either way.

/// Every tool that must be reachable, in the order the strip puts them.
List<String> get toolLabels =>
    [for (final tool in InsideTool.values) tool.label, 'Erase'];

void main() {

  testWidgets('the tools inside an opening are all on the strip, and all within it',
      (tester) async {
    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => errors.add('${details.exception}');
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final design = fin.drawn();
    await tester.binding.setSurfaceSize(const Size(1280, 820));

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(workspaceProvider.notifier);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const ProFrameApp(),
    ));
    await tester.pumpAndSettle();
    await toTheCategories(tester);
    await tester.tap(find.text('WINDOW'));
    await tester.pumpAndSettle();

    controller
      ..openDesign(design)
      ..showView(WorkspaceView.plan)
      ..select(design.openings.single.sectionId);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.text(InsideTool.horizontalLine.label), findsOneWidget,
        reason: 'picking the opening should put its own tools up');

    // Every tool is on the strip, and every one of them is within the
    // window rather than pushed off the edge of it. At 1280 the old `Row`
    // ran 690px past the right-hand edge, which is what put the render
    // error over the view.
    // Put the handler back before asserting: `expect` while it is still
    // overridden makes the framework report a bookkeeping failure instead
    // of this test's own.
    FlutterError.onError = previous;
    expect(errors, isEmpty, reason: errors.join(', '));

    final window = Offset.zero & const Size(1280, 820);
    for (final label in toolLabels) {
      final found = find.text(label);
      expect(found, findsWidgets, reason: '$label is missing from the strip');
      final at = tester.getRect(found.last);
      expect(window.contains(at.topLeft), isTrue,
          reason: '$label starts off the window');
      expect(window.contains(at.bottomRight), isTrue,
          reason: '$label runs off the window');
    }
  });
}
