import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/state/tools.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/hardware/opening_hardware.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_tree.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

// The final acceptance test: one design, three openings, both kinds.
//
//   Design
//   ├── Fixed area
//   ├── Opening 1  — Window   glass over panel
//   ├── Opening 2  — Door     glass over panel
//   ├── Fixed area
//   └── Opening 3  — Window   its own design: four panes
//
// The seventeen claims of the brief are the seventeen tests below, in its
// own order and under its own numbers, so the file can be read against it
// line by line.
//
// It is built the way the user builds it: the sheet is drawn stroke by
// stroke through the workspace, the drawing is read, the application asks
// what each new opening is, the answers are given, and the inside of each
// leaf is drawn afterwards.

ProviderContainer container() {
  final made = ProviderContainer();
  addTearDown(made.dispose);
  return made;
}

List<StrokeSample> inked(List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 30; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 30)));
    }
  }
  return [...samples, StrokeSample(through.last)];
}

List<Vec2> chevron(Vec2 at, {double size = 110}) => [
      Vec2(at.x - size / 2, at.y - size),
      Vec2(at.x + size / 2, at.y),
      Vec2(at.x - size / 2, at.y + size),
    ];

const _glass = Finish(colour: 0xFFD8E6EA, material: MaterialKind.clearGlass);
const _panel = Finish(colour: 0xFF7B4A2B, material: MaterialKind.panel);

/// Five lights; the 2nd, 3rd and 5th marked to open.
///
/// Drawn on the sheet and read, exactly as the user does it. Nothing is
/// answered yet: that is what tests 3 and 4 are about.
WorkspaceController drawn() {
  final controller = container().read(workspaceProvider.notifier)
    ..startDesign(DesignKind.window);

  controller.addStroke(
    inked(const [
      Vec2(0, 0),
      Vec2(6000, 0),
      Vec2(6000, 2200),
      Vec2(0, 2200),
      Vec2(0, 0),
    ]),
    tool: Tool.pen,
  );
  for (var i = 1; i < 5; i++) {
    controller.addStroke(
      inked([Vec2(i * 1200, 0), Vec2(i * 1200, 2200)]),
      tool: Tool.pen,
    );
  }
  for (final at in const [Vec2(1800, 1100), Vec2(3000, 1100), Vec2(5400, 1100)]) {
    controller.addStroke(inked(chevron(at)), tool: Tool.pen);
  }
  controller.readDrawing();
  return controller;
}

/// The design with each leaf answered for and its own inside drawn.
///
/// Opening 1 — window, glass over panel.
/// Opening 2 — door, glass over panel.
/// Opening 3 — window, its own design: a line across and a line up, four
/// panes, the lower two panels.
WorkspaceController built() {
  final controller = drawn();
  final kinds = [DesignKind.window, DesignKind.door, DesignKind.window];

  final openings = [...controller.state.design.openingsInOrder];
  for (var i = 0; i < openings.length; i++) {
    controller.answer(
      WorkspaceState.openingKindQuestion(openings[i].id),
      kinds[i].name,
    );
  }

  var design = controller.state.design;
  final order = [...design.openingsInOrder];
  for (var i = 0; i < order.length; i++) {
    final section = order[i].sectionId;
    final box = design.sectionById(section)!.outline;

    design = DesignEdits.addLineInside(design, section,
        id: 'across-$i',
        at: Vec2(box.centroid.x, box.top + box.height * 0.45),
        horizontal: true);

    // The third leaf gets a design of its own.
    if (i == 2) {
      design = DesignEdits.addLineInside(design, section,
          id: 'up-$i', at: Vec2(box.centroid.x, box.centroid.y),
          horizontal: false);
    }

    for (final pane in design.childSectionsOf(section)) {
      final low = pane.outline.centroid.y > box.centroid.y;
      design = design.withElement(pane.copyWith(finish: low ? _panel : _glass));
    }
  }
  controller.state = controller.state.copyWith(design: design);
  return controller;
}

Design theDesign() => built().state.design;

List<HardwareElement> hardwareOf(Design design, String openingId) => [
      for (final piece in design.hardware)
        if (design.openingHolding(piece.parentId)?.id == openingId) piece,
    ];

String placesIn(Design design, String openingId) => [
      for (final piece in hardwareOf(design, openingId))
        '${piece.id}:${piece.at}',
    ].join('|');

List<Vec3> cornersOf(Mesh mesh, String elementId) => [
      for (final facet in mesh.facets)
        if (facet.elementId == elementId) ...facet.corners,
    ];

void main() {
  test('the design is the one the brief describes', () {
    final design = theDesign();
    expect(design.topLevelSections, hasLength(5));
    expect(design.openings, hasLength(3));
    expect([for (final o in design.openingsInOrder) design.kindOf(o)],
        [DesignKind.window, DesignKind.door, DesignKind.window]);
  });

  test('1 — each opening is independent', () {
    final design = theDesign();
    final order = design.openingsInOrder;

    // Three openings, three sections, three sets of contents, nothing shared.
    expect({for (final o in order) o.id}, hasLength(3));
    expect({for (final o in order) o.sectionId}, hasLength(3));

    final contents = [
      for (final o in order) {for (final e in design.contentsOf(o)) e.id},
    ];
    for (var i = 0; i < contents.length; i++) {
      expect(contents[i], isNotEmpty);
      for (var j = i + 1; j < contents.length; j++) {
        expect(contents[i].intersection(contents[j]), isEmpty,
            reason: 'opening ${i + 1} and ${j + 1} share nothing');
      }
    }

    // And an edit to one is an edit to one.
    final was = {
      for (final o in order)
        o.id: design.childSectionsOf(o.sectionId).length,
    };
    final after = DesignEdits.setOpeningMechanism(
        design, order[1].id, OpeningMechanism.topHung);
    expect(after.openingById(order[1].id)!.mechanism,
        OpeningMechanism.topHung);
    for (final o in [order[0], order[2]]) {
      expect(after.openingById(o.id)!.mechanism, o.mechanism);
      expect(after.childSectionsOf(o.sectionId).length, was[o.id]);
    }
  });

  test('2 — each opening has its own Door/Window type', () {
    final design = theDesign();
    final order = design.openingsInOrder;

    expect(order[0].kind, DesignKind.window);
    expect(order[1].kind, DesignKind.door);
    expect(order[2].kind, DesignKind.window);

    // Written on the opening, not on the design: one design holds both.
    expect(design.kind, DesignKind.window);
    expect(design.kindOf(order[1]), DesignKind.door,
        reason: 'a door leaf in a window assembly stays a door');
  });

  test('3 — the question is asked only when the opening is created', () {
    final controller = drawn();
    Set<String> asking() => {
          for (final q in controller.state.allQuestions)
            if (q.id.startsWith('kind-')) q.id,
        };

    // Three new openings, three questions, one for each.
    expect(controller.state.design.openings, hasLength(3));
    expect(asking(), hasLength(3));
    for (final opening in controller.state.design.openingsInOrder) {
      expect(asking(), contains(WorkspaceState.openingKindQuestion(opening.id)));
    }

    // Answering takes each one away, and no new one appears.
    for (final opening in [...controller.state.design.openingsInOrder]) {
      controller.answer(
          WorkspaceState.openingKindQuestion(opening.id), 'window');
    }
    expect(asking(), isEmpty);
  });

  test('4 — the answer is saved on that opening', () {
    final design = theDesign();
    final order = design.openingsInOrder;

    // In the document, and back from it.
    final json = design.toJson();
    final openings = json['openings']! as List;
    expect(openings.map((o) => (o as Map)['kind']),
        containsAll(<Object?>['window', 'door']));

    final back = Design.fromJson(json);
    expect([for (final o in back.openingsInOrder) o.kind],
        [for (final o in order) o.kind]);
  });

  test('5 — the user can change the type later', () {
    final controller = built();
    final doorId = controller.state.design.openingsInOrder[1].id;

    controller.setOpeningKind(doorId, DesignKind.window);
    expect(controller.state.design.openingById(doorId)!.kind,
        DesignKind.window);

    controller.setOpeningKind(doorId, DesignKind.door);
    expect(controller.state.design.openingById(doorId)!.kind, DesignKind.door);

    // And no other leaf was touched by it.
    final others = controller.state.design.openingsInOrder;
    expect(others[0].kind, DesignKind.window);
    expect(others[2].kind, DesignKind.window);
  });

  test('6 — the door opening gets a real 3D door handle and hinges', () {
    final design = theDesign();
    final door = design.openingsInOrder[1];
    final mine = hardwareOf(design, door.id);

    expect({for (final p in mine) p.kind},
        {HardwareKind.hinge, HardwareKind.lever, HardwareKind.lock});

    final mesh = MeshBuilder.build(design);
    final lever = mine.firstWhere((p) => p.kind == HardwareKind.lever);
    final corners = cornersOf(mesh, lever.id);
    expect(corners, isNotEmpty);

    double spread(Iterable<double> of) =>
        of.reduce((a, b) => a > b ? a : b) -
        of.reduce((a, b) => a < b ? a : b);
    // Real in all three directions: it comes out of the leaf and turns
    // across it, which a flat tab cannot do.
    expect(spread(corners.map((c) => c.x)), greaterThan(40));
    expect(spread(corners.map((c) => c.y)), greaterThan(40));
    expect(spread(corners.map((c) => c.z)), greaterThan(20));

    for (final hinge in mine.where((p) => p.kind == HardwareKind.hinge)) {
      expect(cornersOf(mesh, hinge.id), isNotEmpty);
    }
  });

  test('7 — each window opening gets a real 3D window handle', () {
    final design = theDesign();
    final mesh = MeshBuilder.build(design);

    for (final index in [0, 2]) {
      final leaf = design.openingsInOrder[index];
      final mine = hardwareOf(design, leaf.id);
      expect({for (final p in mine) p.kind},
          {HardwareKind.hinge, HardwareKind.handle},
          reason: 'a window fastens and does not lock');

      final handle = mine.firstWhere((p) => p.kind.isHandle);
      final corners = cornersOf(mesh, handle.id);
      expect(corners, isNotEmpty);
      double spread(Iterable<double> of) =>
          of.reduce((a, b) => a > b ? a : b) -
          of.reduce((a, b) => a < b ? a : b);
      // Its arm hangs down the sash, so it is taller than it is wide.
      expect(spread(corners.map((c) => c.y)),
          greaterThan(spread(corners.map((c) => c.x))));
      expect(corners.map((c) => c.z).reduce((a, b) => a > b ? a : b),
          greaterThan(MeshBuilder.leafFront(design.depthMm)));
    }
  });

  test('8 — the handles are geometry, not pictures', () {
    final design = theDesign();
    final mesh = MeshBuilder.build(design);
    final parts = {for (final element in design.allElements) element.id};

    var hardwareFacets = 0;
    for (final facet in mesh.facets) {
      // Everything built is a part of this design. Nothing is drawn from a
      // file, a texture or a bundled asset — there are none.
      expect(parts, contains(facet.elementId));
      expect(facet.corners.length, greaterThanOrEqualTo(3));
      if (facet.role == FacetRole.hardware) hardwareFacets++;
    }
    expect(hardwareFacets, greaterThan(100),
        reason: 'the ironmongery is modelled, not stamped on');

    // A door's lever and a window's handle are different objects, told
    // apart by what they are built from rather than by their names.
    int facesOf(String id) => [
          for (final facet in mesh.facets)
            if (facet.elementId == id) facet,
        ].length;
    final lever = hardwareOf(design, design.openingsInOrder[1].id)
        .firstWhere((p) => p.kind.isHandle);
    final fastener = hardwareOf(design, design.openingsInOrder[0].id)
        .firstWhere((p) => p.kind.isHandle);
    expect(facesOf(lever.id), isNot(facesOf(fastener.id)));
  });

  test('9 — handle colours and materials are editable, and last', () {
    final design = theDesign();
    final door = design.openingsInOrder[1];
    final handle = hardwareOf(design, door.id).firstWhere((p) => p.kind.isHandle);

    const bronze = Finish(
      colour: 0xFF8C6A3F,
      material: MaterialKind.aluminium,
    );
    expect(HardwareColour.of(bronze.colour), HardwareColour.bronze);

    final painted = OpeningHardware.settle(
        design.withElement(handle.copyWith(finish: bronze)));
    final now =
        painted.hardware.firstWhere((p) => p.id == handle.id);
    expect(now.finish.colour, bronze.colour);
    expect(now.finish.material, MaterialKind.aluminium);

    // The solid builds it in that finish.
    final built = {
      for (final facet in MeshBuilder.build(painted).facets)
        if (facet.elementId == handle.id) facet.colour,
    };
    expect(built, isNotEmpty);
    for (final colour in built) {
      expect((colour >> 16) & 0xFF, greaterThan((colour >> 8) & 0xFF),
          reason: 'bronze is warmer than it is green');
    }

    // And it is not thrown away by the next edit.
    final after = DesignEdits.moveDivider(
        painted, painted.topLevelDividers.first.id, const Vec2(-90, 0));
    expect(after.hardware.firstWhere((p) => p.id == handle.id).finish.colour,
        bronze.colour);
  });

  test('10 — hardware belongs to its specific opening', () {
    final design = theDesign();

    expect(design.hardware.where((p) => p.parentId == null), isEmpty);
    for (final piece in design.hardware) {
      final opening = design.openingHolding(piece.parentId);
      expect(opening, isNotNull);
      expect(piece.parentId, isNot(design.frame!.id));
    }

    final sets = [
      for (final o in design.openingsInOrder)
        {for (final p in hardwareOf(design, o.id)) p.id},
    ];
    for (var i = 0; i < sets.length; i++) {
      expect(sets[i], isNotEmpty);
      for (var j = i + 1; j < sets.length; j++) {
        expect(sets[i].intersection(sets[j]), isEmpty);
      }
    }
  });

  test('11 — moving one opening does not move the others', () {
    final before = theDesign();
    final order = before.openingsInOrder;
    final ids = [for (final o in order) o.id];

    // The bar on the third leaf's own side, which the other two do not
    // touch. A bar shared by two leaves bounds both, and moving it moves
    // both — rightly.
    final bar = before.topLevelDividers
        .firstWhere((b) => b.segment.midpoint.x > 4500);
    final was = {for (final id in ids) id: placesIn(before, id)};

    final after = DesignEdits.moveDivider(before, bar.id, const Vec2(-240, 0));

    expect(placesIn(after, ids[2]), isNot(was[ids[2]]),
        reason: 'the leaf that was moved');
    expect(placesIn(after, ids[0]), was[ids[0]]);
    expect(placesIn(after, ids[1]), was[ids[1]]);
    for (final id in [ids[0], ids[1]]) {
      expect(after.sectionById(after.openingById(id)!.sectionId)!
          .outline.corners,
          before.sectionById(before.openingById(id)!.sectionId)!
              .outline.corners);
    }
  });

  test('12 — internal lines stay inside their own opening', () {
    final design = theDesign();

    for (final opening in design.openingsInOrder) {
      final box = design.sectionById(opening.sectionId)!.outline;
      final bars = design.childDividersOf(opening.sectionId);
      expect(bars, isNotEmpty);

      for (final bar in bars) {
        expect(design.openingHolding(bar.parentId)?.id, opening.id);
        expect(box.holds(bar.segment, reach: DesignEdits.reachFor(bar)),
            isTrue);
      }
      for (final pane in design.childSectionsOf(opening.sectionId)) {
        expect(design.openingHolding(pane.parentId)?.id, opening.id);
      }
    }

    // Opening 1 and 2: glass over panel. Opening 3: its own design.
    final order = design.openingsInOrder;
    expect(design.childSectionsOf(order[0].sectionId), hasLength(2));
    expect(design.childSectionsOf(order[1].sectionId), hasLength(2));
    expect(design.childDividersOf(order[2].sectionId), hasLength(2));
    expect(design.childSectionsOf(order[2].sectionId), hasLength(4));

    for (final index in [0, 1]) {
      final panes = design.childSectionsOf(order[index].sectionId);
      final upper = panes.reduce((a, b) => a.outline.top < b.outline.top ? a : b);
      final lower = panes.reduce((a, b) => a.outline.top > b.outline.top ? a : b);
      expect(upper.finish.material.isGlazing, isTrue, reason: 'upper = glass');
      expect(lower.finish.material, MaterialKind.panel,
          reason: 'lower = panel');
    }
  });

  test('13 — internal lines never become global lines', () {
    final design = theDesign();

    // The four mullions the user drew, and nothing else.
    expect(design.topLevelDividers, hasLength(4));
    for (final bar in design.topLevelDividers) {
      expect(bar.parentId, isNull);
      expect(bar.id, isNot(startsWith('across-')));
      expect(bar.id, isNot(startsWith('up-')));
    }
    expect(design.topLevelSections, hasLength(5));

    // Four lines were drawn inside leaves; all four are still inside one.
    final inside = [
      for (final bar in design.dividers)
        if (bar.parentId != null) bar,
    ];
    expect(inside, hasLength(4));
    for (final bar in inside) {
      expect(design.openingHolding(bar.parentId), isNotNull);
    }
  });

  test('14 — fixed sections remain fixed', () {
    final design = theDesign();
    final fixed = [
      for (final section in design.topLevelSections)
        if (design.openingOf(section.id) == null) section,
    ];
    expect(fixed, hasLength(2));

    for (final section in fixed) {
      expect(design.hasChildren(section.id), isFalse);
      for (final piece in design.hardware) {
        expect(design.sectionHolding(piece.parentId), isNot(section.id));
      }
    }

    // And nothing of them moves, however far the leaves are swung.
    final leaves = {
      for (final opening in design.openings) ...{
        opening.sectionId,
        for (final element in design.contentsOf(opening)) element.id,
      },
    };
    String elsewhere(double open) => [
          for (final facet
              in MeshBuilder.build(design, openFraction: open).facets)
            if (!leaves.contains(facet.elementId))
              '${facet.elementId}:${facet.corners.join(',')}',
        ].join('|');

    final shut = elsewhere(0);
    expect(shut, isNotEmpty);
    for (final angle in [0.25, 0.5, 0.75, 1.0]) {
      expect(elsewhere(angle), shut, reason: 'at $angle');
    }
  });

  test('15 — the drawing and the solid use the same geometry', () {
    final design = theDesign();
    final tree = DesignTree.of(design);

    final onTheSheet = <String>{
      design.frame!.id,
      ...tree.barIds,
      for (final section in tree.fixedSections) section.sectionId,
      for (final branch in tree.openings) ...{
        branch.sectionId,
        ...branch.barIds,
        for (final pane in branch.panes) pane.sectionId,
      },
      for (final piece in design.hardware) piece.id,
    };
    final inTheModel = {
      for (final facet in MeshBuilder.build(design).facets) facet.elementId,
    };

    expect(inTheModel.difference(onTheSheet), isEmpty,
        reason: 'the solid builds nothing the drawing does not have');
    for (final branch in tree.openings) {
      expect(inTheModel, contains(branch.sectionId));
      for (final pane in branch.panes) {
        expect(inTheModel, contains(pane.sectionId));
      }
      for (final bar in branch.barIds) {
        expect(inTheModel, contains(bar));
      }
    }

    // And the model is a function of the design: same design, same mesh.
    String mesh(Design of) => [
          for (final facet in MeshBuilder.build(of).facets)
            '${facet.elementId}:${facet.corners.join(',')}',
        ].join('|');
    expect(mesh(design), mesh(Design.fromJson(design.toJson())));
  });

  test('16 — nothing random is introduced', () {
    final design = theDesign();
    final parts = {for (final element in design.allElements) element.id};

    for (final facet in MeshBuilder.build(design).facets) {
      expect(parts, contains(facet.elementId));
    }

    // The counts are exactly what the drawing and the edits made.
    expect(design.dividers, hasLength(8), reason: '4 mullions + 4 inside');
    expect(design.sections, hasLength(13), reason: '5 lights + 2 + 2 + 4');
    expect(design.hardware.where((p) => p.parentId == null), isEmpty);

    // No stock content anywhere: `test/no_stock_content_test.dart` scans
    // the repository for that, and this is its counterpart on one design.
    expect(design.sketch.strokes, isNotEmpty,
        reason: 'the user’s own ink is what everything came from');
  });

  test('17 — no question is ever asked twice', () {
    final controller = built();
    Set<String> asking() => {
          for (final q in controller.state.allQuestions)
            if (q.id.startsWith('kind-')) q.id,
        };
    expect(asking(), isEmpty);

    // Reading the sheet again.
    controller.readDrawing();
    expect(asking(), isEmpty);

    // Switching between the views.
    controller
      ..showView(WorkspaceView.model)
      ..showView(WorkspaceView.plan)
      ..showView(WorkspaceView.draw);
    expect(asking(), isEmpty);

    // Drawing another line inside a leaf.
    final leaf = controller.state.design.openingsInOrder.first;
    final box = controller.state.design.sectionById(leaf.sectionId)!.outline;
    controller.state = controller.state.copyWith(
      design: DesignEdits.addLineInside(
        controller.state.design,
        leaf.sectionId,
        id: 'one-more',
        at: Vec2(box.centroid.x, box.top + box.height * 0.8),
        horizontal: true,
      ),
    );
    expect(asking(), isEmpty);

    // And opening the design again tomorrow.
    final tomorrow = container().read(workspaceProvider.notifier)
      ..startDesign(DesignKind.window);
    tomorrow.state = tomorrow.state.copyWith(
      design: Design.fromJson(controller.state.design.toJson()),
    );
    expect({
      for (final q in tomorrow.state.allQuestions)
        if (q.id.startsWith('kind-')) q.id,
    }, isEmpty);
  });
}
