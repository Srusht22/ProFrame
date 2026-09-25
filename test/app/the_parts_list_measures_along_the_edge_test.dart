import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/app.dart';
import 'package:proframe/app/inspector/component_tree.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/model/elements.dart';

import 'new_design.dart';
import 'pause_and_take_it_back_test.dart' as sheet;

// A bottom hung sash's hinges run along its bottom rail, so both are at the
// bottom: measuring them "up" read "0 cm up" twice in the list of parts,
// which is true and tells you nothing about either. They are measured in
// from the left, as the opening's own panel measures them.

void main() {
  testWidgets('a bottom hung leaf lists its hinges in from the left',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const ProFrameApp(),
    ));
    await tester.pumpAndSettle();
    await toTheCategories(tester);
    await tester.tap(find.text('WINDOW'));
    await tester.pumpAndSettle();

    final controller = await sheet.twoLeaves(container);
    final order = container.read(workspaceProvider).design.openingsInOrder;
    controller
      ..setOpeningKind(order[0].id, DesignKind.window)
      ..setOpeningKind(order[1].id, DesignKind.window)
      ..setOpeningMechanism(order[0].id, OpeningMechanism.bottomHung);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Parts'));
    await tester.pumpAndSettle();

    expect(find.textContaining('from the left'), findsWidgets);
    expect(find.text('0 cm up'), findsNothing);
    // The side hung leaf beside it is still measured up from its bottom —
    // further down the list, so it is scrolled to first.
    await tester.scrollUntilVisible(
      find.textContaining(' up'),
      120,
      scrollable: find
          .descendant(
            of: find.byType(ComponentTree),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.textContaining(' up'), findsWidgets);
  });
}
