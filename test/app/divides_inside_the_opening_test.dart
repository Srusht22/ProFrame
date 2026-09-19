import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/app.dart';
import 'package:proframe/app/state/tools.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/vec2.dart';

import '../final_visual_and_3d_test.dart' as fin;

// Choosing **Divides → inside the opening** on a bar's own panel.
//
// This is how a line the user drew on the sheet becomes one specific
// opening's. It sets `parentId` to the opening's id, and it also selects
// something inside an opening — which is what used to put the render error
// over the view, because that is what raises the strip of tools.

void main() {
  testWidgets('choosing Divides → inside the opening raises nothing',
      (tester) async {
    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => errors.add('${details.exception}');
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // A line drawn on the sheet, lying across the opening's region. Until
    // the user says otherwise it divides the design; **Divides** is where
    // they say otherwise.
    var design = fin.sheet();
    final box = design.sectionById(design.openings.single.sectionId)!.outline;
    design = DesignEdits.addDivider(
      design,
      id: 'hand-line',
      a: Vec2(box.left + 2, box.top + box.height * 0.4),
      b: Vec2(box.right - 2, box.top + box.height * 0.4),
    );

    await tester.binding.setSurfaceSize(const Size(1280, 820));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(workspaceProvider.notifier);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const ProFrameApp(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('WINDOW'));
    await tester.pumpAndSettle();

    controller
      ..openDesign(design)
      ..showView(WorkspaceView.plan)
      ..select('hand-line');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    final dropdown = find.byType(DropdownButtonFormField<String>);
    expect(dropdown, findsOneWidget, reason: 'the Divides control');
    await tester.ensureVisible(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Inside the opening').last,
        warnIfMissed: false);
    await tester.pumpAndSettle();

    FlutterError.onError = previous;
    expect(errors, isEmpty, reason: errors.join('\n'));

    // And it did what it says: the line is the opening's, not the window's.
    final after = container.read(workspaceProvider).design;
    expect(after.dividerById('hand-line')!.parentId,
        after.openings.single.id);
    expect(after.topLevelDividers.map((bar) => bar.id),
        isNot(contains('hand-line')));
    expect(after.openings, hasLength(1), reason: 'no second opening');
  });
}
