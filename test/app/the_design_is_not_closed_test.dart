import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/inspector/outline_gap_alert.dart';
import 'package:proframe/app/inspector/questions_panel.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/sketch/stroke.dart';

import 'pause_and_take_it_back_test.dart' as sheet;

// The user's words: *if a side of the border is not complete, an alert says
// "the design is not completed — do you want it that way, or are you going
// to change it?"* Held here on the real app: a door drawn with no line
// across its foot, read, and the alert over the work — then each answer.

Future<WorkspaceController> noFoot(ProviderContainer c) async {
  final controller = c.read(workspaceProvider.notifier);
  controller.state = controller.state.copyWith(
    design: controller.state.design.copyWith(
      sketch: Sketch(strokes: [
        sheet.pen('outline', const [
          Vec2(0, 2100),
          Vec2(0, 0),
          Vec2(1000, 0),
          Vec2(1000, 2100),
        ]),
        sheet.pen('transom', const [Vec2(0, 300), Vec2(1000, 300)]),
        sheet.pen('k', sheet.chevron(const Vec2(500, 1200))),
      ]),
    ),
  );
  controller.readDrawing();
  return controller;
}

void main() {
  testWidgets('reading it puts the alert over the work', (tester) async {
    final c = await sheet.openTheApp(tester, 'DOOR');
    await noFoot(c);
    await tester.pumpAndSettle();

    expect(find.byType(OutlineGapAlert), findsOneWidget);
    expect(find.text('Design not closed'), findsOneWidget);
    expect(find.textContaining('the bottom is open'), findsOneWidget);
    expect(find.textContaining('Do you want it this way'), findsOneWidget);
    for (final label in ['Keep it open', 'Close it', 'I will change it']) {
      expect(find.text(label), findsOneWidget);
    }
    // An alert, not a line in the panel below the drawing as well.
    expect(
      find.descendant(
        of: find.byType(QuestionsPanel),
        matching: find.textContaining('not closed'),
      ),
      findsNothing,
    );
  });

  testWidgets('keep it open: built as drawn, and not asked again', (
    tester,
  ) async {
    final c = await sheet.openTheApp(tester, 'DOOR');
    final controller = await noFoot(c);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Keep it open'));
    await tester.pumpAndSettle();

    final design = c.read(workspaceProvider).design;
    expect(design.outlineGap, OutlineGap.leaveOpen);
    expect(design.frame, isNotNull);
    expect(design.frame!.openEdges, hasLength(1));
    expect(design.openings, hasLength(1));
    expect(find.text('Design not closed'), findsNothing);

    controller.readDrawing();
    await tester.pumpAndSettle();
    expect(find.text('Design not closed'), findsNothing);
    expect(c.read(workspaceProvider).design.frame!.openEdges, hasLength(1));
  });

  testWidgets('close it: a sill across the foot', (tester) async {
    final c = await sheet.openTheApp(tester, 'DOOR');
    await noFoot(c);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Close it'));
    await tester.pumpAndSettle();

    final design = c.read(workspaceProvider).design;
    expect(design.outlineGap, OutlineGap.closeIt);
    expect(design.frame!.openEdges, isEmpty);
    expect(design.frameMembers.map((m) => m.placement), contains('Sill'));
  });

  testWidgets('I will change it: nothing is built, the drawing is theirs', (
    tester,
  ) async {
    final c = await sheet.openTheApp(tester, 'DOOR');
    await noFoot(c);
    await tester.pumpAndSettle();

    await tester.tap(find.text('I will change it'));
    await tester.pumpAndSettle();

    final design = c.read(workspaceProvider).design;
    expect(design.outlineGap, isNull);
    expect(design.frame, isNull);
    expect(find.text('Design not closed'), findsNothing);
    expect(design.sketch.strokes, hasLength(3), reason: 'nothing added');
  });
}
