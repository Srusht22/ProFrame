import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/sketch/stroke.dart';

// A mark says a section opens. It does not say whether the leaf is a door
// or a window, and the two are not made the same — so the user is asked,
// once, about the opening that has just been made.
//
//   User marks  >  in a section
//        ↓
//   The section opens
//        ↓
//   "What is Opening 2?"  [ Door ]  [ Window ]
//        ↓
//   Opening 2 is a door. Every other section is untouched.
//
// **Asked once, and never again.** The answer lives on the opening, so it
// is in the file: a re-reading, a switch between the drawing and the model,
// a line drawn inside the leaf and opening the design tomorrow all find an
// opening that has been answered for. Only the control on the opening's own
// panel changes it.

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 30; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 30)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

List<Vec2> chevron(Vec2 at, {double size = 110}) => [
      Vec2(at.x - size / 2, at.y - size),
      Vec2(at.x + size / 2, at.y),
      Vec2(at.x - size / 2, at.y + size),
    ];

/// The sheet: a fixed head over three marked lights.
Sketch sheet() => Sketch(strokes: [
      pen('outline', const [
        Vec2(0, 0),
        Vec2(4200, 0),
        Vec2(4200, 2400),
        Vec2(0, 2400),
        Vec2(0, 0),
      ]),
      pen('transom', const [Vec2(0, 700), Vec2(4200, 700)]),
      pen('mull1', const [Vec2(1800, 700), Vec2(1800, 2400)]),
      pen('mull2', const [Vec2(2900, 700), Vec2(2900, 2400)]),
      pen('k1', chevron(const Vec2(900, 1550))),
      pen('k2', chevron(const Vec2(2350, 1550))),
      pen('k3', chevron(const Vec2(3550, 1550))),
    ]);

ProviderContainer makeContainer() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

/// A workspace with that sheet read.
WorkspaceController read() {
  final controller = makeContainer().read(workspaceProvider.notifier)
    ..startDesign(DesignKind.window);
  controller.state = controller.state.copyWith(
    design: controller.state.design.copyWith(sketch: sheet()),
  );
  controller.readDrawing();
  return controller;
}

Set<String> asked(WorkspaceController c) =>
    {for (final q in c.state.allQuestions) q.id};

void main() {
  group('the question is put once the opening exists', () {
    test('one question for each opening, and none for a fixed light', () {
      final c = read();
      expect(c.state.design.openings, hasLength(3));

      final kindQuestions = [
        for (final q in c.state.allQuestions)
          if (q.id.startsWith('kind-')) q,
      ];
      expect(kindQuestions, hasLength(3));
      // It names the opening it is about, and offers exactly two answers.
      for (final question in kindQuestions) {
        expect(question.prompt, startsWith('What is Opening'));
        expect([for (final o in question.options) o.key],
            ['door', 'window']);
      }
      expect(kindQuestions.map((q) => q.prompt).toSet(), hasLength(3),
          reason: 'each one names its own opening');
    });

    test('it is about that opening, not about the design', () {
      final c = read();
      final opening = c.state.design.openingsInOrder[1];
      final question = c.state.allQuestions
          .firstWhere((q) => q.id == 'kind-${opening.id}');

      expect(question.aboutIds, contains(opening.id));
      expect(question.aboutIds, contains(opening.sectionId));
      for (final other in c.state.design.openings) {
        if (other.id == opening.id) continue;
        expect(question.aboutIds, isNot(contains(other.id)));
      }
    });

    test('nothing is asked before an opening exists', () {
      final c = makeContainer().read(workspaceProvider.notifier)
        ..startDesign(DesignKind.window);
      c.state = c.state.copyWith(
        design: c.state.design.copyWith(sketch: Sketch(strokes: [
          pen('outline', const [
            Vec2(0, 0),
            Vec2(2000, 0),
            Vec2(2000, 1600),
            Vec2(0, 1600),
            Vec2(0, 0),
          ]),
        ])),
      );
      c.readDrawing();

      expect(c.state.design.openings, isEmpty);
      expect(asked(c).where((id) => id.startsWith('kind-')), isEmpty);
    });
  });

  group('answering touches that opening and nothing else', () {
    test('the answer goes on the opening the question named', () {
      final c = read();
      final opening = c.state.design.openingsInOrder[1];

      c.answer('kind-${opening.id}', 'door');

      final after = c.state.design;
      expect(after.openingById(opening.id)!.kind, DesignKind.door);
      for (final other in after.openings) {
        if (other.id == opening.id) continue;
        expect(other.kind, isNull, reason: 'nobody has said about that one');
      }
      // And the design itself is not made a door: it may hold both.
      expect(after.kind, DesignKind.window);
    });

    test('no geometry moves', () {
      final c = read();
      String shape(Design d) => [
            for (final s in d.sections) '${s.id}:${s.outline.corners}',
            for (final b in d.dividers) '${b.id}:${b.a}|${b.b}',
          ].join('|');
      final before = shape(c.state.design);

      c.answer('kind-${c.state.design.openingsInOrder[0].id}', 'door');
      expect(shape(c.state.design), before);
    });

    test('the leaf’s ironmongery is worked out again', () {
      final c = read();
      final opening = c.state.design.openingsInOrder[0];

      double handleUp(Design design, String openingId) {
        final held = design.openingById(openingId)!.sectionId;
        final handle = design.hardware.firstWhere((piece) =>
            piece.kind.isHandle &&
            design.sectionHolding(piece.parentId) == held);
        return design.sectionById(held)!.outline.bottom - handle.at.y;
      }

      final asWindow = handleUp(c.state.design, opening.id);
      c.answer('kind-${opening.id}', 'door');
      final asDoor = handleUp(c.state.design, opening.id);

      expect(asDoor, greaterThan(asWindow),
          reason: 'a door’s lever is higher than a window’s fastener');
      expect(asDoor, closeTo(1000, 1));

      // And the leaf beside it, which nobody answered for, did not move.
      final other = c.state.design.openingsInOrder[1];
      expect(handleUp(c.state.design, other.id), closeTo(asWindow, 0.01));
    });
  });

  group('and it is never put twice', () {
    test('answering takes the question away', () {
      final c = read();
      final opening = c.state.design.openingsInOrder[2];

      expect(asked(c), contains('kind-${opening.id}'));
      c.answer('kind-${opening.id}', 'window');
      expect(asked(c), isNot(contains('kind-${opening.id}')));
    });

    test('reading the sheet again does not put it back', () {
      final c = read();
      for (final opening in c.state.design.openingsInOrder) {
        c.answer('kind-${opening.id}', 'door');
      }
      expect(asked(c).where((id) => id.startsWith('kind-')), isEmpty);

      c.readDrawing();
      expect(asked(c).where((id) => id.startsWith('kind-')), isEmpty);
      for (final opening in c.state.design.openings) {
        expect(opening.kind, DesignKind.door);
      }
    });

    test('drawing a line inside the leaf does not put it back', () {
      final c = read();
      final opening = c.state.design.openingsInOrder[0];
      c.answer('kind-${opening.id}', 'door');

      final box = c.state.design.sectionById(opening.sectionId)!.outline;
      c.state = c.state.copyWith(
        design: DesignEdits.addLineInside(c.state.design, opening.sectionId,
            id: 'inner',
            at: Vec2(box.centroid.x, box.centroid.y),
            horizontal: true),
      );

      expect(asked(c), isNot(contains('kind-${opening.id}')));
      expect(c.state.design.openingById(opening.id)!.kind, DesignKind.door);
    });

    test('putting the design away and fetching it back does not', () {
      final c = read();
      for (final opening in c.state.design.openingsInOrder) {
        c.answer('kind-${opening.id}', 'window');
      }

      // A new session, with nothing remembered but the file itself.
      final reopened = makeContainer().read(workspaceProvider.notifier)
        ..startDesign(DesignKind.window);
      reopened.state = reopened.state.copyWith(
        design: Design.fromJson(c.state.design.toJson()),
      );
      expect(reopened.state.allQuestions.where((q) =>
          q.id.startsWith('kind-')), isEmpty,
          reason: 'the answer is in the file, so there is nothing to ask');
    });

    test('waving it away settles it for now, and changes nothing', () {
      final c = read();
      final opening = c.state.design.openingsInOrder[0];

      c.dismissQuestion('kind-${opening.id}');

      expect(asked(c), isNot(contains('kind-${opening.id}')));
      expect(c.state.design.openingById(opening.id)!.kind, isNull,
          reason: 'waving a question away is not an answer to it');
      // It still follows the design, which is a kind the user did choose.
      expect(c.state.design.kindOf(c.state.design.openingById(opening.id)!),
          c.state.design.kind);
    });
  });

  group('and the user can change their mind', () {
    test('door to window, and back', () {
      final c = read();
      final opening = c.state.design.openingsInOrder[1];

      c.setOpeningKind(opening.id, DesignKind.door);
      expect(c.state.design.openingById(opening.id)!.kind, DesignKind.door);

      c.setOpeningKind(opening.id, DesignKind.window);
      expect(c.state.design.openingById(opening.id)!.kind, DesignKind.window);

      // Still only that one.
      for (final other in c.state.design.openings) {
        if (other.id == opening.id) continue;
        expect(other.kind, isNull);
      }
    });

    test('changing it moves that leaf’s handle and no other', () {
      final c = read();
      final order = c.state.design.openingsInOrder;
      for (final opening in order) {
        c.setOpeningKind(opening.id, DesignKind.door);
      }

      Map<String, double> handles(Design design) => {
            for (final piece in design.hardware)
              if (piece.kind.isHandle)
                design.sectionHolding(piece.parentId)!: piece.at.y,
          };
      final before = handles(c.state.design);

      c.setOpeningKind(order[1].id, DesignKind.window);
      final after = handles(c.state.design);

      expect(after[order[1].sectionId],
          isNot(closeTo(before[order[1].sectionId]!, 1)));
      expect(after[order[0].sectionId],
          closeTo(before[order[0].sectionId]!, 0.01));
      expect(after[order[2].sectionId],
          closeTo(before[order[2].sectionId]!, 0.01));
    });

    test('setting it to what it already is does nothing at all', () {
      final c = read();
      final opening = c.state.design.openingsInOrder[0];
      c.setOpeningKind(opening.id, DesignKind.door);
      final was = c.state.design.toJson().toString();

      c.setOpeningKind(opening.id, DesignKind.door);
      expect(c.state.design.toJson().toString(), was);
    });
  });
}
