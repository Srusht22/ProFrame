import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/app.dart';
import 'package:proframe/app/state/tools.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/model/design.dart';

import 'new_design.dart';
import 'pause_and_take_it_back_test.dart' as sheet;

// A striped "OVERFLOWED BY 121 PIXELS" over the 3D model, on the user's own
// screen: the list of parts open beside the model narrowed it, and the bar
// of depth, profile and the Open slider had no way to give. That is a render
// error laid over the design, so every view is opened here at the width a
// laptop browser leaves, with the parts list open beside it, and any
// overflow at all fails the test.

void main() {
  for (final size in const [Size(1040, 700), Size(1280, 820)]) {
    testWidgets('no view overflows at ${size.width.toInt()} wide, parts open', (
      tester,
    ) async {
      final errors = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) =>
          errors.add(details.toString().split('\n').take(12).join('\n'));
      addTearDown(() => FlutterError.onError = previous);

      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ProFrameApp(),
        ),
      );
      await tester.pumpAndSettle();
      await toTheCategories(tester);
      await tester.tap(find.text('DOOR & WINDOW'));
      await tester.pumpAndSettle();

      final controller = await sheet.twoLeaves(container);
      final order = container.read(workspaceProvider).design.openingsInOrder;
      controller
        ..setOpeningKind(order[0].id, DesignKind.window)
        ..setOpeningKind(order[1].id, DesignKind.door);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Parts'));
      await tester.pumpAndSettle();

      for (final view in WorkspaceView.values) {
        controller.showView(view);
        await tester.pumpAndSettle();
        // And with an opening picked, which puts up the longest panel.
        controller.select(order.first.id);
        await tester.pumpAndSettle();
        controller.select(null);
        await tester.pumpAndSettle();
      }

      FlutterError.onError = previous;
      expect(errors, isEmpty, reason: errors.join('\n\n'));
    });
  }
}
