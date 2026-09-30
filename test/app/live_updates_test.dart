import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' as widgets;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/cad_painter.dart';
import 'package:proframe/app/canvas/design_painter.dart';
import 'package:proframe/app/inspector/component_tree.dart';
import 'package:proframe/app/inspector/inspector_panel.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/screens/tool_bar.dart';
import 'package:proframe/app/screens/workspace_screen.dart';
import 'package:proframe/app/state/tools.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/app/viewer/display_style.dart';
import 'package:proframe/app/viewer/model_painter.dart';
import 'package:proframe/app/viewer/model_view.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/solid/camera.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/many_openings_in_one_design_test.dart' as many;
import 'a_customer_s_page_test.dart' as page;
import 'a_design_in_every_view_test.dart' as every;
import 'customers_screen_test.dart' as customers;
import 'the_designs_screen_test.dart' as screen;

// Phase 17 of the CAD and 3D work: the views follow every edit, at once, and
// only the view that needs to does any work.
//
// There is one design, in the workspace's state, and every view is built
// from it — so an edit made anywhere is the edit every view shows, with
// nothing to refresh by hand. This holds that on the real app, edit by edit,
// with each view on the screen: the width, the height, a divider moved, an
// opening turned the other way, a panel recoloured, a glass changed, a
// hinge added and taken away, a line added inside a pane and deleted.
//
// Then the two things an edit must not do to the other kind of thing: a
// change of material moves no geometry, and a change of geometry resets no
// material — every pane keeps its glass or its panel and its colour, the
// frame its colour, the ironmongery its finish, through every geometry edit
// and a second reading of the sheet.
//
// And the work is only done where it is needed. Turning the model, swinging
// its leaves or changing how it is drawn is a way of looking, not an edit:
// it rebuilds the model view and nothing else — not the bars, the panels,
// the parts or the drawings — and the solid itself, and its floor, are kept
// rather than built again for every pointer move.

// ------------------------------------------------------------------ helpers

/// The panes of [opening], found by where they are: the one holding a point
/// near the head of it and the one holding a point near its foot.
(SectionElement?, SectionElement?) _panesOf(Design d, OpeningElement opening) {
  final box = d.sectionById(opening.sectionId)!.outline;
  SectionElement? at(double share) {
    final p = Vec2(box.centroid.x, box.top + box.height * share);
    for (final s in d.childSectionsOf(opening.sectionId)) {
      if (s.outline.contains(p)) return s;
    }
    return null;
  }

  return (at(0.12), at(0.88));
}

/// What every part is finished in, keyed by what the part *is* rather than
/// by an id an edit may renumber: the frame, each bar by its id, each main
/// division by its place in reading order, each opening's upper and lower
/// pane, and each piece of ironmongery by its kind and opening.
Map<String, String> _finishes(Design d) {
  String of(Finish f) => '${f.material.name}:${f.colour.toRadixString(16)}';
  return {
    'frame': of(d.frame!.finish),
    for (final b in d.dividers) 'bar ${b.id}': of(b.finish),
    for (final (i, s) in d.topLevelSections.indexed)
      if (d.openingOf(s.id) == null) 'light $i': of(s.finish),
    for (final o in d.openings) ...{
      if (_panesOf(d, o).$1 case final s?) '${o.id} upper': of(s.finish),
      if (_panesOf(d, o).$2 case final s?) '${o.id} lower': of(s.finish),
    },
    for (final h in d.hardware)
      '${h.kind.name} of ${d.openingHolding(h.parentId)?.id} '
          '${d.hardware.where((x) => x.kind == h.kind && x.parentId == h.parentId).toList().indexOf(h)}': of(
        h.finish,
      ),
  };
}

/// Where everything is: the frame, the bars, every section's outline — and
/// nothing about what anything is made of.
String _geometry(Design d) => jsonEncode({
  'frame': d.frame!.outline.toJson(),
  'depth': d.depthMm,
  'bars': [
    for (final b in d.dividers) [b.id, b.a.x, b.a.y, b.b.x, b.b.y, b.widthMm],
  ],
  'sections': [
    for (final s in d.sections) [s.id, s.parentId, s.outline.toJson()],
  ],
  'openings': [for (final o in d.openings) o.toJson()],
  'hardware': [
    for (final h in d.hardware) [h.id, h.kind.name, h.at.x, h.at.y],
  ],
});

/// Three windows under a fixed head, each glass over panel, and every part
/// given a finish of its own — so a finish reset to anything is seen.
Design _dressed() {
  var d = many.fittedOut();
  final order = d.openingsInOrder;
  final head = d.topLevelSections.firstWhere((s) => d.openingOf(s.id) == null);
  final (upper1, _) = _panesOf(d, order[0]);
  final (_, lower2) = _panesOf(d, order[1]);
  d = d.copyWith(
    frame: d.frame!.copyWith(
      finish: d.frame!.finish.copyWith(colour: 0xFF22262A),
    ),
    sections: [
      for (final s in d.sections)
        if (s.id == head.id)
          s.copyWith(finish: GlassLook.tinted.finish)
        else if (s.id == upper1!.id)
          s.copyWith(finish: GlassLook.frosted.finish)
        else if (s.id == lower2!.id)
          s.copyWith(finish: PanelColour.grey.finish)
        else
          s,
    ],
    hardware: [
      for (final h in d.hardware)
        h.copyWith(
          finish: h.finish.copyWith(colour: HardwareColour.bronze.colour),
        ),
    ],
  );
  return d;
}

ProviderContainer _workspaceWith(Design d) {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  c.read(workspaceProvider.notifier).openDesign(d);
  return c;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('a change of geometry resets no material', () {
    // Each of these is the user's own edit, through the workspace, as the
    // panels, the figures and the drawing make it.
    final edits = <String, void Function(ProviderContainer)>{
      'the width typed': (c) {
        final d = c.read(workspaceProvider).design;
        c
            .read(workspaceProvider.notifier)
            .resizeFrame(widthMm: d.frame!.outline.width + 450);
      },
      'the height typed': (c) {
        final d = c.read(workspaceProvider).design;
        c
            .read(workspaceProvider.notifier)
            .resizeFrame(heightMm: d.frame!.outline.height - 300);
      },
      'a divider moved inside its opening': (c) {
        final d = c.read(workspaceProvider).design;
        final bar = d.dividers.firstWhere(
          (b) => d.openingHolding(b.parentId) != null,
        );
        c
            .read(workspaceProvider.notifier)
            .moveDividerWithin(bar.id, DesignEdits.alongWithin(d, bar)! + 180);
      },
      'a mullion dragged': (c) {
        final d = c.read(workspaceProvider).design;
        final mullion = d.topLevelDividers.firstWhere((b) => b.isVertical);
        c
            .read(workspaceProvider.notifier)
            .moveDividerTo(
              mullion.id,
              mullion.segment.midpoint + const Vec2(-140, 0),
            );
      },
      'an opening turned to open outward': (c) {
        final d = c.read(workspaceProvider).design;
        c
            .read(workspaceProvider.notifier)
            .setOpeningSwing(d.openingsInOrder[1].id, OpeningDirection.outward);
      },
      'an opening given three hinges': (c) {
        final d = c.read(workspaceProvider).design;
        c
            .read(workspaceProvider.notifier)
            .setOpeningHardware(d.openingsInOrder[2].id, hingeCount: 3);
      },
      'the depth changed': (c) =>
          c.read(workspaceProvider.notifier).setDepth(90),
      'the sheet read again': (c) =>
          c.read(workspaceProvider.notifier).readDrawing(),
    };

    for (final MapEntry(key: what, value: edit) in edits.entries) {
      test(what, () {
        final c = _workspaceWith(_dressed());
        final before = c.read(workspaceProvider).design;
        edit(c);
        final after = c.read(workspaceProvider).design;
        expect(
          _geometry(after),
          isNot(_geometry(before)),
          reason: 'the edit is a change of geometry',
        );
        final was = _finishes(before), now = _finishes(after);
        for (final key in was.keys) {
          if (!now.containsKey(key)) continue; // a hinge that is not there
          expect(now[key], was[key], reason: key);
        }
        // And nothing was lost that was there.
        expect(
          now.keys.where((k) => !k.startsWith('hinge')),
          containsAll(was.keys.where((k) => !k.startsWith('hinge'))),
        );
      });
    }

    test(
      'a line drawn across a pane makes two panes of what that pane was',
      () {
        final c = _workspaceWith(_dressed());
        final d = c.read(workspaceProvider).design;
        final opening = d.openingsInOrder.first;
        final (frosted, _) = _panesOf(d, opening);
        expect(frosted!.finish, GlassLook.frosted.finish);
        final box = frosted.outline;
        c
            .read(workspaceProvider.notifier)
            .addLineInside(frosted.id, box.centroid, horizontal: false);
        final after = c.read(workspaceProvider).design;
        final halves = [
          for (final s in after.sections)
            if (box.contains(s.outline.centroid) &&
                after.childSectionsOf(s.id).isEmpty &&
                s.outline.area < box.area * 0.9)
              s,
        ];
        expect(halves, hasLength(2));
        for (final half in halves) {
          expect(half.finish, GlassLook.frosted.finish, reason: half.id);
        }
        // And every other part as it was.
        final was = _finishes(d), now = _finishes(after);
        for (final key in was.keys) {
          if (key.startsWith('${opening.id} upper')) continue;
          expect(now[key], was[key], reason: key);
        }
      },
    );
  });

  group('a change of material moves no geometry', () {
    final edits = <String, void Function(ProviderContainer)>{
      'a panel recoloured': (c) {
        final d = c.read(workspaceProvider).design;
        final (_, lower) = _panesOf(d, d.openingsInOrder.first);
        c
            .read(workspaceProvider.notifier)
            .setFinish(lower!.id, PanelColour.white.finish);
      },
      'a glass changed': (c) {
        final d = c.read(workspaceProvider).design;
        final (upper, _) = _panesOf(d, d.openingsInOrder[2]);
        c
            .read(workspaceProvider.notifier)
            .setFinish(upper!.id, GlassLook.blueGrey.finish);
      },
      'the frame recoloured': (c) {
        final d = c.read(workspaceProvider).design;
        c
            .read(workspaceProvider.notifier)
            .setFinish(
              d.frame!.id,
              d.frame!.finish.copyWith(colour: 0xFFF2F2F0),
            );
      },
      'a handle recoloured': (c) {
        final d = c.read(workspaceProvider).design;
        final handle = d.hardware.firstWhere((h) => h.kind.isHandle);
        c
            .read(workspaceProvider.notifier)
            .setFinish(
              handle.id,
              handle.finish.copyWith(colour: HardwareColour.silver.colour),
            );
      },
    };
    for (final MapEntry(key: what, value: edit) in edits.entries) {
      test(what, () {
        final c = _workspaceWith(_dressed());
        final before = c.read(workspaceProvider).design;
        edit(c);
        final after = c.read(workspaceProvider).design;
        expect(_finishes(after), isNot(_finishes(before)));
        expect(_geometry(after), _geometry(before));
      });
    }
  });

  group('looking is not editing, and does no work but the looking', () {
    test('only an edit is new work; a way of looking keeps the work', () {
      final c = _workspaceWith(_dressed());
      final controller = c.read(workspaceProvider.notifier);
      Object work() => c.read(workspaceProvider).work;

      final looks = <String, void Function()>{
        'orbit': () => controller.orbit(12, -4),
        'pan': () => controller.panCamera(30, 10),
        'zoom': () => controller.zoomCamera(1.2),
        'projection': () => controller.setProjection(Projection.parallel),
        'named view': () => controller.lookFrom(Camera.front),
        'reset': controller.zoomExtents,
        'framed': () => controller.frame(Camera.isometric, what: 'here'),
        'swing': () => controller.setOpenFraction(0.4),
        'display style': () =>
            controller.setDisplayStyle(DisplayStyle.wireframe),
        'floor': () => controller.setGroundPlane(false),
      };
      for (final MapEntry(key: what, value: look) in looks.entries) {
        final was = work();
        final design = c.read(workspaceProvider).design;
        look();
        expect(identical(work(), was), isTrue, reason: what);
        expect(
          identical(c.read(workspaceProvider).design, design),
          isTrue,
          reason: what,
        );
      }

      final d = c.read(workspaceProvider).design;
      final changes = <String, void Function()>{
        'an edit': () => controller.setDepth(95),
        'a selection': () => controller.select(d.openings.first.id),
        'a tool': () => controller.useTool(Tool.line),
        'a view': () => controller.showView(WorkspaceView.plan),
        'undo': controller.undo,
      };
      for (final MapEntry(key: what, value: change) in changes.entries) {
        final was = work();
        change();
        expect(identical(work(), was), isFalse, reason: what);
      }
    });

    testWidgets('turning the model and playing its swing rebuild the model '
        'view alone, and build the solid once', (tester) async {
      await every.keepAdam();
      final c = await screen.openTheApp(tester, size: every.laptop);
      await _openBasementDoor(tester);
      await every.showView(tester, WorkspaceView.model);
      await tester.pumpAndSettle();

      // Every rebuild of the widgets that show the work, counted.
      final built = <Type, int>{};
      final watched = {
        WorkspaceScreen,
        InspectorPanel,
        ComponentTree,
        ToolBar,
        ModelView,
      };
      widgets.debugOnRebuildDirtyWidget = (element, builtOnce) {
        final type = element.widget.runtimeType;
        if (watched.contains(type)) built[type] = (built[type] ?? 0) + 1;
      };
      addTearDown(() => widgets.debugOnRebuildDirtyWidget = null);

      final shownBefore = every.painterOf<ModelPainter>(tester);
      final solidBefore = _sources(shownBefore);

      // Turn it, as a hand does: a drag of twenty moves.
      final view = find.byType(ModelView);
      final gesture = await tester.startGesture(tester.getCenter(view));
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(const Offset(6, 1));
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();

      // The model turned, and is the same solid: built once, not once a
      // move — the painter's faces are the very facets it had before.
      final turned = every.painterOf<ModelPainter>(tester);
      expect(every.facets(turned), isNot(every.facets(shownBefore)));
      expect(_sources(turned).length, solidBefore.length);
      expect(
        _sources(turned).every(solidBefore.contains),
        isTrue,
        reason: 'the solid was built again for a way of looking',
      );

      // And swing its leaves — which does change the solid, and so builds
      // it again — and look at it another way.
      final controller = c.read(workspaceProvider.notifier);
      for (final f in [0.2, 0.4, 0.6, 0.4, 0.0]) {
        controller.setOpenFraction(f);
        await tester.pump();
      }
      controller.setDisplayStyle(DisplayStyle.shaded);
      await tester.pump();

      expect(
        built[ModelView] ?? 0,
        greaterThan(20),
        reason: 'the model view follows every move',
      );
      for (final type in watched.difference({ModelView})) {
        expect(built[type] ?? 0, 0, reason: '$type was rebuilt');
      }
      final solidShut = _sources(every.painterOf<ModelPainter>(tester));

      // An edit is new work: the solid is built again, from the new design.
      built.clear();
      final pane = c
          .read(workspaceProvider)
          .design
          .sections
          .firstWhere((s) => s.finish.material.isGlazing);
      controller.setFinish(pane.id, PanelColour.brown.finish);
      await tester.pump();
      expect(built[InspectorPanel] ?? 0, greaterThan(0));
      final edited = every.painterOf<ModelPainter>(tester);
      expect(_sources(edited).any(solidShut.contains), isFalse);
      expect(
        every.facets(edited),
        every.projected(c, c.read(workspaceProvider).design),
      );
    });
  });

  group('every edit shows at once in the view that is on the screen', () {
    // The edits the brief names, as the user makes them.
    final edits = <String, void Function(ProviderContainer)>{
      'width': (c) => c
          .read(workspaceProvider.notifier)
          .resizeFrame(
            widthMm:
                c.read(workspaceProvider).design.frame!.outline.width + 200,
          ),
      'height': (c) => c
          .read(workspaceProvider.notifier)
          .resizeFrame(
            heightMm:
                c.read(workspaceProvider).design.frame!.outline.height - 150,
          ),
      'divider moved': (c) {
        final d = c.read(workspaceProvider).design;
        final bar = d.dividers.firstWhere(
          (b) => d.openingHolding(b.parentId) != null,
        );
        c
            .read(workspaceProvider.notifier)
            .moveDividerWithin(bar.id, DesignEdits.alongWithin(d, bar)! - 120);
      },
      'opening changed': (c) {
        final d = c.read(workspaceProvider).design;
        c
            .read(workspaceProvider.notifier)
            .setOpeningSwing(d.openings.single.id, OpeningDirection.outward);
      },
      'panel colour': (c) {
        final d = c.read(workspaceProvider).design;
        final panel = d.sections.firstWhere(
          (s) =>
              !s.finish.material.isGlazing && d.childSectionsOf(s.id).isEmpty,
        );
        c
            .read(workspaceProvider.notifier)
            .setFinish(panel.id, PanelColour.black.finish);
      },
      'glass type': (c) {
        final d = c.read(workspaceProvider).design;
        final glass = d.sections.firstWhere(
          (s) => s.finish.material.isGlazing && d.childSectionsOf(s.id).isEmpty,
        );
        c
            .read(workspaceProvider.notifier)
            .setFinish(glass.id, GlassLook.dark.finish);
      },
      'a hinge added': (c) => c
          .read(workspaceProvider.notifier)
          .setOpeningHardware(
            c.read(workspaceProvider).design.openings.single.id,
            hingeCount: 4,
          ),
      'a hinge taken away': (c) => c
          .read(workspaceProvider.notifier)
          .setOpeningHardware(
            c.read(workspaceProvider).design.openings.single.id,
            hingeCount: 2,
          ),
      'a line added inside a pane': (c) {
        final d = c.read(workspaceProvider).design;
        final opening = d.openings.single;
        final pane = d.childSectionsOf(opening.sectionId).first;
        c
            .read(workspaceProvider.notifier)
            .addLineInside(pane.id, pane.outline.centroid, horizontal: false);
      },
      'that line deleted': (c) {
        final d = c.read(workspaceProvider).design;
        final newest = d.dividers.last;
        c.read(workspaceProvider.notifier)
          ..select(newest.id)
          ..deleteSelected();
      },
    };

    for (final shown in [
      WorkspaceView.draw,
      WorkspaceView.plan,
      WorkspaceView.model,
    ]) {
      testWidgets('with ${shown.name} on the screen', (tester) async {
        await every.keepAdam();
        final c = await screen.openTheApp(tester, size: every.laptop);
        await _openBasementDoor(tester);
        await every.showView(tester, shown);

        for (final MapEntry(key: what, value: edit) in edits.entries) {
          final before = c.read(workspaceProvider).design;
          edit(c);
          await tester.pump();
          final after = c.read(workspaceProvider).design;
          expect(identical(after, before), isFalse, reason: what);
          switch (shown) {
            case WorkspaceView.draw:
              expect(
                identical(every.painterOf<DesignPainter>(tester).design, after),
                isTrue,
                reason: what,
              );
            case WorkspaceView.plan:
              expect(
                identical(every.painterOf<CadPainter>(tester).design, after),
                isTrue,
                reason: what,
              );
            case WorkspaceView.model:
              final painter = every.painterOf<ModelPainter>(tester);
              expect(
                every.facets(painter),
                every.projected(c, after),
                reason: what,
              );
          }
        }
        // Put away the sizes form if an edit raised it, and leave.
        await tester.pumpAndSettle();
      });
    }
  });
}

/// The facets a painter is showing, as the objects they are.
Set<Facet> _sources(ModelPainter painter) =>
    Set<Facet>.identity()..addAll([for (final f in painter.faces) f.source]);

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
