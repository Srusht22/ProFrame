import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/configuration/config_enums.dart';
import 'package:proframe/domain/configuration/configuration_value_objects.dart';
import 'package:proframe/domain/configuration/product_configuration.dart';

void main() {
  test('ProductConfiguration survives a toJson/fromJson round trip', () {
    final now = DateTime.now();
    final original = ProductConfiguration(
      id: 'roundtrip-1',
      projectId: 'proj-1',
      name: 'Round trip door',
      category: ProductCategory.door,
      doorType: DoorType.entrance,
      widthMm: 1234.5,
      heightMm: 2222.5,
      wallOpeningWidthMm: 1260,
      wallOpeningHeightMm: 2250,
      quantity: 4,
      frame: const FrameSpec(
        material: FrameMaterial.steel,
        profileSystem: 'Heavy 90',
        frameDepthMm: 90,
        frameThicknessMm: 60,
        hasDoorJamb: true,
        hasThreshold: true,
      ),
      leaf: const LeafSpec(
        arrangement: LeafArrangement.unequalDouble,
        leafCount: 2,
        primaryLeafRatio: 0.62,
        openingDirection: OpeningDirection.rightHinge,
      ),
      panel: const PanelSpec(type: PanelType.glass, rows: 2, columns: 1),
      glass: const GlassSpec(type: GlassType.laminated, thicknessMm: 8.8, panesCount: 1),
      hardware: const HardwareSpec(
        hingeCount: 4,
        handleModel: HandleModel.premiumLever,
        lockType: LockType.multiPointLock,
        doorCloser: DoorCloserType.concealed,
        hasPullHandle: true,
      ),
      finish: const FinishSpec(frameColor: FrameColor.custom, customHexColor: '#334455'),
      accessories: const AccessoryOptions(mosquitoNet: true, safetyLock: true, customEngraving: 'ProFrame'),
      sections: 1,
      transomFractions: const [0.25, 0.75],
      state: ProductConfigState.quoted,
      notes: 'Handle with care',
      version: 3,
      createdByUserId: 'user-1',
      createdAt: now,
      updatedAt: now,
    );

    final restored = ProductConfiguration.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.widthMm, original.widthMm);
    expect(restored.heightMm, original.heightMm);
    expect(restored.frame.material, original.frame.material);
    expect(restored.frame.hasDoorJamb, isTrue);
    expect(restored.leaf.arrangement, LeafArrangement.unequalDouble);
    expect(restored.leaf.primaryLeafRatio, closeTo(0.62, 1e-9));
    expect(restored.glass.type, GlassType.laminated);
    expect(restored.hardware.lockType, LockType.multiPointLock);
    expect(restored.finish.customHexColor, '#334455');
    expect(restored.accessories.mosquitoNet, isTrue);
    expect(restored.accessories.customEngraving, 'ProFrame');
    expect(restored.transomFractions, [0.25, 0.75]);
    expect(restored.state, ProductConfigState.quoted);
    expect(restored.version, 3);
  });

  test('to3DParams exposes flat primitives the JS engine can consume', () {
    final config = ProductConfiguration.newDraft(name: 'Window', category: ProductCategory.window);
    final params = config.to3DParams();

    expect(params['category'], 'window');
    expect(params['width'], config.widthMm);
    expect(params['height'], config.heightMm);
    expect(params, isNot(contains('id'))); // never leaks internal ids into the render payload
  });
}
