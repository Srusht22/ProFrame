import 'currency.dart';

class PriceLineItem {
  final String label;
  final double amount;
  final String? description;

  const PriceLineItem({required this.label, required this.amount, this.description});
}

/// The fully transparent, per-unit price calculation the spec insists on:
/// never just "TOTAL: $500" — always the itemized path that produced it.
class PriceBreakdown {
  final List<PriceLineItem> materialLines; // Frame, Glass, Panel, Hardware, Accessories
  final double materialsSubtotal;
  final double labor;
  final double finishing;
  final double waste;
  final double overhead;
  final double subtotal; // cost basis before profit
  final double profit;
  final double unitPrice; // subtotal + profit — price for ONE unit
  final int quantity;
  final double lineTotal; // unitPrice * quantity
  final AppCurrency currency;

  const PriceBreakdown({
    required this.materialLines,
    required this.materialsSubtotal,
    required this.labor,
    required this.finishing,
    required this.waste,
    required this.overhead,
    required this.subtotal,
    required this.profit,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
    required this.currency,
  });

  String get formattedUnitPrice => currency.format(unitPrice);
  String get formattedLineTotal => currency.format(lineTotal);

  static const empty = PriceBreakdown(
    materialLines: [],
    materialsSubtotal: 0,
    labor: 0,
    finishing: 0,
    waste: 0,
    overhead: 0,
    subtotal: 0,
    profit: 0,
    unitPrice: 0,
    quantity: 1,
    lineTotal: 0,
    currency: AppCurrency.usd,
  );
}
