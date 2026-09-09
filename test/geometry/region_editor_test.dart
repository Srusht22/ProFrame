import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/core/utilities/geometry_math.dart';
import 'package:proframe/features/geometry/design_validator.dart';
import 'package:proframe/features/geometry/region_editor.dart';
import 'package:proframe/features/geometry/region_solver.dart';
import 'package:proframe/shared/models/design_region.dart';
import 'package:proframe/shared/models/opening_model.dart';

OpeningModel twoSections() => OpeningModel(
      id: 'm',
      kind: OpeningKind.window,
      widthMm: 2000,
      heightMm: 1600,
      regions: [
        DesignRegion(id: 'glass', rect: Box2.fromLTWH(0, 0, 2000, 800)),
        DesignRegion(
          id: 'panel',
          rect: Box2.fromLTWH(0, 800, 2000, 800),
          infill: CellInfill.panel,
        ),
      ],
    );

OpeningModel sideBySide() => OpeningModel(
      id: 'm',
      kind: OpeningKind.window,
      widthMm: 2000,
      heightMm: 1600,
      regions: [
        DesignRegion(id: 'left', rect: Box2.fromLTWH(0, 0, 800, 1600)),
        DesignRegion(id: 'right', rect: Box2.fromLTWH(800, 0, 1200, 1600)),
      ],
    );

double totalArea(OpeningModel model) =>
    model.regions.fold<double>(0, (sum, r) => sum + r.rect.width * r.rect.height);

void main() {
  group('dragging a boundary', () {
    test('carries the neighbour so the total never changes', () {
      final before = twoSections();
      final after = RegionEditor.dragEdge(before, 'glass', RegionEdge.bottom, 1120);

      expect(after.region('glass')!.rect.height, 1120);
      expect(after.region('panel')!.rect.top, 1120);
      expect(after.region('panel')!.rect.height, 480);
      expect(
        after.region('glass')!.rect.height + after.region('panel')!.rect.height,
        after.heightMm,
      );
    });

    test('typing a size and dragging land on identical geometry', () {
      final dragged = RegionEditor.dragEdge(twoSections(), 'glass', RegionEdge.bottom, 1120);
      final typed = RegionEditor.setHeight(twoSections(), 'glass', 1120);

      expect(typed.region('glass')!.rect, dragged.region('glass')!.rect);
      expect(typed.region('panel')!.rect, dragged.region('panel')!.rect);
    });

    test('stops at the minimum instead of collapsing the neighbour', () {
      final after = RegionEditor.dragEdge(twoSections(), 'glass', RegionEdge.bottom, 5000);

      expect(after.region('panel')!.rect.height, RegionEditor.minSectionMm);
      expect(totalArea(after), closeTo(2000 * 1600, 0.001));
    });

    test('only the sections that actually share the boundary move', () {
      // A corner opening shares the vertical boundary at x = 1600 with the
      // section beside it, but not with the full-width section below.
      final model = OpeningModel(
        id: 'm',
        kind: OpeningKind.window,
        widthMm: 2000,
        heightMm: 1600,
        regions: [
          DesignRegion(id: 'corner', rect: Box2.fromLTWH(1600, 0, 400, 400)),
          DesignRegion(id: 'beside', rect: Box2.fromLTWH(0, 0, 1600, 400)),
          DesignRegion(id: 'below', rect: Box2.fromLTWH(0, 400, 2000, 1200)),
        ],
      );

      final after = RegionEditor.dragEdge(model, 'corner', RegionEdge.left, 1500);

      expect(after.region('corner')!.rect.width, 500);
      expect(after.region('beside')!.rect.width, 1500);
      expect(
        after.region('below')!.rect,
        model.region('below')!.rect,
        reason: 'the section below does not touch that boundary',
      );
    });

    test('a boundary can never leave the product', () {
      final model = sideBySide();
      final limits = RegionEditor.edgeLimits(model, 'left', RegionEdge.left);

      expect(limits.min, 0, reason: 'cannot go past the frame');
      expect(limits.max, lessThan(model.widthMm));

      final pushed = RegionEditor.dragEdge(model, 'left', RegionEdge.left, -500);
      expect(pushed.region('left')!.rect.left, 0);
    });

    test('shrinking a section leaves unassigned area, reported not filled', () {
      final model = sideBySide();
      final after = RegionEditor.dragEdge(model, 'left', RegionEdge.left, 200);

      expect(after.region('left')!.rect.left, 200);
      expect(
        after.region('right')!.rect,
        model.region('right')!.rect,
        reason: 'the far neighbour is not dragged along',
      );
      expect(
        const DesignValidator().validate(after).any((i) => i.id == 'coverage'),
        isTrue,
      );
    });
  });

  group('placing a section carves, it does not rearrange', () {
    test('a corner opening leaves the rest as the pieces around it', () {
      final model = OpeningModel(
        id: 'm',
        kind: OpeningKind.window,
        widthMm: 2000,
        heightMm: 1600,
        regions: [DesignRegion(id: 'all', rect: Box2.fromLTWH(0, 0, 2000, 1600))],
      );

      final placed = RegionEditor.placeRegion(
        model,
        Box2.fromLTWH(1600, 0, 400, 400),
        operation: CellOperation.awning,
      );

      final opening = placed.model.region(placed.id)!;
      expect(opening.rect.width, 400);
      expect(opening.rect.height, 400);
      expect(opening.rect.right, 2000);
      expect(opening.rect.top, 0);

      // Still exactly covers the product, with nothing overlapping.
      expect(totalArea(placed.model), closeTo(2000 * 1600, 0.001));
      expect(const DesignValidator().validate(placed.model), isEmpty);
    });

    test('subtracting a corner gives back rectangles that tile the remainder', () {
      final pieces = RegionEditor.subtract(
        Box2.fromLTWH(0, 0, 2000, 1600),
        Box2.fromLTWH(1600, 0, 400, 400),
      );
      final area = pieces.fold<double>(0, (sum, p) => sum + p.width * p.height);

      expect(area, closeTo(2000 * 1600 - 400 * 400, 0.001));
      for (var i = 0; i < pieces.length; i++) {
        for (var j = i + 1; j < pieces.length; j++) {
          expect(pieces[i].overlaps(pieces[j]), isFalse);
        }
      }
    });
  });

  group('changing the overall size', () {
    test('scaling keeps the design’s shape', () {
      final after = RegionEditor.setOverallSize(sideBySide(), widthMm: 4000);

      expect(after.region('left')!.rect.width, 1600);
      expect(after.region('right')!.rect.width, 2400);
      expect(totalArea(after), closeTo(4000 * 1600, 0.001));
    });

    test('keeping the sections leaves the shortfall for the validator to report', () {
      final after = RegionEditor.setOverallSize(
        sideBySide(),
        widthMm: 3000,
        mode: ResizeMode.keepSections,
      );

      expect(after.region('left')!.rect.width, 800, reason: 'sizes untouched');
      final issues = const DesignValidator().validate(after);
      expect(issues.any((i) => i.id == 'coverage'), isTrue);
    });
  });

  group('the validator reports and never edits', () {
    test('an overlap is reported with both sections named', () {
      final model = OpeningModel(
        id: 'm',
        kind: OpeningKind.window,
        widthMm: 2000,
        heightMm: 1600,
        regions: [
          DesignRegion(id: 'a', rect: Box2.fromLTWH(0, 0, 1200, 1600)),
          DesignRegion(id: 'b', rect: Box2.fromLTWH(1000, 0, 1000, 1600)),
        ],
      );

      final issues = const DesignValidator().validate(model);
      expect(issues.any((i) => i.title.contains('overlap')), isTrue);
      // Reporting did not change the design.
      expect(model.region('a')!.rect.width, 1200);
      expect(model.region('b')!.rect.left, 1000);
    });

    test('an over-wide leaf is a warning with an offered fix, not an edit', () {
      final model = RegionEditor.setOperation(
        OpeningModel(
          id: 'm',
          kind: OpeningKind.window,
          widthMm: 2000,
          heightMm: 1600,
          regions: [DesignRegion(id: 'wide', rect: Box2.fromLTWH(0, 0, 2000, 1600))],
        ),
        'wide',
        CellOperation.casementLeft,
      );

      final issue = const DesignValidator()
          .validate(model)
          .firstWhere((i) => i.id.startsWith('leafWidth'));

      expect(issue.severity, IssueSeverity.warning);
      expect(issue.hasRecommendation, isTrue);
      expect(model.region('wide')!.rect.width, 2000, reason: 'still as designed');

      // The fix only applies when it is asked for.
      final fixed = issue.recommendedFix!(model);
      expect(fixed.region('wide')!.rect.width, DesignValidator.maxLeafWidthMm);
    });

    test('a deliberately asymmetric design raises nothing', () {
      final model = OpeningModel(
        id: 'm',
        kind: OpeningKind.window,
        widthMm: 2000,
        heightMm: 1600,
        regions: [
          DesignRegion(id: 'a', rect: Box2.fromLTWH(0, 0, 300, 1600)),
          DesignRegion(id: 'b', rect: Box2.fromLTWH(300, 0, 1700, 1600)),
        ],
      );

      expect(const DesignValidator().validate(model), isEmpty);
    });
  });

  group('dividing', () {
    test('splitting makes two independent sections that still fill the space', () {
      final after = RegionEditor.divide(
        OpeningModel(
          id: 'm',
          kind: OpeningKind.window,
          widthMm: 2000,
          heightMm: 1600,
          regions: [DesignRegion(id: 'all', rect: Box2.fromLTWH(0, 0, 2000, 1600))],
        ),
        'all',
        axis: Axis2.horizontal,
        ratio: 0.7,
      );

      expect(after.regions, hasLength(2));
      expect(after.regions.first.rect.height, closeTo(1120, 0.001));
      expect(totalArea(after), closeTo(2000 * 1600, 0.001));
    });

    test('splitting inside makes panes within one leaf', () {
      final after = RegionEditor.divide(
        RegionEditor.setOperation(
          OpeningModel(
            id: 'm',
            kind: OpeningKind.door,
            widthMm: 900,
            heightMm: 2100,
            regions: [DesignRegion(id: 'leaf', rect: Box2.fromLTWH(0, 0, 900, 2100))],
          ),
          'leaf',
          CellOperation.doorLeafRight,
        ),
        'leaf',
        axis: Axis2.horizontal,
        inside: true,
      );

      expect(after.regions, hasLength(1), reason: 'still one leaf');
      expect(after.regions.single.children, hasLength(2));
      expect(RegionSolver.solve(after).leaves, hasLength(2));
    });

    test('a section too small to divide is left alone', () {
      final model = OpeningModel(
        id: 'm',
        kind: OpeningKind.window,
        widthMm: 200,
        heightMm: 200,
        regions: [DesignRegion(id: 'tiny', rect: Box2.fromLTWH(0, 0, 200, 200))],
      );
      final after = RegionEditor.divide(model, 'tiny', axis: Axis2.horizontal);

      expect(after.regions, hasLength(1));
    });
  });

  test('a free-form design survives a save and reload unchanged', () {
    final model = OpeningModel(
      id: 'm',
      kind: OpeningKind.window,
      widthMm: 2000,
      heightMm: 1600,
      regions: [
        DesignRegion(
          id: 'corner',
          rect: Box2.fromLTWH(1600, 0, 400, 400),
          label: 'Top vent',
          operation: CellOperation.awning,
          handleHeightMm: 1000,
        ),
        DesignRegion(id: 'rest', rect: Box2.fromLTWH(0, 0, 1600, 1600)),
        DesignRegion(id: 'strip', rect: Box2.fromLTWH(1600, 400, 400, 1200)),
      ],
    );

    final restored = OpeningModel.fromJson(model.toJson());

    expect(restored.regions, hasLength(3));
    expect(restored.region('corner')!.rect, model.region('corner')!.rect);
    expect(restored.region('corner')!.label, 'Top vent');
    expect(restored.region('corner')!.handleHeightMm, 1000);
    expect(restored.region('strip')!.rect.width, 400);
  });
}
