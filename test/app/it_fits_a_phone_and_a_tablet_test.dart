import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/app.dart';
import 'package:proframe/app/inspector/component_tree.dart';
import 'package:proframe/app/inspector/inspector_panel.dart';
import 'package:proframe/app/screens/tool_bar.dart';
import 'package:proframe/app/screens/workspace_bars.dart';
import 'package:proframe/app/screens/workspace_screen.dart';
import 'package:proframe/app/state/tools.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/model/design.dart';

import 'new_design.dart';
import 'pause_and_take_it_back_test.dart' as sheet;

// The user's screenshot: the workspace on a phone, with a striped overflow
// across the bar of views and most of the controls off the edge of the
// screen. The workspace is laid out by the room it is given — the tools the
// navigation bar along the bottom and the views the one across the top on
// every screen, and what is picked in a drawer on a phone and a tablet —
// and nothing overflows at any of the sizes people hold.

const phones = [Size(360, 740), Size(390, 844), Size(440, 956)];
const tablets = [Size(768, 1024), Size(820, 1180), Size(1024, 768)];

Future<(ProviderContainer, WorkspaceController)> twoLeavesAt(
  WidgetTester tester,
  Size size,
) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const ProFrameApp()),
  );
  await tester.pumpAndSettle();
  await toTheCategories(tester);
  await tester.scrollUntilVisible(
    find.text('DOOR & WINDOW'),
    100,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text('DOOR & WINDOW'));
  await tester.pumpAndSettle();

  final controller = await sheet.twoLeaves(container);
  final order = container.read(workspaceProvider).design.openingsInOrder;
  controller
    ..setOpeningKind(order[0].id, DesignKind.window)
    ..setOpeningKind(order[1].id, DesignKind.door);
  await tester.pumpAndSettle();
  return (container, controller);
}

/// Every flex on the screen that is overflowing, and where it was made.
/// Walking the render tree finds all of them, not only the first error.
List<String> overflowing(WidgetTester tester, String where) => [
  for (final r in tester.allRenderObjects)
    if (r is RenderFlex && r.toStringShort().contains('OVERFLOWING'))
      '[$where] ${r.debugCreator.toString().split('\n').first}',
];

void main() {
  for (final size in [...phones, ...tablets]) {
    testWidgets(
      'nothing overflows at ${size.width.toInt()} × ${size.height.toInt()}',
      (tester) async {
        final errors = <String>[];
        final (container, controller) = await twoLeavesAt(tester, size);
        final first = container
            .read(workspaceProvider)
            .design
            .openingsInOrder
            .first;
        errors.addAll(overflowing(tester, 'drawn'));

        for (final view in WorkspaceView.values) {
          controller.showView(view);
          await tester.pumpAndSettle();
          errors.addAll(overflowing(tester, view.name));

          controller.select(first.id);
          await tester.pumpAndSettle();
          errors.addAll(overflowing(tester, '${view.name}, picked'));

          final scaffold = tester.state<ScaffoldState>(
            find.byType(Scaffold).last,
          );
          if (scaffold.hasEndDrawer) {
            scaffold.openEndDrawer();
            await tester.pumpAndSettle();
            errors.addAll(overflowing(tester, '${view.name}, drawer'));
            scaffold.closeEndDrawer();
            await tester.pumpAndSettle();
          }
          controller.select(null);
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        expect(errors, isEmpty, reason: errors.join('\n'));
      },
    );
  }

  for (final size in const [Size(390, 844), Size(820, 1180), Size(1280, 820)]) {
    testWidgets('the tools are the navigation bar along the bottom at '
        '${size.width.toInt()} wide', (tester) async {
      await twoLeavesAt(tester, size);
      final bar = find.byType(ToolBar);
      expect(bar, findsOneWidget);
      expect(tester.getRect(bar).bottom, closeTo(size.height, 1));
      expect(tester.getRect(bar).width, closeTo(size.width, 1));
      // Every tool is on it, reached by scrolling it if need be.
      for (final tool in Tool.values) {
        expect(
          find.descendant(of: bar, matching: find.text(tool.label)),
          findsOneWidget,
        );
      }
      // And the views are the navigation across the top.
      final views = find.byType(ViewTabs);
      expect(tester.getRect(views).top, lessThan(size.height / 4));
    });
  }

  group('on a phone', () {
    testWidgets('the three views share the width, and each is named', (
      tester,
    ) async {
      await twoLeavesAt(tester, const Size(360, 740));
      for (final view in WorkspaceView.values) {
        expect(find.text(view.shortLabel), findsOneWidget);
      }
      // Nothing of the bar is off the screen.
      for (final tip in ['Read again', 'Parts', 'Details']) {
        final button = find.byTooltip(tip);
        expect(button, findsOneWidget);
        expect(tester.getRect(button).right, lessThanOrEqualTo(360));
      }
    });

    testWidgets('what is picked is named, and Edit opens it', (tester) async {
      final (container, controller) = await twoLeavesAt(
        tester,
        const Size(390, 844),
      );
      final design = container.read(workspaceProvider).design;
      final first = design.openingsInOrder.first;
      expect(find.byType(InspectorPanel), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);

      controller.select(first.id);
      await tester.pumpAndSettle();
      expect(find.text(design.nameOf(first)), findsWidgets);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.byType(InspectorPanel), findsOneWidget);

      // The drawer leaves some of the drawing showing beside it.
      final drawer = tester.getRect(find.byType(Drawer));
      expect(drawer.width, lessThan(390));
      tester.state<ScaffoldState>(find.byType(Scaffold).last).closeEndDrawer();
      await tester.pumpAndSettle();

      // Letting it go puts the bar away.
      await tester.tap(find.byTooltip('Let it go'));
      await tester.pumpAndSettle();
      expect(container.read(workspaceProvider).selected, isNull);
      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('the parts open in the drawer', (tester) async {
      await twoLeavesAt(tester, const Size(390, 844));
      await tester.tap(find.byTooltip('Parts'));
      await tester.pumpAndSettle();
      expect(find.byType(ComponentTree), findsOneWidget);
    });
  });

  testWidgets('on a tablet what is picked is in a drawer', (tester) async {
    await twoLeavesAt(tester, const Size(820, 1180));
    // Not in a panel narrowing the drawing.
    expect(find.byType(InspectorPanel), findsNothing);
    await tester.tap(find.byTooltip('Details'));
    await tester.pumpAndSettle();
    expect(find.byType(InspectorPanel), findsOneWidget);
  });

  test('the layout follows the room, not the device', () {
    expect(WorkspaceLayout.of(390), WorkspaceLayout.phone);
    expect(WorkspaceLayout.of(820), WorkspaceLayout.tablet);
    expect(WorkspaceLayout.of(1280), WorkspaceLayout.desktop);
  });
}
