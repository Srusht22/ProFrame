import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/core/services/key_value_store.dart';
import 'package:proframe/features/pricing/pricing_engine.dart';
import 'package:proframe/features/projects/design_repository.dart';
import 'package:proframe/features/recognition/interpretation_service.dart';
import 'package:proframe/features/geometry/region_solver.dart';
import 'package:proframe/features/rendering/three_d/scene_builder.dart';
import 'package:proframe/shared/models/design_document.dart';
import 'package:proframe/shared/models/interpretation.dart';
import 'package:proframe/shared/models/opening_model.dart';
import 'package:proframe/shared/models/scene_3d.dart';

import '../support/sketch_builders.dart';

void main() {
  const service = InterpretationService();

  group('drawing to finished product, end to end', () {
    test('a hand-drawn two-panel window becomes a real 1200 x 800 unit', () async {
      final result = await service.interpret(
        sketch: twoPanelWindowSketch(),
        kind: OpeningKind.window,
      );
      final model = result.model;

      expect(model.widthMm, 1200);
      expect(model.heightMm, 800);
      expect(model.regions, hasLength(2));
      expect(model.regions.first.operation, CellOperation.casementLeft);
      expect(model.regions.last.operation, CellOperation.fixed);
    });

    test('the proportions of the drawing survive into millimetres', () async {
      final result = await service.interpret(
        sketch: twoPanelWindowSketch(),
        kind: OpeningKind.window,
      );
      final solved = RegionSolver.solve(result.model);

      // The mullion was drawn dead centre, so the two sections must match.
      expect(
        solved.topRegions[0].aperture.width,
        closeTo(solved.topRegions[1].aperture.width, 1),
      );
    });

    test('the 3D model that comes out is a real assembly of the right parts', () async {
      final result = await service.interpret(
        sketch: twoPanelWindowSketch(),
        kind: OpeningKind.window,
      );
      final scene = const SceneBuilder().build(result.model);

      expect(scene.parts.length, greaterThan(20));
      expect(scene.partsWithRole(PartRole.mullion), hasLength(1));
      expect(scene.glassCount, 2);
      expect(scene.hingeCount, greaterThanOrEqualTo(2));
      // The hinges belong to the left casement that was drawn.
      for (final hinge in scene.partsWithRole(PartRole.hinge)) {
        expect(hinge.center.x, lessThan(0));
      }
    });

    test('a door drawing produces a door leaf, a threshold and a lock', () async {
      final result = await service.interpret(
        sketch: doorWithTransomSketch(),
        kind: OpeningKind.door,
      );
      final scene = const SceneBuilder().build(result.model);

      expect(result.model.kind, OpeningKind.door);
      expect(result.model.widthMm, 900);
      expect(result.model.heightMm, 2100);
      expect(scene.partsWithRole(PartRole.threshold), hasLength(1));
      expect(scene.partsWithRole(PartRole.lockCylinder), hasLength(1));
      expect(scene.partsWithRole(PartRole.transom), hasLength(1));
    });

    test('the price is derived from the same geometry as the model', () async {
      final result = await service.interpret(
        sketch: twoPanelWindowSketch(),
        kind: OpeningKind.window,
      );
      final scene = const SceneBuilder().build(result.model);
      final breakdown = const PricingEngine().price(result.model);
      final hinges = breakdown.hardware.firstWhere((l) => l.label == 'Hinges');

      expect(hinges.quantity, scene.partsWithRole(PartRole.hinge).length.toDouble());
      expect(breakdown.total, greaterThan(0));
    });
  });

  group('the read-back the user sees', () {
    test('confident readings are listed and nothing is invented', () async {
      final result = await service.interpret(
        sketch: twoPanelWindowSketch(),
        kind: OpeningKind.window,
      );
      final report = result.report;

      expect(report.recognised.any((i) => i.title.contains('Width 1200 mm')), isTrue);
      expect(report.recognised.any((i) => i.title.contains('Height 800 mm')), isTrue);
      expect(report.hasQuestions, isFalse);
      expect(report.confidence, greaterThan(0.8));
    });

    test('an unmeasured drawing asks instead of assuming', () async {
      final sketch = (SketchBuilder()
            ..rectangle(0, 0, 600, 400)
            ..division(300, 0, 300, 400))
          .build();

      final result = await service.interpret(sketch: sketch, kind: OpeningKind.window);
      final width = result.report.items.firstWhere((i) => i.id == 'width');

      expect(width.level, isNot(InterpretationLevel.recognised));
      expect(width.choices, isNotEmpty);
      expect(width.detail, contains('drawing scale'));
    });

    test('an ambiguous opening offers real alternatives', () async {
      final sketch = (SketchBuilder()
            ..rectangle(0, 0, 400, 400)
            ..diagonal(400, 0, 0, 200)
            ..dimension(0, -60, 400, -60, 800)
            ..dimension(460, 0, 460, 400, 800))
          .build();

      final result = await service.interpret(sketch: sketch, kind: OpeningKind.window);
      final cell = result.report.items.firstWhere((i) => i.id.startsWith('cell.'));

      expect(cell.level, InterpretationLevel.uncertain);
      expect(cell.choices.map((c) => c.label), contains(CellOperation.fixed.label));
    });

    test('a panel drawn inside the frame is asked about, never assumed', () async {
      // A rectangle floating inside the outline, touching no edge, with no
      // opening mark on it. The app must ask what it is instead of deciding
      // (section 18) — and must keep it exactly where it was drawn.
      final sketch = (SketchBuilder()
            ..rectangle(0, 0, 1000, 800)
            ..rectangle(250, 200, 750, 600)
            ..dimension(0, -60, 1000, -60, 2000)
            ..dimension(1060, 0, 1060, 800, 1600))
          .build();

      final result = await service.interpret(sketch: sketch, kind: OpeningKind.window);

      final asked = result.report.uncertain
          .where((i) => i.id.startsWith('cell.') && i.title.contains('you drew'))
          .toList();
      expect(asked, isNotEmpty);
      expect(asked.first.choices, isNotEmpty);
      expect(asked.first.detail, contains('did not mark'));

      // The drawn rectangle is still a section of its own, at its own size,
      // and the frame around it was filled in rather than redrawn.
      final inner = result.model.regions.singleWhere(
        (r) => (r.rect.left - 500).abs() < 2 && (r.rect.top - 400).abs() < 2,
      );
      expect(inner.rect.width, closeTo(1000, 2));
      expect(inner.rect.height, closeTo(800, 2));
      expect(result.model.regions.length, greaterThan(1));
    });
  });

  group('saving and reopening', () {
    test('a design round-trips through storage with its ink and its model', () async {
      final result = await service.interpret(
        sketch: twoPanelWindowSketch(),
        kind: OpeningKind.window,
      );
      final repository = DesignRepository(InMemoryKeyValueStore());
      final design = DesignDocument.blank(id: 'd1', kind: OpeningKind.window).copyWith(
        name: 'Kitchen window',
        sketch: twoPanelWindowSketch(),
        model: result.model,
        calibration: result.calibration,
      );

      await repository.save(design);
      final reloaded = (await repository.loadAll()).single;

      expect(reloaded.name, 'Kitchen window');
      expect(reloaded.sketch.strokes.length, design.sketch.strokes.length);
      expect(reloaded.model.widthMm, 1200);
      expect(reloaded.model.allRegions.length, 2);
      expect(reloaded.calibration.pxPerMm, closeTo(0.5, 0.001));
    });

    test('a version can be restored and the state it replaced is kept', () async {
      var design = DesignDocument.blank(id: 'd1', kind: OpeningKind.window);
      design = design.withVersionSnapshot('First save');
      design = design.copyWith(model: design.model.copyWith(widthMm: 2400));

      final restored = design.restoreVersion(design.versions.first.id);

      expect(restored.model.widthMm, 1200);
      expect(restored.versions.first.label, 'Before restore');
      expect(restored.versions.first.model.widthMm, 2400);
    });

    test('an unfinished drawing can be recovered', () async {
      final repository = DesignRepository(InMemoryKeyValueStore());
      final draft = DesignDocument.blank(id: 'draft', kind: OpeningKind.door)
          .copyWith(sketch: doorWithTransomSketch());

      await repository.saveDraft(draft);
      final recovered = await repository.loadDraft();

      expect(recovered, isNotNull);
      expect(recovered!.sketch.strokes, isNotEmpty);

      await repository.clearDraft();
      expect(await repository.loadDraft(), isNull);
    });

    test('a corrupt draft never blocks start-up', () async {
      final store = InMemoryKeyValueStore({'proframe.draft.v1': 'not json'});
      final repository = DesignRepository(store);

      expect(await repository.loadDraft(), isNull);
    });
  });
}
