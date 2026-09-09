import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/core/utilities/geometry_math.dart';
import 'package:proframe/features/geometry/instruction_parser.dart';
import 'package:proframe/shared/models/design_region.dart';
import 'package:proframe/shared/models/opening_model.dart';

const runner = InstructionRunner();

OpeningModel blankWindow() => OpeningModel(
      id: 'm',
      kind: OpeningKind.window,
      widthMm: 2000,
      heightMm: 1600,
      regions: [
        DesignRegion(id: 's1', rect: Box2.fromLTWH(0, 0, 2000, 1600)),
      ],
    );

/// Runs an instruction and insists it was understood and applied.
OpeningModel say(OpeningModel model, String text, {String? selectedId}) {
  final result = runner.run(model, text, selectedId: selectedId);
  expect(
    result.problems,
    isEmpty,
    reason: 'instruction was not carried out: ${result.problems}',
  );
  expect(result.changedAnything, isTrue, reason: 'nothing changed for "$text"');
  return result.model!;
}

DesignRegion byInfill(OpeningModel model, CellInfill infill) =>
    model.allRegions.firstWhere((r) => r.infill == infill);

void main() {
  group('the conversation from the brief, step by step', () {
    test('"half glass, half panel" then "make the glass 70%"', () {
      var model = blankWindow();

      model = say(model, 'Make the upper half glass and the lower half panel.');
      expect(model.regions, hasLength(2));
      var glass = byInfill(model, CellInfill.glass);
      var panel = byInfill(model, CellInfill.panel);
      expect(glass.rect.height, 800);
      expect(panel.rect.height, 800);
      expect(glass.rect.top, 0, reason: 'glass is the upper half');

      model = say(model, 'Actually, make the glass 70%.');
      glass = byInfill(model, CellInfill.glass);
      panel = byInfill(model, CellInfill.panel);
      expect(glass.rect.height, closeTo(1120, 0.001));
      expect(panel.rect.height, closeTo(480, 0.001));
      expect(
        glass.rect.height + panel.rect.height,
        closeTo(model.heightMm, 0.001),
        reason: 'the two still add up to the overall height',
      );
    });

    test('"a 40 cm by 40 cm opening at the top-right" lands exactly there', () {
      var model = blankWindow();
      model = say(
        model,
        'At the top-right of the window, I want an opening that is 40 cm wide '
        'and 40 cm high',
      );

      final opening = model.allRegions.firstWhere((r) => r.operation.isOperable);
      expect(opening.rect.width, 400);
      expect(opening.rect.height, 400);
      expect(opening.rect.right, 2000, reason: 'hard against the right edge');
      expect(opening.rect.top, 0, reason: 'hard against the top edge');
    });

    test('"on the left side, 40 cm wide and full height"', () {
      var model = blankWindow();
      model = say(
        model,
        'On the left side, I want another opening that is 40 cm wide and full height',
      );

      final opening = model.allRegions.firstWhere((r) => r.operation.isOperable);
      expect(opening.rect.width, 400);
      expect(opening.rect.height, 1600);
      expect(opening.rect.left, 0);
    });

    test('the whole brief, run as one paragraph, reproduces the arrangement', () {
      var model = blankWindow();
      model = say(
        model,
        'Make the upper half glass and the lower half panel. '
        'At the top-right, put an opening that is 40 cm wide and 40 cm high. '
        'On the left side make an opening 40 cm wide and full height.',
      );

      final openings =
          model.allRegions.where((r) => r.operation.isOperable).toList();
      expect(openings, hasLength(2));

      final corner = openings.firstWhere((r) => r.rect.height == 400);
      final side = openings.firstWhere((r) => r.rect.height == 1600);

      expect(corner.rect.width, 400);
      expect(corner.rect.right, 2000);
      expect(corner.rect.top, 0);

      expect(side.rect.width, 400);
      expect(side.rect.left, 0);

      // Everything still lives inside the product, nothing overlaps.
      for (final region in model.regions) {
        expect(region.rect.left, greaterThanOrEqualTo(-0.001));
        expect(region.rect.right, lessThanOrEqualTo(2000.001));
      }
    });
  });

  group('the documented phrasings', () {
    test('"make the left section 40 cm wide"', () {
      var model = say(blankWindow(), 'Make the left half glass and the right half panel');
      model = say(model, 'Make the left section 40 cm wide');

      final left = model.regions.reduce((a, b) => a.rect.left <= b.rect.left ? a : b);
      final right = model.regions.reduce((a, b) => a.rect.left > b.rect.left ? a : b);
      expect(left.rect.width, 400);
      expect(right.rect.width, 1600, reason: 'the neighbour took up the difference');
    });

    test('"full height" really is full height — it takes the space it needs', () {
      var model = say(blankWindow(), 'Make the upper half glass and the lower half panel');
      model = say(model, 'Make the upper section full height');

      final tall = model.allRegions.reduce(
        (a, b) => a.rect.height >= b.rect.height ? a : b,
      );
      expect(tall.rect.height, 1600);
      expect(
        model.regions.every((r) => r.rect.height == 1600),
        isTrue,
        reason: 'the section it covered entirely is gone, not squeezed to a sliver',
      );
    });

    test('"make the right panel sliding"', () {
      var model = say(blankWindow(), 'Make the left half glass and the right half panel');
      model = say(model, 'Make the right panel sliding');

      final right = model.regions.reduce((a, b) => a.rect.left > b.rect.left ? a : b);
      expect(right.operation, CellOperation.slidingRight);
    });

    test('"keep the centre panel fixed"', () {
      var model = say(blankWindow(), 'Make the left half glass and the right half panel');
      model = say(model, 'Make the right panel sliding');
      model = say(model, 'Keep the right panel fixed');

      final right = model.regions.reduce((a, b) => a.rect.left > b.rect.left ? a : b);
      expect(right.operation, CellOperation.fixed);
    });

    test('"put the handle 100 cm from the floor"', () {
      var model = say(
        blankWindow(),
        'At the top-right put an opening that is 40 cm wide and 40 cm high',
      );
      model = say(model, 'Put the handle 100 cm from the floor');

      final opening = model.allRegions.firstWhere((r) => r.operation.isOperable);
      expect(opening.handleHeightMm, 1000);
    });

    test('"make the left section 30 cm wider than the right section"', () {
      var model = say(blankWindow(), 'Make the left half glass and the right half panel');
      model = say(model, 'Make the left section 30 cm wider than the right section');

      final left = model.regions.reduce((a, b) => a.rect.left <= b.rect.left ? a : b);
      final right = model.regions.reduce((a, b) => a.rect.left > b.rect.left ? a : b);
      expect(left.rect.width - right.rect.width, closeTo(300, 0.001));
      expect(left.rect.width + right.rect.width, closeTo(2000, 0.001));
    });

    test('"move this to the top-right"', () {
      final placed = runner.run(
        blankWindow(),
        'At the bottom-left put an opening that is 40 cm wide and 40 cm high',
      );
      final model = say(
        placed.model!,
        'Move this to the top-right',
        selectedId: placed.selectedId,
      );

      final opening = model.region(placed.selectedId!)!;
      expect(opening.rect.right, 2000);
      expect(opening.rect.top, 0);
    });

    test('"half of the window glass and the other half panel"', () {
      final model = say(
        blankWindow(),
        'I want half of the window to be glass and the other half to be panel',
      );
      expect(model.regions, hasLength(2));
      expect(byInfill(model, CellInfill.glass).rect.height, 800);
    });
  });

  group('it refuses rather than guessing', () {
    test('an unrecognised sentence changes nothing and says so', () {
      final result = runner.run(blankWindow(), 'make it look nicer please');

      expect(result.changedAnything, isFalse);
      expect(result.problems.single, contains('did not understand'));
    });

    test('an ambiguous section is queried, not picked at random', () {
      // Two glass sections of the same size: "the glass" cannot mean one.
      final model = OpeningModel(
        id: 'm',
        kind: OpeningKind.window,
        widthMm: 2000,
        heightMm: 1600,
        regions: [
          DesignRegion(id: 'a', rect: Box2.fromLTWH(0, 0, 1000, 1600)),
          DesignRegion(id: 'b', rect: Box2.fromLTWH(1000, 0, 1000, 1600)),
        ],
      );
      final result = runner.run(model, 'Make the glass 70%');

      expect(result.changedAnything, isFalse);
      expect(result.problems.single.toLowerCase(), contains('could mean'));
    });

    test('a divide with no target and several sections asks instead of picking', () {
      final model = OpeningModel(
        id: 'm',
        kind: OpeningKind.window,
        widthMm: 2000,
        heightMm: 1600,
        regions: [
          DesignRegion(id: 'a', rect: Box2.fromLTWH(0, 0, 1000, 1600)),
          DesignRegion(id: 'b', rect: Box2.fromLTWH(1000, 0, 1000, 1600)),
        ],
      );
      final result =
          runner.run(model, 'Make the upper half glass and the lower half panel');

      expect(result.changedAnything, isFalse);
      expect(result.problems.single, contains('say which one you mean'));
    });

    test('an opening larger than the product is refused with the numbers', () {
      final result = runner.run(
        blankWindow(),
        'At the top-right put an opening that is 300 cm wide and 40 cm high',
      );

      expect(result.changedAnything, isFalse);
      expect(result.problems.single, contains('does not fit'));
    });

    test('a handle outside the product is refused', () {
      final placed = runner.run(
        blankWindow(),
        'At the top-right put an opening that is 40 cm wide and 40 cm high',
      );
      final result = runner.run(placed.model!, 'Put the handle 500 cm from the floor');

      expect(result.changedAnything, isFalse);
      expect(result.problems.single, contains('outside'));
    });

    test('nothing selected means "this" is a question, not a guess', () {
      final result = runner.run(blankWindow(), 'Move this to the top-right');
      expect(result.changedAnything, isFalse);
    });
  });

  test('every documented example parses', () {
    const parser = InstructionParser();
    for (final example in InstructionParser.examples) {
      final parsed = parser.parse(example);
      expect(
        parsed.single.isUnderstood,
        isTrue,
        reason: 'the help text advertises "$example" but it does not parse',
      );
    }
  });
}
