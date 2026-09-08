import '../configuration/config_enums.dart';
import '../configuration/product_configuration.dart';
import '../manufacturing/bom_line.dart';
import '../manufacturing/cutting_list_line.dart';
import '../pricing/pricing_rules.dart';

/// Derives real manufacturing paperwork — a cutting list and a bill of
/// materials — from the same [ProductConfiguration] the price and the 2D/3D
/// views use, so a width change can never leave the factory floor with
/// stale numbers. Default formulas are intentionally simple/explicit so a
/// factory can replace them with their own cutting/joinery rules later
/// (spec §18: "designed so actual factory-specific formulas can later
/// replace the default formulas").
class ManufacturingEngine {
  const ManufacturingEngine();

  List<CuttingListLine> generateCuttingList(ProductConfiguration config) {
    final lines = <CuttingListLine>[];
    final material = config.frame.material.label;
    final frameThickness = config.frame.frameThicknessMm;

    lines.add(CuttingListLine(
      component: 'Outer Frame — Head',
      lengthMm: config.widthMm,
      quantity: 1,
      material: material,
    ));
    lines.add(CuttingListLine(
      component: 'Outer Frame — Sill',
      lengthMm: config.widthMm,
      quantity: 1,
      material: material,
    ));
    lines.add(CuttingListLine(
      component: 'Outer Frame — Jamb',
      lengthMm: config.heightMm,
      quantity: 2,
      material: material,
    ));

    final sections = config.category == ProductCategory.window ? config.sections : 1;
    if (sections > 1) {
      lines.add(CuttingListLine(
        component: 'Mullion (vertical)',
        lengthMm: config.heightMm,
        quantity: sections - 1,
        material: material,
      ));
    }

    if (config.transomFractions.isNotEmpty) {
      lines.add(CuttingListLine(
        component: 'Transom (horizontal)',
        lengthMm: config.widthMm,
        quantity: config.transomFractions.length,
        material: material,
      ));
    }

    if (config.frame.hasDoorJamb) {
      lines.add(CuttingListLine(
        component: 'Door Jamb',
        lengthMm: config.heightMm,
        quantity: 2,
        material: material,
        notes: 'Reveal lining for masonry opening',
      ));
    }

    if (config.frame.hasThreshold) {
      lines.add(CuttingListLine(
        component: 'Threshold',
        lengthMm: config.widthMm,
        quantity: 1,
        material: material,
      ));
    }

    final operableLeaves = config.leaf.leafCount;
    if (operableLeaves > 0) {
      final perLeafWidth = (config.widthMm / operableLeaves) - (frameThickness * 2);
      final leafHeight = config.heightMm - (frameThickness * 2);
      lines.add(CuttingListLine(
        component: 'Leaf Stile (side)',
        lengthMm: leafHeight,
        quantity: operableLeaves * 2,
        material: material,
        notes: 'Operable leaf vertical members',
      ));
      lines.add(CuttingListLine(
        component: 'Leaf Rail (top/bottom)',
        lengthMm: perLeafWidth.clamp(0, config.widthMm).toDouble(),
        quantity: operableLeaves * 2,
        material: material,
        notes: 'Operable leaf horizontal members',
      ));
    }

    return lines;
  }

  List<BomLine> generateBom(ProductConfiguration config, PricingRules rules) {
    final lines = <BomLine>[];
    final widthM = config.widthM;
    final heightM = config.heightM;
    final perimeterM = 2 * (widthM + heightM);
    final bomSections = config.category == ProductCategory.window ? config.sections : 1;
    final verticalMullions = bomSections > 1 ? bomSections - 1 : 0;
    final totalFrameLengthM = perimeterM + (verticalMullions * heightM) +
        (config.transomFractions.length * widthM);

    final frameRate =
        rules.framePricePerMeter[config.frame.material] ?? rules.framePricePerMeter.values.first;
    lines.add(BomLine(
      partNumber: 'FRM-${config.frame.material.name.toUpperCase()}',
      description: '${config.frame.material.label} profile — ${config.frame.profileSystem}',
      quantity: totalFrameLengthM,
      unit: 'm',
      unitPrice: frameRate,
    ));

    final areaM2 = widthM * heightM;
    if (config.panel.type == PanelType.glass) {
      final glassRate = rules.glassPricePerSqm[config.glass.type] ?? rules.glassPricePerSqm.values.first;
      lines.add(BomLine(
        partNumber: 'GLS-${config.glass.type.name.toUpperCase()}',
        description: '${config.glass.type.label} glass, ${config.glass.thicknessMm.toInt()} mm '
            '(${config.glass.panesCount}-pane)',
        quantity: areaM2,
        unit: 'm²',
        unitPrice: glassRate,
      ));
    } else {
      final panelRate = rules.panelPricePerSqm[config.panel.type] ?? rules.panelPricePerSqm.values.first;
      lines.add(BomLine(
        partNumber: 'PNL-${config.panel.type.name.toUpperCase()}',
        description: config.panel.type.label,
        quantity: areaM2,
        unit: 'm²',
        unitPrice: panelRate,
      ));
    }

    if (config.hardware.hingeCount > 0) {
      lines.add(BomLine(
        partNumber: 'HNG-STD',
        description: 'Hinge',
        quantity: config.hardware.hingeCount.toDouble(),
        unit: 'pcs',
        unitPrice: rules.hingePriceEach,
      ));
    }

    final operableLeaves = config.leaf.leafCount == 0 ? 1 : config.leaf.leafCount;
    if (config.hardware.handleModel != HandleModel.none) {
      lines.add(BomLine(
        partNumber: 'HDL-${config.hardware.handleModel.name.toUpperCase()}',
        description: config.hardware.handleModel.label,
        quantity: operableLeaves.toDouble(),
        unit: 'pcs',
        unitPrice: rules.handleBasePrice + config.hardware.handleModel.relativePriceAdjustment,
      ));
    }

    if (config.hardware.lockType != LockType.none) {
      lines.add(BomLine(
        partNumber: 'LCK-${config.hardware.lockType.name.toUpperCase()}',
        description: config.hardware.lockType.label,
        quantity: 1,
        unit: 'pcs',
        unitPrice: rules.lockPrice[config.hardware.lockType] ?? 0,
      ));
    }

    if (config.hardware.doorCloser != DoorCloserType.none) {
      lines.add(BomLine(
        partNumber: 'CLS-${config.hardware.doorCloser.name.toUpperCase()}',
        description: config.hardware.doorCloser.label,
        quantity: 1,
        unit: 'pcs',
        unitPrice: rules.doorCloserPrice[config.hardware.doorCloser] ?? 0,
      ));
    }

    if (config.accessories.weatherSealing) {
      lines.add(BomLine(
        partNumber: 'SEAL-EPDM',
        description: 'EPDM weather seal / gasket',
        quantity: perimeterM,
        unit: 'm',
        unitPrice: rules.sealPricePerMeter,
      ));
    }

    if (config.accessories.mosquitoNet) {
      lines.add(BomLine(
        partNumber: 'ACC-MOSQ',
        description: 'Mosquito net panel',
        quantity: areaM2,
        unit: 'm²',
        unitPrice: rules.mosquitoNetPricePerSqm,
      ));
    }

    final flatAccessoryCount = [
      config.accessories.safetyLock,
      config.accessories.soundInsulation,
      config.accessories.thermalInsulation,
      config.accessories.decorativeStrips,
    ].where((e) => e).length;
    if (flatAccessoryCount > 0) {
      lines.add(BomLine(
        partNumber: 'ACC-MISC',
        description: 'Selected accessories (safety lock / insulation / trim)',
        quantity: flatAccessoryCount.toDouble(),
        unit: 'set',
        unitPrice: rules.accessoryFlatPrice,
      ));
    }

    // Fasteners: 4 per structural joint (each corner + each internal mullion
    // and transom junction) — a simple, replaceable heuristic.
    final joints = 4 + (verticalMullions * 2) + (config.transomFractions.length * 2);
    lines.add(BomLine(
      partNumber: 'FST-SCR',
      description: 'Self-tapping frame fixing screws',
      quantity: (joints * 4).toDouble(),
      unit: 'pcs',
      unitPrice: 0.06,
    ));

    return lines;
  }
}
