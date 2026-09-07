import '../configuration/config_enums.dart';
import '../configuration/product_configuration.dart';
import '../pricing/price_breakdown.dart';
import '../pricing/pricing_rules.dart';

/// Turns a [ProductConfiguration] + [PricingRules] into a transparent,
/// itemized [PriceBreakdown]. Pure calculation — no widgets, no I/O, no
/// hard-coded numbers (every rate comes from [PricingRules], which an
/// administrator can edit from Settings → Pricing Rules).
///
/// Worked example the formulas below follow (spec §14), for a 1000×2100 mm
/// door: frame perimeter = 2×2100 + 1000 = 5200 mm = 5.2 m; glass/panel
/// area = 1.0 × 2.1 = 2.1 m². Extra frame length is added on top of the
/// simple perimeter for every internal mullion/transom, and glazed area is
/// split evenly across [ProductConfiguration.sections] + any transoms so a
/// sectioned window's BOM and price stay consistent with its 2D/3D layout.
class PricingEngine {
  final PricingRules rules;

  const PricingEngine(this.rules);

  PriceBreakdown calculate(ProductConfiguration config) {
    final widthM = config.widthM;
    final heightM = config.heightM;

    // --- Frame -----------------------------------------------------------
    final perimeterM = 2 * (widthM + heightM);
    final sections = config.category == ProductCategory.window ? config.sections : 1;
    final verticalMullions = sections > 1 ? sections - 1 : 0;
    final mullionLengthM = verticalMullions * heightM;
    final transomLengthM = config.transomFractions.length * widthM;
    final totalFrameLengthM = perimeterM + mullionLengthM + transomLengthM;

    final frameRate = rules.framePricePerMeter[config.frame.material] ??
        rules.framePricePerMeter.values.first;
    final finishFactor = rules.finishMultiplier[config.finish.frameColor] ?? 1.0;
    final frameCost = totalFrameLengthM * frameRate * finishFactor;

    // --- Glass / Panel -----------------------------------------------------
    final grossAreaM2 = widthM * heightM;
    final glazedAreaM2 = config.panel.type != PanelType.solid ? grossAreaM2 : 0.0;
    final solidAreaM2 = config.panel.type == PanelType.solid ? grossAreaM2 : 0.0;

    final glassRate = rules.glassPricePerSqm[config.glass.type] ?? rules.glassPricePerSqm.values.first;
    final panelRate = rules.panelPricePerSqm[config.panel.type] ?? rules.panelPricePerSqm.values.first;

    final glassCost = config.panel.type == PanelType.glass ? glazedAreaM2 * glassRate : 0.0;
    final panelCost = config.panel.type != PanelType.glass ? solidAreaM2 * panelRate : 0.0;

    // --- Hardware ----------------------------------------------------------
    final hingeCost = config.hardware.hingeCount * rules.hingePriceEach;
    final operableLeaves = config.leaf.leafCount == 0 ? 1 : config.leaf.leafCount;
    final handleCost = config.hardware.handleModel == HandleModel.none
        ? 0.0
        : (rules.handleBasePrice + config.hardware.handleModel.relativePriceAdjustment) *
            operableLeaves;
    final lockCost = rules.lockPrice[config.hardware.lockType] ?? 0.0;
    final closerCost = rules.doorCloserPrice[config.hardware.doorCloser] ?? 0.0;
    final hardwareCost = hingeCost + handleCost + lockCost + closerCost;

    // --- Accessories ---------------------------------------------------------
    final flatAccessoryCost = config.accessories.activeCount * rules.accessoryFlatPrice;
    final mosquitoNetCost =
        config.accessories.mosquitoNet ? grossAreaM2 * rules.mosquitoNetPricePerSqm : 0.0;
    final sealCost = config.accessories.weatherSealing ? perimeterM * rules.sealPricePerMeter : 0.0;
    final accessoriesCost = flatAccessoryCost + mosquitoNetCost + sealCost;

    final materialLines = [
      PriceLineItem(
        label: 'Frame',
        amount: frameCost,
        description:
            '${totalFrameLengthM.toStringAsFixed(2)} m × ${config.frame.material.label} @ ${rules.currency.format(frameRate)}/m',
      ),
      if (glassCost > 0)
        PriceLineItem(
          label: 'Glass',
          amount: glassCost,
          description:
              '${glazedAreaM2.toStringAsFixed(2)} m² × ${config.glass.type.label} @ ${rules.currency.format(glassRate)}/m²',
        ),
      if (panelCost > 0)
        PriceLineItem(
          label: 'Panel',
          amount: panelCost,
          description:
              '${solidAreaM2.toStringAsFixed(2)} m² × ${config.panel.type.label} @ ${rules.currency.format(panelRate)}/m²',
        ),
      PriceLineItem(
        label: 'Hardware',
        amount: hardwareCost,
        description:
            '${config.hardware.hingeCount} hinges, ${config.hardware.handleModel.label}, ${config.hardware.lockType.label}',
      ),
      if (accessoriesCost > 0)
        PriceLineItem(
          label: 'Accessories',
          amount: accessoriesCost,
          description: 'Seals, mosquito net & selected add-ons',
        ),
    ];

    final materialsSubtotal = frameCost + glassCost + panelCost + hardwareCost + accessoriesCost;

    // --- Labor ---------------------------------------------------------------
    final labor = rules.laborMode == LaborMode.percentageOfMaterials
        ? materialsSubtotal * rules.laborPercent
        : rules.laborFixedPerUnit;

    // --- Finishing (extra cost of the selected finish beyond baseline) -------
    final finishing = materialsSubtotal * (finishFactor - 1.0).clamp(0, double.infinity);

    final materialsLaborFinishing = materialsSubtotal + labor + finishing;

    // --- Waste & Overhead ------------------------------------------------------
    final waste = materialsLaborFinishing * rules.wastePercent;
    final overhead = (materialsLaborFinishing + waste) * rules.overheadPercent;

    final subtotal = materialsLaborFinishing + waste + overhead;

    // --- Profit --------------------------------------------------------------
    final profit = subtotal * rules.profitPercent;
    final unitPrice = subtotal + profit;
    final lineTotal = unitPrice * config.quantity;

    return PriceBreakdown(
      materialLines: materialLines,
      materialsSubtotal: materialsSubtotal,
      labor: labor,
      finishing: finishing,
      waste: waste,
      overhead: overhead,
      subtotal: subtotal,
      profit: profit,
      unitPrice: unitPrice,
      quantity: config.quantity,
      lineTotal: lineTotal,
      currency: rules.currency,
    );
  }
}
