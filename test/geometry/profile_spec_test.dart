import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/core/utilities/geometry_math.dart';
import 'package:proframe/features/geometry/region_solver.dart';
import 'package:proframe/features/pricing/pricing_engine.dart';
import 'package:proframe/features/rendering/three_d/scene_builder.dart';
import 'package:proframe/shared/models/design_region.dart';
import 'package:proframe/shared/models/materials.dart';
import 'package:proframe/shared/models/opening_model.dart';
import 'package:proframe/shared/models/scene_3d.dart';

OpeningModel window({ProfileSpec profile = ProfileSpec.fromMaterial}) => OpeningModel(
      id: 'm',
      kind: OpeningKind.window,
      widthMm: 2000,
      heightMm: 1600,
      profile: profile,
      regions: [
        DesignRegion(id: 'a', rect: Box2.fromLTWH(0, 0, 1000, 1600)),
        DesignRegion(id: 'b', rect: Box2.fromLTWH(1000, 0, 1000, 1600)),
      ],
    );

void main() {
  group('profile sizes follow the material until they are pinned', () {
    test('an untouched design uses the material system', () {
      final model = window();

      expect(model.frameFaceMm, FrameMaterial.aluminium.frameFaceMm);
      expect(model.mullionFaceMm, FrameMaterial.aluminium.mullionFaceMm);
      expect(model.profile.isAllDefault, isTrue);
    });

    test('changing material moves everything that is not pinned', () {
      final aluminium = window();
      final upvc = aluminium.copyWith(material: FrameMaterial.upvc);

      expect(upvc.frameFaceMm, FrameMaterial.upvc.frameFaceMm);
      expect(upvc.frameFaceMm, isNot(aluminium.frameFaceMm));
    });

    test('a pinned size survives a change of material', () {
      final model = window(profile: const ProfileSpec(frameFaceMm: 80))
          .copyWith(material: FrameMaterial.upvc);

      expect(model.frameFaceMm, 80);
      expect(model.sashFaceMm, FrameMaterial.upvc.sashFaceMm,
          reason: 'the ones left alone still follow the material');
    });

    test('clearing a pin hands the dimension back to the material', () {
      final pinned = window(profile: const ProfileSpec(mullionFaceMm: 90));
      expect(pinned.mullionFaceMm, 90);

      final cleared = pinned.copyWith(
        profile: pinned.profile.clearing(ProfileDimension.mullionFace),
      );
      expect(cleared.mullionFaceMm, FrameMaterial.aluminium.mullionFaceMm);
    });
  });

  group('a pinned size reaches everything downstream', () {
    test('a wider frame narrows the apertures in the solved geometry', () {
      final normal = RegionSolver.solve(window());
      final chunky = RegionSolver.solve(window(profile: const ProfileSpec(frameFaceMm: 100)));

      expect(chunky.innerRect.width, lessThan(normal.innerRect.width));
      expect(
        chunky.byId('a')!.aperture.width,
        lessThan(normal.byId('a')!.aperture.width),
      );
    });

    test('a wider mullion is a wider bar, and the sections still add up', () {
      final solved = RegionSolver.solve(window(profile: const ProfileSpec(mullionFaceMm: 100)));
      final bar = solved.bars.firstWhere((b) => b.vertical);

      expect(bar.rect.width, closeTo(100, 0.001));
      final a = solved.byId('a')!.aperture;
      final b = solved.byId('b')!.aperture;
      expect(a.width + b.width + 100 + 2 * 50, closeTo(2000, 0.001));
    });

    test('a deeper frame is deeper in the 3D model', () {
      final normal = const SceneBuilder().build(window());
      final deep = const SceneBuilder()
          .build(window(profile: const ProfileSpec(frameDepthMm: 120)));

      expect(deep.depthMm, 120);
      expect(
        deep.partsWithRole(PartRole.frameHead).single.size.z,
        greaterThan(normal.partsWithRole(PartRole.frameHead).single.size.z),
      );
    });

    test('a wider frame costs more glass-free area, so the price moves', () {
      final normal = const PricingEngine().price(window());
      final chunky = const PricingEngine()
          .price(window(profile: const ProfileSpec(frameFaceMm: 120)));

      final normalGlass =
          normal.materials.firstWhere((l) => l.label.contains('double')).quantity;
      final chunkyGlass =
          chunky.materials.firstWhere((l) => l.label.contains('double')).quantity;
      expect(chunkyGlass, lessThan(normalGlass));
    });

    test('profile overrides survive a save and reload', () {
      final model = window(
        profile: const ProfileSpec(frameFaceMm: 80, glazingBeadMm: 20),
      );
      final restored = OpeningModel.fromJson(model.toJson());

      expect(restored.frameFaceMm, 80);
      expect(restored.glazingBeadMm, 20);
      expect(restored.profile.sashFaceMm, isNull, reason: 'still following material');
    });
  });

  group('infill thickness', () {
    test('follows the glass type until it is set', () {
      const region = DesignRegion(id: 'a', rect: Box2(0, 0, 100, 100));
      expect(region.infillThicknessMm, GlassType.clearDouble.thicknessMm);

      final thick = region.copyWith(glassThicknessMm: 44);
      expect(thick.infillThicknessMm, 44);
    });

    test('a panel section reads the panel thickness', () {
      const region = DesignRegion(
        id: 'a',
        rect: Box2(0, 0, 100, 100),
        infill: CellInfill.panel,
      );
      expect(region.infillThicknessMm, PanelMaterial.sandwichPanel.thicknessMm);
      expect(region.copyWith(panelThicknessMm: 40).infillThicknessMm, 40);
    });

    test('an overridden thickness is what the 3D model is built with', () {
      final model = OpeningModel(
        id: 'm',
        kind: OpeningKind.window,
        widthMm: 1200,
        heightMm: 1400,
        regions: [
          DesignRegion(
            id: 'a',
            rect: Box2.fromLTWH(0, 0, 1200, 1400),
            glassThicknessMm: 44,
          ),
        ],
      );
      final scene = const SceneBuilder().build(model);

      expect(scene.partsWithRole(PartRole.glass).single.size.z, 44);
    });
  });
}
