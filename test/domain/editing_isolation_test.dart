import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/sections/section_builder.dart';

/// A design with something of every kind in it, all deliberately unequal, so
/// any change that spreads shows up.
Design everything() {
  final at = DateTime(2026);
  var design = SectionBuilder.rebuild(Design(
    id: 'd',
    name: 'test',
    kind: DesignKind.door,
    createdAt: at,
    updatedAt: at,
    frame: FrameElement(
      id: 'frame',
      outline: Polygon.rect(0, 0, 1800, 2200),
      profileMm: 60,
    ),
    dividers: const [
      DividerElement(id: 'v', a: Vec2(520, 0), b: Vec2(520, 2200), widthMm: 50),
      DividerElement(
        id: 'h',
        a: Vec2(520, 1400),
        b: Vec2(1800, 1400),
        widthMm: 45,
      ),
    ],
    hardware: const [
      HardwareElement(id: 'lever', kind: HardwareKind.lever, at: Vec2(1650, 1100)),
      HardwareElement(id: 'hinge', kind: HardwareKind.hinge, at: Vec2(70, 400)),
    ],
    dimensions: const [
      DimensionElement(id: 'dim', a: Vec2(0, 2200), b: Vec2(520, 2200)),
    ],
    texts: const [
      TextElement(id: 'note', text: 'Toughened', at: Vec2(900, 300)),
    ],
    arrows: const [
      ArrowElement(id: 'arrow', from: Vec2(950, 380), to: Vec2(1100, 500)),
    ],
  ));

  final tall = design.sections
      .reduce((a, b) => a.heightMm > b.heightMm ? a : b);
  design = design.withElement(tall.copyWith(
    finish: const Finish(colour: 0xFF7B4A2B, material: MaterialKind.panel),
  ));
  return DesignEdits.setOpening(
    design,
    tall.id,
    openingId: 'o',
    mechanism: OpeningMechanism.hingedLeft,
    markAt: tall.outline.centroid,
    markGlyph: '>',
  );
}

/// Everything about an element that an unrelated edit must not touch.
String fingerprint(Design design, String elementId) {
  final element = design.elementById(elementId);
  return switch (element) {
    null => 'gone',
    FrameElement() => '${element.outline.corners}|${element.profileMm}'
        '|${element.finish.colour}|${element.finish.material}',
    DividerElement() => '${element.a}|${element.b}|${element.widthMm}'
        '|${element.finish.colour}',
    SectionElement() => '${element.outline.corners}'
        '|${element.finish.colour}|${element.finish.material}',
    OpeningElement() => '${element.sectionId}|${element.mechanism}'
        '|${element.direction}|${element.markGlyph}',
    HardwareElement() => '${element.at}|${element.kind}|${element.rotation}',
    DimensionElement() =>
      '${element.a}|${element.b}|${element.offsetMm}|${element.statedMm}',
    TextElement() => '${element.at}|${element.text}|${element.sizeMm}',
    ArrowElement() => '${element.from}|${element.to}',
    FrameMemberElement() => '${element.run.a}|${element.run.b}',
  };
}

Map<String, String> everythingExcept(Design design, Set<String> ignore) => {
      for (final element in design.allElements)
        if (!ignore.contains(element.id))
          element.id: fingerprint(design, element.id),
    };

void main() {
  group('every kind of element can be picked out of the drawing', () {
    test('the frame, its sides, the bars, the panes and the rest', () {
      final design = everything();
      final labels = {for (final e in design.allElements) e.label};

      expect(labels, contains('Frame'));
      expect(labels, contains('Head'));
      expect(labels, contains('Sill'));
      expect(labels, contains('Left jamb'));
      expect(labels, contains('Right jamb'));
      expect(labels, contains('Vertical divider'));
      expect(labels, contains('Horizontal divider'));
      expect(labels, contains('Section'));
      expect(labels, contains('Lever'));
      expect(labels, contains('Hinge'));
      expect(labels, contains('Toughened'));
      expect(labels, contains('Arrow'));
      expect(labels.any((l) => l.startsWith('Hinged left')), isTrue);
      expect(labels.any((l) => l.endsWith('mm')), isTrue);
    });

    test('tapping the frame picks the side you tapped', () {
      final design = everything();
      final head = DesignEdits.hitTest(design, const Vec2(900, 10), slopMm: 20);
      expect(head, isA<FrameMemberElement>());
      expect(head!.label, 'Head');

      final jamb = DesignEdits.hitTest(design, const Vec2(10, 900), slopMm: 20);
      expect(jamb!.label, 'Left jamb');

      final sill =
          DesignEdits.hitTest(design, const Vec2(900, 2190), slopMm: 20);
      expect(sill!.label, 'Sill');
    });

    test('every element in the drawing can be found by its own id', () {
      final design = everything();
      for (final element in design.allElements) {
        expect(design.elementById(element.id), isNotNull,
            reason: '${element.label} should be findable');
      }
    });
  });

  group('dragging a boundary and typing a size agree', () {
    test('a bar dragged across matches the width typed for its section', () {
      final base = everything();
      final left = base.sections
          .reduce((a, b) => a.outline.left < b.outline.left ? a : b);

      // Typed: make the left pane 800 wide.
      final typed = DesignEdits.setSectionWidth(base, left.id, 800);
      final typedBar = typed.dividers.firstWhere((d) => d.id == 'v');

      // Dragged: take hold of the boundary and put it where that leaves it.
      final dragged = DesignEdits.moveDividerAcross(
        base,
        'v',
        Vec2(typedBar.segment.midpoint.x, 1100),
      );

      final draggedLeft = dragged.sections
          .reduce((a, b) => a.outline.left < b.outline.left ? a : b);
      expect(draggedLeft.widthMm, closeTo(800, 1));
      expect(
        dragged.dividers.firstWhere((d) => d.id == 'v').segment.midpoint.x,
        closeTo(typedBar.segment.midpoint.x, 0.01),
      );
    });

    test('a frame side dragged matches the overall width typed', () {
      final base = everything();

      final typed = DesignEdits.moveFrameEdge(base, FrameEdge.right, 2000);

      // The right jamb is the member whose midpoint is furthest right.
      final jamb = base.frameMembers
          .reduce((a, b) => a.run.midpoint.x > b.run.midpoint.x ? a : b);
      final dragged = DesignEdits.moveFrameMember(
        base,
        jamb.index,
        DesignEdits.frameMemberOffset(base, jamb.index, const Vec2(2000, 1100)),
      );

      expect(typed.frame!.outline.right, closeTo(2000, 0.01));
      expect(dragged.frame!.outline.right, closeTo(2000, 0.01));
      expect(dragged.sections.length, typed.sections.length);
    });

    test('a bar only moves across itself, never along', () {
      final base = everything();
      final before = base.dividers.firstWhere((d) => d.id == 'v');

      // A drag straight down the bar's own length.
      final after = DesignEdits.moveDividerAcross(
        base,
        'v',
        Vec2(before.segment.midpoint.x, before.segment.midpoint.y + 600),
      );
      final moved = after.dividers.firstWhere((d) => d.id == 'v');
      expect(moved.a.x, closeTo(before.a.x, 0.01));
      expect(moved.a.y, closeTo(before.a.y, 0.01));
    });
  });

  group('an edit touches only what it names', () {
    test('moving a bar leaves the other bar, the notes and the rest alone', () {
      final before = everything();
      // Sections, the opening's mark and the opening's own ironmongery
      // follow the bars by construction, so they are the ones legitimately
      // allowed to move. A handle that stayed put while the leaf it is on
      // changed size would be the bug.
      final untouched = {
        'v',
        for (final s in before.sections) s.id,
        'o',
        for (final h in before.hardware)
          if (h.isOpeningHardware) h.id,
      };
      final was = everythingExcept(before, untouched);

      final after = DesignEdits.moveDividerAcross(before, 'v', const Vec2(760, 1100));

      expect(after.dividers.firstWhere((d) => d.id == 'v').a.x,
          closeTo(760, 0.01));
      expect(everythingExcept(after, untouched), was);
    });

    test('recolouring one pane leaves every other element identical', () {
      final before = everything();
      final target = before.sections.first;
      final was = everythingExcept(before, {target.id});

      final after = before.withElement(target.copyWith(
        finish: const Finish(colour: 0xFF8C1E20, material: MaterialKind.louvre),
      ));

      expect(after.sectionById(target.id)!.finish.colour, 0xFF8C1E20);
      expect(everythingExcept(after, {target.id}), was);
    });

    test('moving a handle moves that handle and nothing else', () {
      final before = everything();
      final was = everythingExcept(before, {'lever'});

      final after =
          DesignEdits.moveHardware(before, 'lever', const Vec2(1700, 900));

      expect(after.elementById('lever')!.anchor, const Vec2(1700, 900));
      expect(everythingExcept(after, {'lever'}), was);
    });

    test('moving a dimension end changes that dimension only', () {
      final before = everything();
      final was = everythingExcept(before, {'dim'});

      final after = DesignEdits.moveDimensionEnd(
        before,
        'dim',
        const Vec2(700, 2200),
        startEnd: false,
      );

      final dimension = after.elementById('dim')! as DimensionElement;
      expect(dimension.b.x, 700);
      expect(dimension.a, const Vec2(0, 2200));
      expect(everythingExcept(after, {'dim'}), was);
    });

    test('sliding a dimension off the work does not change what it measures',
        () {
      final before = everything();
      final was = everythingExcept(before, {'dim'});

      final after =
          DesignEdits.setDimensionOffset(before, 'dim', const Vec2(260, 2400));

      final dimension = after.elementById('dim')! as DimensionElement;
      expect(dimension.measuredMm, closeTo(520, 0.01));
      expect(dimension.offsetMm.abs(), greaterThan(100));
      expect(everythingExcept(after, {'dim'}), was);
    });

    test('moving a note moves the note, not the arrow beside it', () {
      final before = everything();
      final was = everythingExcept(before, {'note'});

      final after =
          DesignEdits.dragElement(before, 'note', const Vec2(40, -60));

      expect(after.elementById('note')!.anchor, const Vec2(940, 240));
      expect(everythingExcept(after, {'note'}), was);
    });

    test('changing the bar width changes that bar and the panes it makes', () {
      final before = everything();
      final untouched = {
        'v',
        for (final s in before.sections) s.id,
        'o',
        for (final h in before.hardware)
          if (h.isOpeningHardware) h.id,
      };
      final was = everythingExcept(before, untouched);

      final bar = before.dividers.firstWhere((d) => d.id == 'v');
      final after = SectionBuilder.rebuild(
        before.withElement(bar.copyWith(widthMm: 120)),
      );

      expect(after.dividers.firstWhere((d) => d.id == 'v').widthMm, 120);
      // The other bar did not change thickness to match.
      expect(after.dividers.firstWhere((d) => d.id == 'h').widthMm, 45);
      expect(everythingExcept(after, untouched), was);
    });
  });

  group('moving one side of the frame', () {
    test('moves that side and leaves the others where they were', () {
      final before = everything();
      final head = before.frameMembers.firstWhere((m) => m.label == 'Head');

      // Positive is outward, away from the middle: the head moves up.
      final after = DesignEdits.moveFrameMember(before, head.index, 200);

      expect(after.frame!.outline.top, closeTo(-200, 0.01));
      expect(after.frame!.outline.bottom, closeTo(2200, 0.01));
      expect(after.frame!.outline.left, closeTo(0, 0.01));
      expect(after.frame!.outline.right, closeTo(1800, 0.01));
      // The bars stayed where they were put; only the frame moved.
      expect(after.dividers.firstWhere((d) => d.id == 'v').a.x,
          closeTo(520, 0.01));
    });

    test('a raking side of a five-sided frame moves square to itself', () {
      final at = DateTime(2026);
      final design = SectionBuilder.rebuild(Design(
        id: 'd',
        name: 'x',
        kind: DesignKind.window,
        createdAt: at,
        updatedAt: at,
        frame: FrameElement(
          id: 'f',
          outline: const Polygon([
            Vec2(0, 400),
            Vec2(600, 0),
            Vec2(1200, 400),
            Vec2(1200, 1800),
            Vec2(0, 1800),
          ]),
          profileMm: 50,
        ),
      ));

      final rake = design.frameMembers
          .firstWhere((m) => m.label.startsWith('Raking'));
      final before = rake.run;

      final after = DesignEdits.moveFrameMember(design, rake.index, 120);
      final moved = after.frameMembers[rake.index].run;

      // It kept its angle and moved square to itself by the distance asked.
      expect(moved.headingDegrees, closeTo(before.headingDegrees, 0.01));
      expect(before.distanceTo(moved.midpoint), closeTo(120, 0.5));
      // And it is still a five-sided frame.
      expect(after.frame!.outline.corners, hasLength(5));
    });

    test('a side cannot be pushed through the other side', () {
      final before = everything();
      final head = before.frameMembers.firstWhere((m) => m.label == 'Head');
      // Inward, far enough to pass the sill.
      final after = DesignEdits.moveFrameMember(before, head.index, -4000);
      expect(after.frame!.outline.bottom,
          greaterThan(after.frame!.outline.top));
    });
  });
}
