import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/model/customer_discount.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/infill.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/pricing/design_price_state.dart';
import 'package:proframe/domain/pricing/design_pricing.dart';
import 'package:proframe/domain/pricing/extra_charge.dart';
import 'package:proframe/domain/pricing/price_list.dart';
import 'package:proframe/domain/pricing/price_result.dart';
import 'package:proframe/domain/pricing/pricing_access.dart';
import 'package:proframe/domain/pricing/quotation.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'financial_records_test.dart' show listAt, member, pricingOf, usd;
import 'payment_history_test.dart' show ledgerOf;
import 'pricing_engine_test.dart'
    show acceptance, door, engine, glassOverPanel, withProfile, zero;

// Phase 32: what a real factory job costs — what the design's own geometry
// costs (glass only where the design has glass), the extras the factory
// adds by hand (quantity × unit price), the design's own discount, the
// customer's extras and discount — and who may change each of them, asked
// by the stores and the services themselves.

final _now = DateTime(2026, 10, 5, 10);

/// An extra as the factory writes it.
ExtraCharge extra(
  String name,
  ExtraCategory category,
  String quantity,
  String unit,
  String price, {
  String id = 'EXT-1',
  String currency = 'USD',
  ExtraScope scope = ExtraScope.design,
}) => ExtraCharge(
  id: id,
  name: name,
  category: category,
  quantityMilli: ExtraCharge.readQuantity(quantity).value!,
  unit: unit,
  unitPriceCents: ExtraCharge.readPrice(price).value!,
  currency: currency,
  scope: scope,
  createdAt: _now,
  updatedAt: _now,
  by: 'Owner',
);

ExtraCharge silicone({String id = 'EXT-S', String quantity = '5'}) =>
    extra('Silicone', ExtraCategory.material, quantity, 'bottle', '3', id: id);

ExtraCharge labour({String id = 'EXT-L'}) =>
    extra('Labour', ExtraCategory.labour, '5', 'hour', '10', id: id);

/// [d] with [extras] put in by the owner.
Design withExtras(Design d, List<ExtraCharge> extras) {
  var out = d;
  for (final e in extras) {
    out = DesignPricing.putExtra(out, e, by: WorkshopRole.owner).design!;
  }
  return out;
}

/// The brief's acceptance price list on the acceptance design: profile
/// $200 (7.60 m × $20 normal, 6.00 m × $8 opening), the white panel $100
/// (1.893296 m² × $52.818), hardware $30 (four hinges at $5, a lever at $6,
/// a lock at $4) — and glass at $20 a square metre that the design, all
/// panel, never uses.
PriceList factoryList() =>
    withProfile(zero, MaterialKind.upvc, normal: 20, opening: 8).copyWith(
      panelPerM2: {...zero.panelPerM2, PanelColour.white: 52.818},
      glassPerM2: {for (final g in GlassLook.values) g: 20},
      sealedGlassPerM2: {for (final g in GlassLook.values) g: 20},
      hardwareEach: {
        ...zero.hardwareEach,
        HardwareKind.hinge: 5,
        HardwareKind.lever: 6,
        HardwareKind.lock: 4,
      },
    );

int cents(double v) => Money.cents(v);

String moneyOf(int c) => usd(c);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('48. the acceptance test: Front Entrance Door, glass not used', () {
    test('profile 200 + panel 100 + glass 0 + hardware 30 = 330; silicone '
        '5 × 3 = 15 and labour 5 × 10 = 50 make 65; 395 less 45 is 350', () {
      final list = factoryList();
      var d = acceptance().copyWith(name: 'Front Entrance Door');
      final base = engine.price(d, list);
      expect(base.isPriced, isTrue, reason: '${base.issues}');
      int group(PriceResult r, PriceGroup g) => cents(r.sumOf(g));
      expect(
        group(base, PriceGroup.normalProfile) +
            group(base, PriceGroup.openingProfile),
        20000,
      );
      expect(group(base, PriceGroup.panel), 10000);
      expect(group(base, PriceGroup.glass), 0, reason: 'no glass is used');
      expect(base.lines.where((l) => l.group == PriceGroup.glass), isEmpty);
      expect(base.measurements.glassArea.value, 0);
      expect(group(base, PriceGroup.hardware), 3000);
      expect(base.designCostCents, 33000);

      d = withExtras(d, [silicone(), labour()]);
      final s = d.pricing.extras.first;
      expect(s.totalCents, 1500);
      expect(s.sum(moneyOf), '5 bottles × 3.00 USD');
      expect(d.pricing.extras.last.totalCents, 5000);
      expect(d.pricing.extras.last.sum(moneyOf), '5 hours × 10.00 USD');

      final withExtrasPrice = engine.price(d, list);
      expect(withExtrasPrice.designCostCents, 33000);
      expect(withExtrasPrice.extrasCents, 6500);
      expect(withExtrasPrice.subtotalCents, 39500);

      final discounted = DesignPricing.setDiscount(
        d,
        kind: DiscountKind.fixed,
        value: 4500,
        list: list,
        by: WorkshopRole.owner,
        money: moneyOf,
        at: _now,
      );
      expect(discounted.problem, isNull);
      final priced = engine.price(discounted.design!, list);
      expect(priced.subtotalCents, 39500);
      expect(priced.discountCents, 4500);
      expect(priced.totalCents, 35000);
      // No hidden glass, and silicone and labour once each — never also a
      // line of the design's own cost.
      expect(priced.lines.where((l) => l.group == PriceGroup.glass), isEmpty);
      expect(priced.extras.where((e) => e.name == 'Silicone'), hasLength(1));
      expect(priced.extras.where((e) => e.name == 'Labour'), hasLength(1));
      expect(
        priced.lines.where(
          (l) => l.label.contains('Silicone') || l.label.contains('Labour'),
        ),
        isEmpty,
      );
      expect(priced.lines.where((l) => l.group == PriceGroup.labour), isEmpty);
    });
  });

  group('49. the second acceptance test: Adam, A 500 + B 400 + a trip', () {
    test('A 500 + B 400 + transport 1 trip × 30 = 930; less 30 is 900; the '
        'trip is no design\'s', () {
      final list = listAt(door: 500, window: 400);
      final a = door(id: 'a');
      final b = door(kind: DesignKind.window, id: 'b');
      final pricing = pricingOf([a, b], list);
      expect([for (final d in pricing.designs) d.state.total], [500, 400]);
      final trip = extra(
        'Transportation',
        ExtraCategory.transport,
        '1',
        'trip',
        '30',
        scope: ExtraScope.customer,
      );
      final f = CustomerFinance.of(
        pricing,
        ledgerOf(),
        discount: CustomerDiscount(
          id: 'DSC-1',
          kind: DiscountKind.fixed,
          value: 3000,
          currency: 'USD',
          at: _now,
          by: 'Owner',
        ),
        extras: [trip],
      );
      expect(f.designsCents, 90000);
      expect(f.extrasCents, 3000);
      expect(f.subtotalCents, 93000);
      expect(f.discountCents, 3000);
      expect(f.totalCents, 90000);
      // Neither design's price has the trip in it.
      for (final d in pricing.designs) {
        expect(d.state.record!.result.extras, isEmpty);
      }
    });
  });

  group('glass is optional', () {
    test('a design all panel has no glass, whatever the glass rate', () {
      final r = engine.price(acceptance(), factoryList());
      expect(r.measurements.glassArea.value, 0);
      expect(r.sumOf(PriceGroup.glass), 0);
      expect(r.lines.where((l) => l.group == PriceGroup.glass), isEmpty);
    });

    test('a design all glass has glass and no panel', () {
      final d = door();
      final r = engine.price(d, factoryList());
      expect(r.isPriced, isTrue, reason: '${r.issues}');
      expect(r.measurements.glassArea.value, greaterThan(0));
      expect(r.measurements.panelArea.value, 0);
      expect(r.sumOf(PriceGroup.glass), greaterThan(0));
      expect(r.lines.where((l) => l.group == PriceGroup.panel), isEmpty);
    });

    test('glass over panel: each by its own area, never half and half', () {
      final d = glassOverPanel(door());
      final r = engine.price(d, factoryList());
      expect(r.isPriced, isTrue, reason: '${r.issues}');
      final glass = r.measurements.glassArea.value;
      final panel = r.measurements.panelArea.value;
      expect(glass, greaterThan(0));
      expect(panel, greaterThan(0));
      expect(glass, isNot(closeTo(panel, 1e-6)), reason: 'not 50/50');
      final lines = r.lines.where((l) => l.group == PriceGroup.glass);
      expect(
        lines.fold<double>(0, (s, l) => s + l.quantity),
        closeTo(glass, 1e-9),
      );
    });

    test('a window is not charged glass for being a window, nor a door for '
        'having an opening', () {
      for (final kind in [DesignKind.window, DesignKind.door]) {
        var d = door(kind: kind, id: kind.name);
        for (final part in Infill.partsOf(d)) {
          d = d.withElement(part.copyWith(finish: PanelColour.white.finish));
        }
        final r = engine.price(d, factoryList());
        expect(r.isPriced, isTrue, reason: '${r.issues}');
        expect(d.openings, isNotEmpty);
        expect(r.measurements.glassArea.value, 0, reason: kind.name);
        expect(r.lines.where((l) => l.group == PriceGroup.glass), isEmpty);
      }
    });

    test('glass the design has is charged once; an extra for the same '
        'glass is refused unless it is said to be additional', () {
      final list = factoryList();
      final d = door();
      final r = engine.price(d, list);
      final glassLine = r.lines.firstWhere((l) => l.group == PriceGroup.glass);
      final again = extra('Glass', ExtraCategory.material, '1', 'piece', '50');
      final refused = DesignPricing.putExtra(
        d,
        again,
        by: WorkshopRole.owner,
        calculated: r.lines,
        money: moneyOf,
      );
      expect(refused.design, isNull);
      expect(refused.problem, contains('already calculated'));
      expect(refused.problem, contains('Glass'));
      expect(
        ExtraCharge.alreadyCalculated('Glass', ExtraCategory.material, [
          glassLine,
        ]),
        isNotEmpty,
      );
      final said = DesignPricing.putExtra(
        d,
        again,
        by: WorkshopRole.owner,
        calculated: r.lines,
        additional: true,
      );
      expect(said.design!.pricing.extras.single.name, 'Glass');
      // A design with no glass has no glass to charge twice.
      final panelOnly = engine.price(acceptance(), list);
      expect(
        ExtraCharge.alreadyCalculated(
          'Glass',
          ExtraCategory.material,
          panelOnly.lines,
        ),
        isEmpty,
      );
      // Labour is the category's own labour, where the list charges one.
      expect(
        ExtraCharge.alreadyCalculated('Help', ExtraCategory.labour, [
          PriceLine(
            group: PriceGroup.labour,
            label: 'Making',
            quantity: 1,
            unit: PriceUnit.fixed,
            rate: 20,
            amount: 20,
          ),
        ]),
        hasLength(1),
      );
    });
  });

  group('extras: quantity × unit price, exactly', () {
    test('silicone 5 × 3 = 15, labour 5 × 10 = 50, transport 1 × 20 = 20: '
        '85', () {
      final all = [
        silicone(),
        labour(),
        extra('Transport', ExtraCategory.transport, '1', 'trip', '20'),
      ];
      expect([for (final e in all) e.totalCents], [1500, 5000, 2000]);
      expect(all.totalCentsIn('USD'), 8500);
    });

    test('decimal quantities and prices, to the cent, half a cent up', () {
      expect(
        extra(
          'Tape',
          ExtraCategory.material,
          '2.5',
          'metre',
          '3.25',
        ).totalCents,
        813,
        reason: '2.5 × 3.25 = 8.125',
      );
      expect(
        extra(
          'Fitter',
          ExtraCategory.labour,
          '1.5',
          'hour',
          '12.75',
        ).totalCents,
        1913,
        reason: '1.5 × 12.75 = 19.125',
      );
      expect(
        extra(
          'Brackets',
          ExtraCategory.material,
          '0.333',
          'kg',
          '7.50',
        ).totalCents,
        250,
        reason: '0.333 × 7.50 = 2.4975',
      );
      // Ten of 0.10 is 1.00, never 0.9999…
      expect(
        extra(
          'Screws',
          ExtraCategory.material,
          '10',
          'piece',
          '0.10',
        ).totalCents,
        100,
      );
    });

    test('a custom item and a unit nobody predicted, with no code for '
        'either', () {
      final e = extra(
        'Special aluminium accessory',
        ExtraCategory.other,
        '2',
        'piece',
        '7.50',
      );
      expect(e.totalCents, 1500);
      final odd = extra('Sealant', ExtraCategory.material, '3', 'tube', '2');
      expect(odd.unitText, 'tube', reason: 'a typed unit, as typed');
      expect(odd.sum(moneyOf), '3 tube × 2.00 USD');
      expect(odd.totalCents, 600);
      expect(ExtraCharge.fromJson(jsonDecode(jsonEncode(odd.toJson()))), odd);
    });

    test('what cannot be an extra: no name, nothing, below nothing, a '
        'figure that is not one', () {
      expect(ExtraCharge.readQuantity('').problem, 'Enter the quantity.');
      expect(
        ExtraCharge.readQuantity('0').problem,
        'The quantity must be more than nothing.',
      );
      expect(
        ExtraCharge.readQuantity('-5').problem,
        'The quantity must be more than nothing.',
      );
      expect(ExtraCharge.readQuantity('five').problem, contains('number'));
      expect(ExtraCharge.readQuantity('1.2345').problem, contains('three'));
      expect(
        ExtraCharge.readPrice('-3').problem,
        'A unit price cannot be below nothing.',
      );
      expect(ExtraCharge.readPrice('3.255').problem, contains('cent'));
      expect(ExtraCharge.readPrice('0').value, 0, reason: 'free is a price');
      expect(
        ExtraCharge.problemWith(
          name: ' ',
          quantityMilli: 1000,
          unit: 'piece',
          unitPriceCents: 100,
        ),
        'Enter what the extra is.',
      );
      expect(
        ExtraCharge.problemWith(
          name: 'Silicone',
          quantityMilli: 0,
          unit: 'bottle',
          unitPriceCents: 300,
        ),
        'The quantity must be more than nothing.',
      );
      expect(
        ExtraCharge.problemWith(
          name: 'Silicone',
          quantityMilli: 1000,
          unit: 'bottle',
          unitPriceCents: -1,
        ),
        'A unit price cannot be below nothing.',
      );
      // A kept extra that is not one is no extra, never a made-up charge.
      expect(
        ExtraCharge.fromJson({...silicone().toJson(), 'quantityMilli': -5000}),
        isNull,
      );
      expect(ExtraCharge.fromJson({'name': 'Silicone'}), isNull);
    });

    test('edited: 5 bottles become 6, and 15 becomes 18; removed, it is '
        'gone from the price', () {
      final list = factoryList();
      var d = withExtras(acceptance(), [silicone()]);
      expect(engine.price(d, list).extrasCents, 1500);
      final six = silicone(quantity: '6');
      d = DesignPricing.putExtra(d, six, by: WorkshopRole.owner).design!;
      expect(d.pricing.extras, hasLength(1), reason: 'changed, not added');
      expect(engine.price(d, list).extrasCents, 1800);
      d = DesignPricing.removeExtra(d, six.id, by: WorkshopRole.owner);
      expect(d.pricing.extras, isEmpty);
      expect(engine.price(d, list).extrasCents, 0);
      expect(engine.price(d, list).subtotalCents, 33000);
    });

    test('categories are labels; the sum is the same for every one', () {
      for (final c in ExtraCategory.values) {
        final e = extra('Thing', c, '4', 'piece', '2.50');
        expect(e.totalCents, 1000, reason: c.name);
        expect(ExtraCategory.byName(c.name), c);
        expect(ExtraCharge.fromJson(e.toJson())!.category, c);
      }
      expect(ExtraCategory.byName('something later'), ExtraCategory.other);
    });

    test('an extra in another currency is never added: it stops the price '
        'and is said', () {
      final d = withExtras(acceptance(), [
        extra(
          'Ferry',
          ExtraCategory.transport,
          '1',
          'trip',
          '15',
          currency: 'EUR',
        ),
      ]);
      final r = engine.price(d, factoryList());
      expect(r.isPriced, isFalse);
      expect(r.issues.first.message, contains('EUR'));
      expect(r.issues.first.message, contains('USD'));
      final pricing = pricingOf([door(id: 'a')], listAt(door: 500));
      final f = CustomerFinance.of(
        pricing,
        ledgerOf(),
        extras: [
          extra(
            'Ferry',
            ExtraCategory.transport,
            '1',
            'trip',
            '15',
            currency: 'EUR',
            scope: ExtraScope.customer,
          ),
        ],
      );
      expect(f.extrasCents, 0);
      expect(f.subtotalCents, isNull, reason: 'not final, never 515');
      expect(f.notFinalReason, contains('EUR'));
    });

    test('nothing in the engine knows silicone, labour, transport or '
        'installation by name — every extra is an ExtraCharge', () {
      for (final f in Directory('lib/domain/pricing').listSync()) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        // The code, not what its comments say about what a user types.
        final text = [
          for (final line in f.readAsLinesSync())
            if (!line.trimLeft().startsWith('//')) line,
        ].join('\n').toLowerCase();
        for (final word in [
          'silicone',
          'transportprice',
          'labourprice',
          'laborprice',
          'installationprice',
        ]) {
          expect(text.contains(word), isFalse, reason: '${f.path}: $word');
        }
      }
    });
  });

  group('discounts and their order', () {
    test('design: cost + extras − its discount; customer: designs + its '
        'extras − its discount; nothing taken off twice', () {
      final list = listAt(door: 600, window: 400);
      var a = door(id: 'a');
      a = withExtras(a, [silicone(), labour()]); // 600 + 65 = 665
      a = DesignPricing.setDiscount(
        a,
        kind: DiscountKind.percent,
        value: 1000, // 10% of 665 = 66.50
        list: list,
        by: WorkshopRole.owner,
        money: moneyOf,
      ).design!;
      final ra = engine.price(a, list);
      expect(ra.subtotalCents, 66500);
      expect(ra.discountCents, 6650);
      expect(ra.totalCents, 59850);
      final b = door(kind: DesignKind.window, id: 'b');
      final pricing = pricingOf([a, b], list);
      final f = CustomerFinance.of(
        pricing,
        ledgerOf(payments: [100]),
        discount: CustomerDiscount(
          id: 'DSC-1',
          kind: DiscountKind.percent,
          value: 1000,
          at: _now,
          by: 'Owner',
        ),
        extras: [
          extra(
            'Delivery',
            ExtraCategory.transport,
            '1',
            'trip',
            '30',
            scope: ExtraScope.customer,
          ),
        ],
      );
      // 598.50 + 400 + 30 = 1,028.50; 10% is 102.85; 925.65; less 100 paid.
      expect(f.designsCents, 99850);
      expect(f.subtotalCents, 102850);
      expect(f.discountCents, 10285);
      expect(f.totalCents, 92565);
      expect(f.dueCents, 82565);
    });

    test('the design discount: none, a percentage, a fixed amount — '
        'checked as the customer\'s is', () {
      final list = factoryList();
      final d = acceptance();
      ({Design? design, String? problem}) give(DiscountKind? k, int? v) =>
          DesignPricing.setDiscount(
            d,
            kind: k,
            value: v,
            list: list,
            by: WorkshopRole.owner,
            money: moneyOf,
          );
      expect(give(DiscountKind.percent, 0).problem, contains('more than'));
      expect(give(DiscountKind.percent, 10001).problem, contains('100%'));
      expect(
        give(DiscountKind.fixed, 33001).problem,
        contains('more than the subtotal'),
      );
      expect(give(DiscountKind.fixed, 33000).problem, isNull);
      final ten = give(DiscountKind.percent, 1000).design!;
      expect(engine.price(ten, list).discountCents, 3300);
      expect(ten.pricing.discount!.by, 'Owner');
      final none = DesignPricing.setDiscount(
        ten,
        kind: null,
        value: null,
        list: list,
        by: WorkshopRole.owner,
        money: moneyOf,
      ).design!;
      expect(none.pricing.discount, isNull);
      expect(engine.price(none, list).totalCents, 33000);
    });

    test('who gave a discount and when, or who wrote an extra, does not make '
        'the price stale — what it charges does', () {
      final list = factoryList();
      final d = withExtras(acceptance(), [silicone()]);
      final record = PriceRecord.calculate(d, list)!;
      final reNoted = DesignPricing.putExtra(
        d,
        silicone().copyWith(
          by: 'Rawa',
          updatedAt: _now.add(const Duration(hours: 1)),
          note: 'the clear one',
        ),
        by: WorkshopRole.owner,
      ).design!;
      expect(DesignPriceState.of(reNoted, list, record).isCurrent, isTrue);
      final more = DesignPricing.putExtra(
        d,
        silicone(quantity: '7'),
        by: WorkshopRole.owner,
      ).design!;
      expect(
        DesignPriceState.of(more, list, record).status,
        DesignPriceStatus.needsRecalculation,
      );
    });
  });

  group('quotations keep the extras as they were', () {
    test('44 again, with extras: a quotation of 1,000 + 15 + 50 less 65 is '
        '1,000, and stays so after silicone becomes 4 a bottle', () {
      final list = listAt(door: 1000);
      final d = withExtras(door(id: 'a'), [silicone()]);
      final pricing = pricingOf([d], list);
      final made = Quotation.build(
        customerId: 'adam',
        customerName: 'Adam',
        chosen: pricing.designs,
        currency: 'USD',
        number: 1,
        now: _now,
        by: 'Owner',
        money: usd,
        extras: [
          extra(
            'Labour',
            ExtraCategory.labour,
            '5',
            'hour',
            '10',
            scope: ExtraScope.customer,
          ),
        ],
        discount: CustomerDiscount(
          id: 'DSC-1',
          kind: DiscountKind.fixed,
          value: 6500,
          currency: 'USD',
          at: _now,
          by: 'Owner',
        ),
      );
      final q = made.quotation!;
      expect(q.designsCents, 101500, reason: '1,000 and its silicone');
      expect(q.extrasCents, 5000);
      expect(q.subtotalCents, 106500);
      expect(q.discountCents, 6500);
      expect(q.totalCents, 100000);

      // Kept and read back, then the silicone changed: the quotation is as
      // it was.
      final kept = Quotation.fromJson(jsonDecode(jsonEncode(q.toJson())))!;
      final dearer = DesignPricing.putExtra(
        d,
        extra(
          'Silicone',
          ExtraCategory.material,
          '6',
          'bottle',
          '4',
          id: 'EXT-S',
        ),
        by: WorkshopRole.owner,
      ).design!;
      expect(engine.price(dearer, list).extrasCents, 2400);
      final line = kept.lines.single.result.extras.single;
      expect(line.quantityMilli, 5000);
      expect(line.unitPriceCents, 300);
      expect(line.sum(usd), '5 bottles × 3.00 USD');
      expect(kept.extras.single.totalCents, 5000);
      expect(kept.totalCents, 100000);
      expect(
        kept.changedDesigns({'a': PriceInputs.ofDesign(dearer)}),
        hasLength(1),
        reason: 'said to have changed, and not rewritten',
      );
    });

    test('a quotation kept before extras reads as it was', () {
      final q = Quotation.fromJson({
        'number': 3,
        'customerId': 'adam',
        'createdAt': _now.toIso8601String(),
        'updatedAt': _now.toIso8601String(),
        'status': 'draft',
        'currency': 'USD',
        'lines': <Object?>[],
        'subtotalCents': 50000,
        'totalCents': 50000,
      })!;
      expect(q.extras, isEmpty);
      expect(q.designsCents, 50000);
      expect(q.extrasCents, 0);
    });
  });

  group('kept', () {
    test('a design\'s extras through a save and a reload', () async {
      final d = withExtras(acceptance(), [silicone(), labour()]);
      final store = DesignStore();
      await store.save(d, by: WorkshopRole.owner);
      final back = (await DesignStore().load(d.id))!;
      expect(back.pricing.extras, d.pricing.extras);
      expect(back.pricing.extras.first.sum(usd), '5 bottles × 3.00 USD');
      expect(back.pricing.extras.first.createdAt, _now);
    });

    test('a customer\'s extras: added, changed, taken off — and never put '
        'back by a copy read before', () async {
      final store = CustomerStore();
      final adam = await store.create(
        name: 'Adam',
        now: _now,
        by: WorkshopRole.owner,
      );
      final trip = extra(
        'Transport',
        ExtraCategory.transport,
        '1',
        'trip',
        '30',
        id: 'EXT-T',
        scope: ExtraScope.customer,
      );
      await store.saveExtra(adam.id, trip, by: WorkshopRole.owner);
      expect((await store.load(adam.id))!.extras.single.totalCents, 3000);
      // A copy read before the trip, saved after: the trip stays.
      await store.save(adam.copyWith(phone: '0750'), by: WorkshopRole.owner);
      final now = (await store.load(adam.id))!;
      expect(now.extras, [trip]);
      expect(now.phone, '0750');
      final two = trip.copyWith(quantityMilli: 2000);
      await store.saveExtra(adam.id, two, by: WorkshopRole.owner);
      expect((await store.load(adam.id))!.extras.single.totalCents, 6000);
      // A copy read with the trip, saved after it was taken off: it stays
      // off.
      final withTrip = (await store.load(adam.id))!;
      await store.takeExtraOff(adam.id, trip.id, by: WorkshopRole.owner);
      await store.save(
        withTrip.copyWith(notes: 'gate code 12'),
        by: WorkshopRole.owner,
      );
      expect((await store.load(adam.id))!.extras, isEmpty);
    });

    test('a customer extra that duplicates a calculated cost is refused '
        'unless it is additional', () async {
      final store = CustomerStore();
      final adam = await store.create(name: 'Adam', by: WorkshopRole.owner);
      final glassLine = engine
          .price(door(), factoryList())
          .lines
          .where((l) => l.group == PriceGroup.glass);
      final glass = extra(
        'Glass',
        ExtraCategory.material,
        '1',
        'piece',
        '5',
        scope: ExtraScope.customer,
      );
      await expectLater(
        store.saveExtra(
          adam.id,
          glass,
          by: WorkshopRole.owner,
          calculated: glassLine,
        ),
        throwsStateError,
      );
      expect((await store.load(adam.id))!.extras, isEmpty);
      await store.saveExtra(
        adam.id,
        glass,
        by: WorkshopRole.owner,
        calculated: glassLine,
        additional: true,
      );
      expect((await store.load(adam.id))!.extras, hasLength(1));
    });

    test('extras never move geometry, and a design price writes nothing '
        'into a payment', () {
      final d = acceptance();
      final e = withExtras(d, [silicone(), labour()]);
      Map<String, Object?> geometry(Design x) => Map.of(x.toJson())
        ..remove('pricing')
        ..remove('updatedAt');
      expect(jsonEncode(geometry(e)), jsonEncode(geometry(d)));
      expect(e.sections.length, d.sections.length);
      expect(e.dividers.length, d.dividers.length);
    });
  });

  group('permissions', () {
    final cashier = member('Cashier', {
      ...Capability.viewOnly,
      Capability.paymentsCreate,
    });
    final fitter = member('Fitter', {
      ...Capability.viewOnly,
      Capability.extrasCreate,
    });

    test('extras: added only with extras.create, changed only with '
        'extras.edit, removed only with extras.delete', () {
      final d = acceptance();
      expect(
        () => DesignPricing.putExtra(d, silicone(), by: cashier),
        throwsA(isA<AccessDenied>()),
      );
      final added = DesignPricing.putExtra(d, silicone(), by: fitter).design!;
      expect(
        () =>
            DesignPricing.putExtra(added, silicone(quantity: '6'), by: fitter),
        throwsA(isA<AccessDenied>()),
        reason: 'adding is not changing',
      );
      expect(
        () => DesignPricing.removeExtra(added, 'EXT-S', by: fitter),
        throwsA(isA<AccessDenied>()),
      );
      expect(
        () => DesignPricing.removeExtra(
          added,
          'EXT-S',
          by: const NobodySignedIn(),
        ),
        throwsA(isA<AccessDenied>()),
      );
      expect(
        DesignPricing.removeExtra(
          added,
          'EXT-S',
          by: WorkshopRole.owner,
        ).pricing.extras,
        isEmpty,
      );
      expect(
        () => DesignPricing.setDiscount(
          d,
          kind: DiscountKind.percent,
          value: 1000,
          list: factoryList(),
          by: WorkshopRole.staff,
          money: moneyOf,
        ),
        throwsA(isA<AccessDenied>()),
        reason: 'a discount is the owner\'s unless given',
      );
    });

    test('customers: added only with customers.create, edited only with '
        'customers.edit — by the store itself', () async {
      final store = CustomerStore();
      await expectLater(
        store.create(name: 'Adam', by: cashier),
        throwsA(isA<AccessDenied>()),
      );
      await expectLater(
        store.create(name: 'Adam', by: const NobodySignedIn()),
        throwsA(isA<AccessDenied>()),
      );
      expect(await store.count(), 0, reason: 'nothing was written');
      final adam = await store.create(name: 'Adam', by: WorkshopRole.owner);
      await expectLater(
        store.save(adam.copyWith(phone: '1'), by: cashier),
        throwsA(isA<AccessDenied>()),
      );
      expect((await store.load(adam.id))!.phone, '');
      final clerk = member('Clerk', {
        ...Capability.viewOnly,
        Capability.customersEdit,
      });
      await store.save(adam.copyWith(phone: '1'), by: clerk);
      expect((await store.load(adam.id))!.phone, '1');
      // A design kept for somebody nobody has made makes a customer: that
      // needs customers.create too.
      await expectLater(
        DesignStore().save(
          door(id: 'x').copyWith(customer: 'Sara'),
          by: member('Drafter', {
            ...Capability.viewOnly,
            Capability.designsCreate,
          }),
        ),
        throwsA(isA<AccessDenied>()),
      );
      expect(await store.named('Sara'), isNull);
    });

    test('designs: created, edited, deleted, duplicated and renamed only '
        'with their own capability', () async {
      final designs = DesignStore();
      final customers = CustomerStore();
      final adam = await customers.create(name: 'Adam', by: WorkshopRole.owner);
      final d = door(id: 'front').copyWith(customerId: adam.id);
      await expectLater(
        designs.save(d, by: cashier),
        throwsA(isA<AccessDenied>()),
      );
      expect(await designs.load('front'), isNull);
      final drafter = member('Drafter', {
        ...Capability.viewOnly,
        Capability.designsCreate,
      });
      await designs.save(d, by: drafter);
      expect(await designs.load('front'), isNotNull);
      // Created, then changed: editing is its own capability.
      await expectLater(
        designs.save(d.copyWith(name: 'Back door'), by: drafter),
        throwsA(isA<AccessDenied>()),
      );
      await expectLater(
        designs.retitle('front', 'Back door', by: drafter),
        throwsA(isA<AccessDenied>()),
      );
      expect((await designs.load('front'))!.name, d.name);
      await expectLater(
        designs.remove('front', by: drafter),
        throwsA(isA<AccessDenied>()),
      );
      await expectLater(
        designs.duplicate('front', by: cashier),
        throwsA(isA<AccessDenied>()),
      );
      expect(await designs.count(), 1);
      // The design's pricing alone — an extra put in by somebody who may
      // add one — is kept without designs.edit.
      final priced = DesignPricing.putExtra(
        (await designs.load('front'))!,
        silicone(),
        by: fitter,
      ).design!;
      await designs.save(priced, by: fitter);
      expect((await designs.load('front'))!.pricing.extras, hasLength(1));
      // …but nothing else rides along with it.
      await expectLater(
        designs.save(priced.copyWith(name: 'Sneaked'), by: fitter),
        throwsA(isA<AccessDenied>()),
      );
      await designs.remove('front', by: WorkshopRole.owner);
      expect(await designs.count(), 0);
    });

    test('the owner may do everything; the device with no staff accounts '
        'what it always could, and extras; nobody signed in only looks', () {
      for (final c in Capability.values) {
        expect(WorkshopRole.owner.can(c), isTrue, reason: c.key);
      }
      for (final c in [
        Capability.customersView,
        Capability.customersCreate,
        Capability.customersEdit,
        Capability.designsView,
        Capability.designsCreate,
        Capability.designsEdit,
        Capability.designsDelete,
        Capability.extrasCreate,
        Capability.extrasEdit,
        Capability.extrasDelete,
      ]) {
        expect(WorkshopRole.staff.can(c), isTrue, reason: c.key);
      }
      expect(WorkshopRole.staff.can(Capability.discountsApply), isFalse);
      expect(const NobodySignedIn().can(Capability.customersView), isTrue);
      expect(const NobodySignedIn().can(Capability.designsView), isTrue);
      for (final c in [
        Capability.customersCreate,
        Capability.customersEdit,
        Capability.designsCreate,
        Capability.designsEdit,
        Capability.designsDelete,
        Capability.extrasCreate,
      ]) {
        expect(const NobodySignedIn().can(c), isFalse, reason: c.key);
      }
      // A member of staff taken off Active may do nothing.
      final off = member('Off', Capability.standard, active: false);
      expect(off.can(Capability.designsEdit), isFalse);
      // There is no permission to delete a customer, because nobody can.
      expect(Capability.byKey('customers.delete'), isNull);
    });
  });
}
