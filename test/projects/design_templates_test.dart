import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/features/pricing/pricing_engine.dart';
import 'package:proframe/features/projects/design_templates.dart';
import 'package:proframe/features/rendering/three_d/scene_builder.dart';
import 'package:proframe/shared/models/materials.dart';
import 'package:proframe/shared/models/opening_model.dart';
import 'package:proframe/shared/models/scene_3d.dart';

void main() {
  test('template ids are unique', () {
    final ids = designTemplates.map((t) => t.id).toSet();
    expect(ids, hasLength(designTemplates.length));
  });

  group('every template is a real, buildable product', () {
    for (final template in designTemplates) {
      test('${template.name} solves, renders and prices cleanly', () {
        final model = template.build('t');
        final solved = OpeningSolver.solve(model);
        final scene = const SceneBuilder().build(model);
        final price = const PricingEngine().price(model);

        expect(model.kind, template.kind);
        expect(solved.leaves, isNotEmpty);
        expect(scene.parts.length, greaterThan(4));
        expect(price.total, greaterThan(0));
        expect(
          model.validate(),
          isEmpty,
          reason: '${template.name} should not ship with manufacturing warnings',
        );

        // Sections must exactly fill the frame, as for any other model.
        final row = solved.topCells.where((c) => c.rowIndex == 0).toList();
        final widths = row.fold<double>(0, (sum, c) => sum + c.aperture.width);
        final bars = (row.length - 1) * model.material.mullionFaceMm;
        expect(
          widths + bars + 2 * model.material.frameFaceMm,
          closeTo(model.widthMm, 0.001),
        );
      });
    }
  });

  test('cell ids are unique inside a template, so edits address one section', () {
    for (final template in designTemplates) {
      final ids = template.build('t').layout.allCells.map((c) => c.id).toList();
      expect(ids.toSet(), hasLength(ids.length), reason: template.name);
    }
  });

  test('the glass-over-panel door really has two sections in one leaf', () {
    final model =
        designTemplates.firstWhere((t) => t.id == 'door-glass-panel').build('t');
    final solved = OpeningSolver.solve(model);
    final scene = const SceneBuilder().build(model);

    expect(solved.leaves, hasLength(2));
    expect(solved.leaves.map((c) => c.spec.infill), contains(CellInfill.panel));
    expect(scene.partsWithRole(PartRole.panel), hasLength(1));
    expect(scene.partsWithRole(PartRole.glass), hasLength(1));
    // One leaf frame, so one handle.
    expect(scene.partsWithRole(PartRole.handle), hasLength(1));
  });

  test('the double door locks only the active leaf', () {
    final model = designTemplates.firstWhere((t) => t.id == 'double-door').build('t');
    final scene = const SceneBuilder().build(model);

    expect(model.operableCellCount, 2);
    expect(scene.partsWithRole(PartRole.lockCylinder), hasLength(1));
  });

  test('the two-panel slider puts its leaves in different tracks', () {
    final model =
        designTemplates.firstWhere((t) => t.id == 'sliding-two-panel').build('t');
    final scene = const SceneBuilder().build(model);
    final left = scene.partsForCell('r0.c0').firstWhere((p) => p.role == PartRole.glass);
    final right = scene.partsForCell('r0.c1').firstWhere((p) => p.role == PartRole.glass);

    expect(left.center.z, isNot(right.center.z));
    expect(scene.partsWithRole(PartRole.hinge), isEmpty);
  });
}
