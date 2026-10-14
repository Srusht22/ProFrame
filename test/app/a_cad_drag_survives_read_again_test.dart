import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/cad_painter.dart';
import 'package:proframe/app/canvas/design_painter.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/state/tools.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a_customer_s_page_test.dart' as page;
import 'a_design_in_every_view_test.dart' as every;
import 'customers_screen_test.dart' as customers;
import 'new_design.dart' show showEverything;
import 'the_designs_screen_test.dart' as screen;

// The fault, the way the user met it: on the technical drawing the head of
// a door is picked and dragged down by its grip, and the door is shorter;
// then **Read again** — and the door was its old height again, because the
// reading rebuilt the frame from the ink and the drag had never moved the
// ink. This is that, on the real app, with the pointer: the grip the CAD
// view puts on the head, a drag of it, and the button.

/// The technical drawing's painter and where its canvas starts.
(CadPainter, Offset) _cad(WidgetTester tester) {
  final paint = find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter is CadPainter,
  );
  return (
    tester.widget<CustomPaint>(paint).painter! as CadPainter,
    tester.getTopLeft(paint),
  );
}

Offset _onScreen(WidgetTester tester, Vec2 sheet) {
  final (painter, origin) = _cad(tester);
  return origin + painter.view.toScreen(sheet);
}

double _height(Design d) => d.frame!.outline.height;
double _top(Design d) => d.frame!.outline.top;

Future<void> _openBasementDoor(WidgetTester tester) async {
  await customers.toCustomers(tester);
  await page.openCustomer(tester, 'Adam');
  final open = find
      .byKey(CustomerDesignCard.openKey('basement-door'))
      .hitTestable();
  await tester.scrollUntilVisible(
    open,
    100,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(open);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the head dragged down on the technical drawing stays down '
      'through Read again, and every view shows it', (tester) async {
    await every.keepAdam();
    final c = await screen.openTheApp(tester, size: every.laptop);
    await _openBasementDoor(tester);
    await every.showView(tester, WorkspaceView.plan);
    await showEverything(tester);

    final before = c.read(workspaceProvider).design;
    final head = Vec2(
      (before.frame!.outline.left + before.frame!.outline.right) / 2,
      _top(before),
    );

    // Pick the frame on its head, then drag the head's grip down.
    await tester.tapAt(_onScreen(tester, head));
    await tester.pumpAndSettle();
    final from = _onScreen(tester, head);
    final to = _onScreen(tester, head + const Vec2(0, 150));
    final drag = await tester.startGesture(from);
    for (var i = 1; i <= 10; i++) {
      await drag.moveTo(Offset.lerp(from, to, i / 10)!);
      await tester.pump();
    }
    await drag.up();
    await tester.pumpAndSettle();

    final dragged = c.read(workspaceProvider).design;
    expect(
      _height(dragged),
      lessThan(_height(before) - 100),
      reason: 'the drag took the head down',
    );
    expect(
      identical(every.painterOf<CadPainter>(tester).design, dragged),
      isTrue,
    );

    // The primary regression: Read again.
    await tester.tap(find.text('Read again'));
    await tester.pumpAndSettle();
    final read = c.read(workspaceProvider).design;
    expect(identical(read, dragged), isFalse, reason: 'the sheet was read');
    expect(_height(read), closeTo(_height(dragged), 1e-6));
    expect(_top(read), closeTo(_top(dragged), 1e-6));
    expect(read.openings, hasLength(before.openings.length));
    expect(read.dividers, hasLength(before.dividers.length));

    // And each view draws the design as read.
    expect(identical(every.painterOf<CadPainter>(tester).design, read), isTrue);
    await every.showView(tester, WorkspaceView.draw);
    expect(
      identical(every.painterOf<DesignPainter>(tester).design, read),
      isTrue,
    );
    await every.showView(tester, WorkspaceView.plan);
    await tester.tap(find.text('Read again'));
    await tester.pumpAndSettle();
    expect(
      _height(c.read(workspaceProvider).design),
      closeTo(_height(dragged), 1e-6),
      reason: 'a second Read, after a trip to the drawing, the same',
    );
  });
}
