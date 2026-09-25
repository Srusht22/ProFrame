import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/app.dart';
import 'package:proframe/app/state/tools.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/app/theme/app_theme.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/sketch/stroke.dart';

import 'new_design.dart';

void main() {
  testWidgets('choose your design: a door and a window, and the rest',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ProviderScope(child: ProFrameApp()));
    await tester.pumpAndSettle();
    await toTheCategories(tester);

    expect(find.text('Choose your design'), findsOneWidget);
    expect(
      find.text('Select the type of product you want to create.'),
      findsOneWidget,
    );
    expect(find.text('DOOR'), findsOneWidget);
    expect(find.text('WINDOW'), findsOneWidget);
    expect(find.text('DOOR & WINDOW'), findsOneWidget);
    expect(find.text('SLIDING'), findsOneWidget);
  });

  testWidgets('picking a window opens the workspace with the canvas dominant',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ProviderScope(child: ProFrameApp()));
    await tester.pumpAndSettle();
    await toTheCategories(tester);

    await chooseDesign(tester, 'WINDOW');

    // Known by who it is for.
    expect(find.text('Test customer'), findsOneWidget);
    expect(find.text('Draw'), findsOneWidget);
    expect(find.text('CAD drawing'), findsOneWidget);
    expect(find.text('3D model'), findsOneWidget);

    // Every tool is reachable.
    for (final label in [
      'Select',
      'Freehand',
      'Straight\nline',
      'Rectangle',
      'Polyline',
      'Dimension',
      'Arrow',
      'Note',
      'Eraser',
    ]) {
      expect(find.text(label.replaceAll('\n', ' ')), findsAny,
          reason: 'the $label tool should be on the rail');
    }
  });

  testWidgets('the canvas is the biggest thing on screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ProviderScope(child: ProFrameApp()));
    await tester.pumpAndSettle();
    await toTheCategories(tester);
    await chooseDesign(tester, 'WINDOW');

    final rail = tester.getSize(find.byType(Scaffold).last);
    expect(rail.width, 1400);

    // Tools take 76, the inspector 320: the drawing keeps the rest.
    expect(1400 - 76 - 320, greaterThan(1400 * 0.65));
  });

  testWidgets('a drawn design shows the read prompt, and reading it works',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    late WidgetRef captured;
    await tester.pumpWidget(ProviderScope(
      child: Consumer(builder: (context, ref, _) {
        captured = ref;
        return const ProFrameApp();
      }),
    ));
    await tester.pumpAndSettle();
    await toTheCategories(tester);
    await chooseDesign(tester, 'WINDOW');

    captured.read(workspaceProvider.notifier).addStroke(
      const [
        StrokeSample(Vec2(0, 0)),
        StrokeSample(Vec2(1000, 0)),
        StrokeSample(Vec2(1000, 2000)),
        StrokeSample(Vec2(0, 2000)),
        StrokeSample(Vec2(0, 0)),
      ],
      tool: Tool.pen,
    );
    await tester.pumpAndSettle();

    expect(find.text('Read my drawing'), findsOneWidget);
    await tester.tap(find.text('Read my drawing'));
    await tester.pumpAndSettle();

    final design = captured.read(workspaceProvider).design;
    expect(design.frame, isNotNull);
    expect(design.sections, hasLength(1));

    // And nothing is asked about it. The drawing said what the shape is, so
    // it is built; the size is on the panel beside it, ready to be typed
    // over, which is an edit rather than a question.
    expect(find.textContaining('How wide is this'), findsNothing);
    expect(find.textContaining('One thing to check'), findsNothing);
    expect(find.text('OVERALL WIDTH'), findsOneWidget);
  });

  testWidgets('the theme uses the stated colours', (tester) async {
    final theme = AppTheme.build();
    expect(theme.colorScheme.primary, const Color(0xFF013E37));
    expect(theme.colorScheme.secondary, const Color(0xFFFFEFB3));
    expect(theme.appBarTheme.backgroundColor, const Color(0xFF013E37));
  });
}
