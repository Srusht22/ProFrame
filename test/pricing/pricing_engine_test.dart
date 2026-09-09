import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/features/geometry/model_editor.dart';
import 'package:proframe/features/pricing/pricing_engine.dart';
import 'package:proframe/features/pricing/pricing_rules.dart';
import 'package:proframe/features/rendering/three_d/scene_builder.dart';
import 'package:proframe/shared/models/materials.dart';
import 'package:proframe/shared/models/opening_model.dart';
import 'package:proframe/shared/models/scene_3d.dart';

const engine = PricingEngine();

OpeningModel window({double width = 1500, double height = 1400}) => OpeningModel(
      id: 'w',
      kind: OpeningKind.window,
      widthMm: width,
      heightMm: height,
      layout: OpeningLayout.single(const LayoutCell(id: 'c0')),
    );

void main() {
  group('the price comes from the geometry, not from a catalogue entry', () {
    test('frame length is the real perimeter of the unit', () {
      final breakdown = engine.price(window());
      final frame = breakdown.materials.firstWhere((l) => l.label.contains('Outer frame'));

      expect(frame.quantity, closeTo(2 * (1.5 + 1.4), 0.01));
      expect(frame.unit, 'm');
    });

    test('glass is charged on the area that is actually glazed', () {
      final model = window();
      final solved = OpeningSolver.solve(model);
      final breakdown = engine.price(model);
      final glass = breakdown.materials.firstWhere((l) => l.label.contains('double'));

      expect(glass.quantity, closeTo(solved.totalGlassAreaM2, 0.01));
      expect(glass.quantity, lessThan(model.areaM2));
    });

    test('a bigger window costs more', () {
      final small = engine.price(window(width: 900, height: 900)).total;
      final large = engine.price(window(width: 2400, height: 1800)).total;

      expect(large, greaterThan(small));
    });

    test('adding a mullion adds a bar line and raises the price', () {
      final plain = engine.price(window());
      final divided = engine.price(ModelEditor.addMullion(window(), 0));

      expect(plain.materials.any((l) => l.label.contains('Mullions')), isFalse);
      expect(divided.materials.any((l) => l.label.contains('Mullions')), isTrue);
      expect(divided.total, greaterThan(plain.total));
    });

    test('making a section open adds sash profile, hinges, a handle and seals', () {
      final fixed = engine.price(window());
      final opening = engine.price(
        ModelEditor.setCellOperation(window(), 'c0', CellOperation.casementRight),
      );

      expect(fixed.hardware, isEmpty);
      expect(opening.hardware.any((l) => l.label == 'Hinges'), isTrue);
      expect(opening.hardware.any((l) => l.label == 'Handles'), isTrue);
      expect(opening.hardware.any((l) => l.label == 'Weather seals'), isTrue);
      expect(opening.materials.any((l) => l.label.contains('Sash')), isTrue);
      expect(opening.total, greaterThan(fixed.total));
    });

    test('the hinge count charged matches the hinge count modelled in 3D', () {
      final model = ModelEditor.setCellOperation(
        window(height: 2000),
        'c0',
        CellOperation.casementRight,
      );
      final breakdown = engine.price(model);
      final hinges = breakdown.hardware.firstWhere((l) => l.label == 'Hinges');
      final scene = const SceneBuilder().build(model);

      expect(hinges.quantity, scene.partsWithRole(PartRole.hinge).length.toDouble());
    });

    test('a more expensive glass raises only the glazing line', () {
      final clear = engine.price(window());
      final lowE = engine.price(
        ModelEditor.updateCell(window(), 'c0', (c) => c.copyWith(glass: GlassType.lowE)),
      );

      expect(lowE.total, greaterThan(clear.total));
      expect(lowE.hardwareTotal, clear.hardwareTotal);
      expect(lowE.labourTotal, clear.labourTotal);
    });

    test('a different frame material changes the frame rate', () {
      final aluminium = engine.price(window());
      final wood = engine.price(window().copyWith(material: FrameMaterial.wood));

      expect(wood.materialsTotal, greaterThan(aluminium.materialsTotal));
    });

    test('a sliding leaf is charged track, not hinges', () {
      final breakdown = engine.price(
        ModelEditor.setCellOperation(window(), 'c0', CellOperation.slidingLeft),
      );

      expect(breakdown.hardware.any((l) => l.label == 'Sliding track'), isTrue);
      expect(breakdown.hardware.any((l) => l.label == 'Hinges'), isFalse);
    });
  });

  group('totals', () {
    test('waste, overhead and margin compound on the direct cost', () {
      const rules = PricingRules(wasteRate: 0.1, overheadRate: 0.1, profitRate: 0.1);
      final breakdown = const PricingEngine(rules: rules).price(window());

      expect(breakdown.wasteAmount, closeTo(breakdown.directTotal * 0.1, 0.01));
      expect(
        breakdown.overheadAmount,
        closeTo((breakdown.directTotal + breakdown.wasteAmount) * 0.1, 0.01),
      );
      expect(
        breakdown.total,
        closeTo(
          breakdown.directTotal +
              breakdown.wasteAmount +
              breakdown.overheadAmount +
              breakdown.profitAmount,
          0.01,
        ),
      );
    });

    test('the currency symbol from the rules is used', () {
      final breakdown =
          const PricingEngine(rules: PricingRules(currencySymbol: '€')).price(window());

      expect(breakdown.currencySymbol, '€');
    });
  });
}
