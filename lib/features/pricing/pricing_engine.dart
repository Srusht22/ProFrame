import '../../shared/models/materials.dart';
import '../../shared/models/opening_model.dart';
import '../rendering/three_d/scene_builder.dart';
import 'pricing_rules.dart';

class PriceLine {
  final String label;
  final String detail;
  final double quantity;
  final String unit;
  final double rate;

  const PriceLine({
    required this.label,
    required this.detail,
    required this.quantity,
    required this.unit,
    required this.rate,
  });

  double get total => quantity * rate;
}

class PriceBreakdown {
  final List<PriceLine> materials;
  final List<PriceLine> hardware;
  final List<PriceLine> labour;
  final double wasteAmount;
  final double overheadAmount;
  final double profitAmount;
  final String currencySymbol;

  const PriceBreakdown({
    required this.materials,
    required this.hardware,
    required this.labour,
    required this.wasteAmount,
    required this.overheadAmount,
    required this.profitAmount,
    required this.currencySymbol,
  });

  double get materialsTotal => materials.fold(0, (sum, l) => sum + l.total);
  double get hardwareTotal => hardware.fold(0, (sum, l) => sum + l.total);
  double get labourTotal => labour.fold(0, (sum, l) => sum + l.total);
  double get directTotal => materialsTotal + hardwareTotal + labourTotal;
  double get total => directTotal + wasteAmount + overheadAmount + profitAmount;

  List<PriceLine> get allLines => [...materials, ...hardware, ...labour];
}

/// Prices the product from its actual generated geometry — profile lengths,
/// glass areas, hardware counts — not from a generic catalogue entry (§42).
class PricingEngine {
  final PricingRules rules;

  const PricingEngine({this.rules = const PricingRules()});

  PriceBreakdown price(OpeningModel model) {
    final solved = OpeningSolver.solve(model);
    final material = model.material;

    final materials = <PriceLine>[
      PriceLine(
        label: 'Outer frame profile',
        detail: '${material.label} ${material.frameFaceMm.round()} mm face',
        quantity: _round(solved.framePerimeterM),
        unit: 'm',
        rate: rules.framePerMetre[material] ?? 0,
      ),
      if (solved.barLengthM > 0)
        PriceLine(
          label: 'Mullions & transoms',
          detail: '${solved.allBars.length} bars',
          quantity: _round(solved.barLengthM),
          unit: 'm',
          rate: rules.barPerMetre[material] ?? 0,
        ),
      if (solved.sashPerimeterM > 0)
        PriceLine(
          label: 'Sash / leaf profile',
          detail: '${model.operableCellCount} opening '
              '${model.operableCellCount == 1 ? 'leaf' : 'leaves'}',
          quantity: _round(solved.sashPerimeterM),
          unit: 'm',
          rate: rules.sashPerMetre[material] ?? 0,
        ),
    ];

    // Glazing, grouped by glass type so a mixed unit prices correctly.
    final glassAreas = <GlassType, double>{};
    final panelAreas = <PanelMaterial, double>{};
    for (final cell in solved.leaves) {
      switch (cell.spec.infill) {
        case CellInfill.glass:
          glassAreas.update(cell.spec.glass, (v) => v + cell.glazingAreaM2,
              ifAbsent: () => cell.glazingAreaM2);
        case CellInfill.panel:
        case CellInfill.louvre:
          panelAreas.update(cell.spec.panel, (v) => v + cell.glazingAreaM2,
              ifAbsent: () => cell.glazingAreaM2);
        case CellInfill.mesh:
        case CellInfill.open:
          break;
      }
    }
    glassAreas.forEach((type, area) {
      materials.add(PriceLine(
        label: type.label,
        detail: '${type.thicknessMm.round()} mm glazing',
        quantity: _round(area),
        unit: 'm²',
        rate: rules.glassPerSquareMetre[type] ?? 0,
      ));
    });
    panelAreas.forEach((type, area) {
      materials.add(PriceLine(
        label: type.label,
        detail: '${type.thicknessMm.round()} mm infill',
        quantity: _round(area),
        unit: 'm²',
        rate: rules.panelPerSquareMetre[type] ?? 0,
      ));
    });

    if (model.hasThreshold) {
      materials.add(PriceLine(
        label: 'Threshold',
        detail: 'Full width',
        quantity: _round(model.widthMm / 1000),
        unit: 'm',
        rate: rules.thresholdPerMetre,
      ));
    }
    if (model.hasSill) {
      materials.add(PriceLine(
        label: 'Window sill',
        detail: '${model.sillProjectionMm.round()} mm projection',
        quantity: _round((model.widthMm + 120) / 1000),
        unit: 'm',
        rate: rules.sillPerMetre,
      ));
    }

    // Hardware counts come from the same rules the 3D model uses, so the
    // quote can never list a different number of hinges than the model shows.
    var hinges = 0;
    var handles = 0;
    var locks = 0;
    var trackLength = 0.0;
    var sealLength = 0.0;
    for (final cell in solved.allCells) {
      final operation = cell.spec.operation;
      if (!operation.isOperable) continue;
      sealLength += 2 * (cell.sashRect.width + cell.sashRect.height) / 1000;
      if (operation.isSliding) {
        trackLength += cell.sashRect.width / 1000;
      } else if (operation.hingeSide != HingeSide.none) {
        final span = operation.hingeSide == HingeSide.top || operation.hingeSide == HingeSide.bottom
            ? cell.sashRect.width
            : cell.sashRect.height;
        hinges += SceneBuilder.hingeCountFor(span, isDoor: operation.isDoorLeaf);
      }
      if (cell.spec.handle != HandleStyle.none) handles++;
      if (cell.spec.hasLock) locks++;
    }

    final hardware = <PriceLine>[
      if (hinges > 0)
        PriceLine(
          label: 'Hinges',
          detail: 'Sized to leaf height',
          quantity: hinges.toDouble(),
          unit: 'pcs',
          rate: rules.hingeEach,
        ),
      if (handles > 0)
        PriceLine(
          label: 'Handles',
          detail: 'One per opening leaf',
          quantity: handles.toDouble(),
          unit: 'pcs',
          rate: rules.handleEach,
        ),
      if (locks > 0)
        PriceLine(
          label: 'Locks',
          detail: 'Active leaf',
          quantity: locks.toDouble(),
          unit: 'pcs',
          rate: rules.lockEach,
        ),
      if (trackLength > 0)
        PriceLine(
          label: 'Sliding track',
          detail: 'Top and bottom',
          quantity: _round(trackLength * 2),
          unit: 'm',
          rate: rules.slidingTrackPerMetre,
        ),
      if (sealLength > 0)
        PriceLine(
          label: 'Weather seals',
          detail: 'Around every opening leaf',
          quantity: _round(sealLength),
          unit: 'm',
          rate: rules.sealPerMetre,
        ),
    ];

    final area = model.areaM2;
    final labour = <PriceLine>[
      PriceLine(
        label: 'Fabrication labour',
        detail: 'Cutting, machining, assembly',
        quantity: _round(area),
        unit: 'm²',
        rate: rules.labourPerSquareMetre,
      ),
      PriceLine(
        label: 'Installation',
        detail: 'On site fitting and sealing',
        quantity: _round(area),
        unit: 'm²',
        rate: rules.installationPerSquareMetre,
      ),
    ];

    final direct = materials.fold<double>(0, (s, l) => s + l.total) +
        hardware.fold<double>(0, (s, l) => s + l.total) +
        labour.fold<double>(0, (s, l) => s + l.total);
    final waste = direct * rules.wasteRate;
    final overhead = (direct + waste) * rules.overheadRate;
    final profit = (direct + waste + overhead) * rules.profitRate;

    return PriceBreakdown(
      materials: materials,
      hardware: hardware,
      labour: labour,
      wasteAmount: waste,
      overheadAmount: overhead,
      profitAmount: profit,
      currencySymbol: rules.currencySymbol,
    );
  }

  double _round(double value) => (value * 100).round() / 100;
}
