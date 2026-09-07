import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/pricing/currency.dart';
import 'package:proframe/domain/pricing/price_breakdown.dart';
import 'package:proframe/shared/widgets/price_breakdown_view.dart';

void main() {
  testWidgets('PriceBreakdownView renders every material line and the unit price', (tester) async {
    const breakdown = PriceBreakdown(
      materialLines: [
        PriceLineItem(label: 'Frame', amount: 92.6, description: '6.2 m × Aluminum'),
        PriceLineItem(label: 'Glass', amount: 67.2, description: '2.1 m² × Clear'),
      ],
      materialsSubtotal: 159.8,
      labor: 16.0,
      finishing: 0,
      waste: 8.8,
      overhead: 14.1,
      subtotal: 198.7,
      profit: 39.7,
      unitPrice: 238.4,
      quantity: 2,
      lineTotal: 476.8,
      currency: AppCurrency.usd,
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PriceBreakdownView(breakdown: breakdown))),
    );

    expect(find.text('Frame'), findsOneWidget);
    expect(find.text('Glass'), findsOneWidget);
    expect(find.text('Unit price'), findsOneWidget);
    expect(find.text(r'$238.40'), findsOneWidget);
    expect(find.textContaining('× 2 units'), findsOneWidget);
  });
}
