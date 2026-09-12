import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/app.dart';
import 'package:proframe/app/widgets/workspace_scaffold.dart';
import 'package:proframe/core/design/app_theme.dart';
import 'package:proframe/core/design/tokens.dart';

/// The sizes spec section 12D names, plus the two orientations.
const sizes = <String, Size>{
  'phone portrait 360': Size(360, 800),
  'phone landscape 800x360': Size(800, 360),
  'tablet portrait 600': Size(600, 960),
  'tablet landscape 900': Size(900, 700),
  'desktop 1440': Size(1440, 900),
};

Future<void> setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> pumpApp(
  WidgetTester tester,
  Size size, {
  double textScale = 1.0,
}) async {
  await setSize(tester, size);
  await tester.pumpWidget(
    ProviderScope(
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: ProFrameApp(idFactory: () => 'test-project'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the app lays out at every size without overflowing', () {
    // Flutter turns an overflow into a test failure, so simply pumping each
    // size is a real regression test for the layout (spec section 12D).
    for (final entry in sizes.entries) {
      testWidgets(entry.key, (tester) async {
        await pumpApp(tester, entry.value);

        expect(find.text('What are you making?'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('large text is supported at every size', () {
    for (final entry in sizes.entries) {
      testWidgets('${entry.key} at 1.6x text', (tester) async {
        await pumpApp(tester, entry.value, textScale: 1.6);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a text scale beyond the cap does not break the layout',
        (tester) async {
      // The OS allows well over 2x. The app clamps rather than letting the
      // workspace be squeezed off screen.
      await pumpApp(tester, const Size(360, 800), textScale: 3.0);

      expect(tester.takeException(), isNull);
    });
  });

  group('creating a design', () {
    testWidgets('both product choices are offered and neither is preselected',
        (tester) async {
      await pumpApp(tester, const Size(1440, 900));

      expect(find.text('Door'), findsOneWidget);
      expect(find.text('Window'), findsOneWidget);
      // Nothing is chosen for the user, so Start drawing is not yet available.
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Start drawing'),
      );
      expect(button.onPressed, isNull);
      expect(find.text('Choose a product and a material to continue.'),
          findsOneWidget);
    });

    testWidgets('the material choice only appears once it is relevant',
        (tester) async {
      await pumpApp(tester, const Size(1440, 900));

      // Colour and profile are hidden until a material is chosen, so the first
      // screen stays to two decisions (spec section 3A).
      expect(find.text('Colour'), findsNothing);
      expect(find.text('Profile system'), findsNothing);

      await tester.tap(find.text('PVC'));
      await tester.pumpAndSettle();

      expect(find.text('Colour'), findsOneWidget);
      expect(find.text('Profile system'), findsOneWidget);
    });

    testWidgets('choosing a material selects that material\'s profile',
        (tester) async {
      await pumpApp(tester, const Size(1440, 900));

      await tester.tap(find.text('Aluminium'));
      await tester.pumpAndSettle();

      // The factory default is pre-selected so a beginner never opens this.
      expect(find.text('Generic aluminium casement'), findsOneWidget);
      expect(find.text('Generic PVC casement'), findsNothing);
    });

    testWidgets('the generic-profile warning is shown, not buried',
        (tester) async {
      await pumpApp(tester, const Size(1440, 900));

      await tester.tap(find.text('PVC'));
      await tester.pumpAndSettle();

      expect(find.text('These are preview profiles'), findsOneWidget);
      expect(
        find.textContaining('must be replaced with your supplier'),
        findsOneWidget,
      );
    });

    testWidgets('a complete choice creates a real design', (tester) async {
      await pumpApp(tester, const Size(1440, 900));

      await tester.tap(find.text('Window'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PVC'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Start drawing'));
      await tester.pumpAndSettle();

      expect(find.text('Design created'), findsOneWidget);
      expect(find.text('Window'), findsWidgets);
      // The design states what is still missing rather than implying it is
      // ready (spec section 2).
      expect(find.text('Still to confirm'), findsOneWidget);
      expect(
        find.textContaining('has not been interpreted'),
        findsOneWidget,
      );
    });
  });

  group('the workspace shell arranges itself by width', () {
    Widget shell() => MaterialApp(
          theme: AppTheme.light(),
          home: const WorkspaceScaffold(
            title: 'Workspace',
            tools: [Icon(Icons.edit), Icon(Icons.straighten)],
            canvas: ColoredBox(color: AppColors.canvasSurface),
            properties: Text('Section properties'),
          ),
        );

    testWidgets('compact hides the panel behind a button', (tester) async {
      await setSize(tester, const Size(360, 800));
      await tester.pumpWidget(shell());
      await tester.pumpAndSettle();

      expect(find.text('Section properties'), findsNothing);
      expect(find.text('Properties'), findsOneWidget);

      await tester.tap(find.text('Properties'));
      await tester.pumpAndSettle();

      expect(find.text('Section properties'), findsOneWidget);
    });

    testWidgets('expanded shows the panel alongside the canvas',
        (tester) async {
      await setSize(tester, const Size(1440, 900));
      await tester.pumpWidget(shell());
      await tester.pumpAndSettle();

      // No button needed: the panel is simply there.
      expect(find.text('Section properties'), findsOneWidget);
      expect(find.text('Properties'), findsNothing);
    });

    testWidgets('medium can fold the panel away to widen the canvas',
        (tester) async {
      await setSize(tester, const Size(900, 700));
      await tester.pumpWidget(shell());
      await tester.pumpAndSettle();

      expect(find.text('Section properties'), findsOneWidget);

      await tester.tap(find.byTooltip('Hide properties'));
      await tester.pumpAndSettle();

      expect(find.text('Section properties'), findsNothing);
    });

    testWidgets('a landscape phone drops the app bar to save height',
        (tester) async {
      await setSize(tester, const Size(800, 360));
      await tester.pumpWidget(shell());
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an upright tablet keeps the app bar', (tester) async {
      await setSize(tester, const Size(600, 960));
      await tester.pumpWidget(shell());
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
    });
  });

  testWidgets('rotating the device does not change the design', (tester) async {
    await pumpApp(tester, const Size(1440, 900));

    await tester.tap(find.text('Window'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PVC'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Start drawing'));
    await tester.pumpAndSettle();

    expect(find.text('Design created'), findsOneWidget);
    expect(find.text('PVC'), findsOneWidget);

    // Rotate to portrait.
    tester.view.physicalSize = const Size(900, 1440);
    await tester.pumpAndSettle();

    // Same design, same choices, no exception. Model dimensions are in
    // millimetres and independent of the screen (spec section 8).
    expect(find.text('Design created'), findsOneWidget);
    expect(find.text('PVC'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
