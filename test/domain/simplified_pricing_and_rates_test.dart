import 'dart:convert';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/l10n/app_localizations.dart';
import 'package:proframe/app/l10n/arb_words.dart';
import 'package:proframe/domain/dimensions/units.dart';
import 'package:proframe/domain/model/customer_discount.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/payment.dart';
import 'package:proframe/domain/pricing/colour_catalog.dart';
import 'package:proframe/domain/pricing/design_price_state.dart';
import 'package:proframe/domain/pricing/extra_catalog.dart';
import 'package:proframe/domain/pricing/extra_charge.dart';
import 'package:proframe/domain/pricing/price_list.dart';
import 'package:proframe/domain/pricing/price_list_fields.dart';
import 'package:proframe/domain/pricing/price_result.dart';
import 'package:proframe/domain/pricing/pricing_access.dart';
import 'package:proframe/domain/pricing/quotation.dart';
import 'package:proframe/domain/text/numerals.dart';
import 'package:proframe/domain/text/refusal.dart';
import 'package:proframe/domain/text/words.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/extra_catalog_store.dart';
import 'package:proframe/infrastructure/price_list_store.dart';
import 'package:proframe/infrastructure/staff_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pricing_engine_test.dart' show door, engine, glassCharged;

// Phase 35 in the domain: the factory's *Charge for glass*, the factory's
// list of extras, figures typed on a Kurdish keyboard, and refusals said in
// the language shown. None of it changes how anything already kept is
// priced, and none of it touches the geometry.

final kurdish = ArbWords(lookupAppLocalizations(const Locale('ckb')));

/// [door] with clear glass, included in its price, as `door` has it.
final glazed = door();

/// The geometry of [d], without anything about its price.
String geometryOf(Design d) {
  final json = d.toJson()
    ..remove('pricing')
    ..remove('createdAt')
    ..remove('updatedAt');
  return jsonEncode(json);
}

ExtraItem item(
  String name, {
  int cents = 300,
  String unit = 'bottle',
  String currency = 'USD',
  String id = '',
  bool active = true,
}) => ExtraItem(
  id: id.isEmpty ? 'item-${name.toLowerCase()}' : id,
  name: name,
  category: ExtraCategory.material,
  unit: unit,
  unitPriceCents: cents,
  currency: currency,
  updatedAt: DateTime(2026, 10, 12),
  active: active,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group("the factory's Charge for glass", () {
    test('is off for a new configuration: the example list and a list '
        'built without saying', () {
      expect(PriceList.starter.chargesGlass, isFalse);
      expect(
        PriceList(
          currency: 'USD',
          profiles: const {},
          glassPerM2: const {},
          panelPerM2: const {},
          hardwareEach: const {},
          categories: const {},
          installation: const InstallationRate(),
        ).chargesGlass,
        isFalse,
      );
    });

    test('off: the glass is measured and kept, and not charged, whatever '
        'the design says — and said to be off', () {
      final off = glassCharged.copyWith(chargesGlass: false);
      final r = engine.price(glazed, off);
      expect(r.isPriced, isTrue);
      expect(glazed.pricing.glassPriced, isTrue, reason: 'the design says on');
      expect(r.lines.where((l) => l.group == PriceGroup.glass), isEmpty);
      expect(r.measurements.glassArea.value, greaterThan(0));
      expect(r.glassState, GlassState.disabled);
      expect(r.glassCharging, isFalse);
      expect(geometryOf(glazed), geometryOf(door()), reason: 'no geometry');
    });

    test('on: charged where the design includes it, not where it does not; '
        'a design with no glass is charged none', () {
      final on = engine.price(glazed, glassCharged);
      expect(on.glassState, GlassState.charged);
      expect(on.sumOf(PriceGroup.glass), greaterThan(0));
      final notIncluded = engine.price(
        glazed.copyWith(pricing: glazed.pricing.copyWith(glassPriced: false)),
        glassCharged,
      );
      expect(notIncluded.glassState, GlassState.notIncluded);
      expect(
        notIncluded.total,
        closeTo(on.total! - on.sumOf(PriceGroup.glass), 1e-9),
      );
    });

    test('a list kept before the switch reads as on, and is written back '
        'exactly as it was — so no price kept against it goes stale', () {
      final old =
          jsonDecode(jsonEncode(glassCharged.toJson())) as Map<String, Object?>;
      expect(old.containsKey('chargesGlass'), isFalse);
      final read = PriceList.fromJson(old)!;
      expect(read.chargesGlass, isTrue);
      expect(jsonEncode(read.toJson()), jsonEncode(old));
      expect(
        PriceInputs.of(glazed, read),
        PriceInputs.of(glazed, glassCharged),
      );
      // And off is kept as off.
      final off = PriceList.fromJson(
        jsonDecode(jsonEncode(PriceList.starter.toJson())),
      )!;
      expect(off.chargesGlass, isFalse);
    });

    test('turning it on or off makes a kept price need recalculating, and a '
        'quotation keeps its figures', () {
      final record = PriceRecord.calculate(glazed, glassCharged)!;
      final off = glassCharged.copyWith(chargesGlass: false);
      expect(
        DesignPriceState.of(glazed, off, record).status,
        DesignPriceStatus.needsRecalculation,
      );
      final kept = PriceResult.fromJson(
        jsonDecode(jsonEncode(record.result.toJson())) as Map<String, Object?>,
      );
      expect(kept.total, record.result.total);
      expect(kept.glassState, GlassState.charged);
      // A price kept while the factory did not charge glass says so.
      final offRecord = PriceRecord.calculate(glazed, off)!;
      final back = PriceResult.fromJson(
        jsonDecode(jsonEncode(offRecord.result.toJson()))
            as Map<String, Object?>,
      );
      expect(back.glassState, GlassState.disabled);
      expect(Quotation, isNotNull);
    });

    test(
      'kept, read back and refused to anybody without pricing.edit',
      () async {
        final store = PriceListStore();
        final on = await store.save(
          PriceList.starter.copyWith(chargesGlass: true),
          by: WorkshopRole.owner,
        );
        expect(on.chargesGlass, isTrue);
        expect((await store.load()).chargesGlass, isTrue);
        expect(
          () => store.save(on, by: WorkshopRole.staff),
          throwsA(isA<AccessDenied>()),
        );
      },
    );

    test('the price editor says what each section of figures applies to, '
        'and which figures are money', () {
      final fields = RateField.of(PriceList.starter);
      expect(fields.every((f) => f.about != null), isTrue);
      final border = fields.firstWhere((f) => f.id == 'profile.upvc.normal');
      expect(border.about, contains('one rate for both'));
      expect(border.isMoney, isTrue);
      expect(
        fields.firstWhere((f) => f.id == 'sliding.rollersPerPanel').isMoney,
        isFalse,
      );
      expect(
        fields.firstWhere((f) => f.id.endsWith('special.percent')).isMoney,
        isFalse,
      );
      // In Kurdish, the same figures with their own words.
      final ckb = RateField.of(PriceList.starter, kurdish);
      expect(ckb.map((f) => f.id), fields.map((f) => f.id));
      expect(ckb.first.about, isNot(fields.first.about));
    });
  });

  group("the factory's list of extras", () {
    test('an item is a template: choosing one copies its name, unit and '
        'price into the charge, and the item changed afterwards changes '
        'nothing already added', () {
      final silicone = item('Silicone');
      final charge = silicone.chargeOf(
        id: 'EXT-1',
        quantityMilli: 5000,
        scope: ExtraScope.design,
        now: DateTime(2026, 10, 12),
      );
      expect(charge.totalCents, 1500);
      expect(charge.name, 'Silicone');
      expect(charge.unit, 'bottle');
      expect(charge.itemId, 'item-silicone');
      expect(
        charge.sum((c) => '${(c / 100).toStringAsFixed(2)} USD'),
        '5 bottles × 3.00 USD',
      );
      final dearer = silicone.copyWith(unitPriceCents: 400);
      expect(dearer.unitPriceCents, 400);
      expect(charge.totalCents, 1500, reason: 'copied, not referred to');
      final back = ExtraCharge.fromJson(
        jsonDecode(jsonEncode(charge.toJson())),
      );
      expect(back, charge);
      expect(back!.itemId, 'item-silicone');
    });

    test('where an extra came from says nothing of what it charges', () {
      final from = item('Silicone').chargeOf(
        id: 'EXT-1',
        quantityMilli: 5000,
        scope: ExtraScope.design,
        now: DateTime(2026, 10, 12),
      );
      final typed = ExtraCharge(
        id: 'EXT-1',
        name: 'Silicone',
        category: ExtraCategory.material,
        quantityMilli: 5000,
        unit: 'bottle',
        unitPriceCents: 300,
        currency: 'USD',
        scope: ExtraScope.design,
        createdAt: DateTime(2026, 10, 12),
        updatedAt: DateTime(2026, 10, 12),
      );
      PricingChoices with_(ExtraCharge e) =>
          glazed.pricing.copyWith(extras: [e]);
      expect(
        PriceInputs.ofDesign(glazed.copyWith(pricing: with_(from))),
        PriceInputs.ofDesign(glazed.copyWith(pricing: with_(typed))),
      );
    });

    test('a name, a unit and a price of nothing or more are needed, and no '
        'two active items share a name', () {
      final items = [item('Silicone')];
      expect(ExtraCatalog.problemWith(item(' '), items), isNotNull);
      expect(
        ExtraCatalog.problemWith(item('Tape', unit: ' '), items),
        isNotNull,
      );
      expect(
        ExtraCatalog.problemWith(item('Tape', cents: -1), items),
        isNotNull,
      );
      expect(
        ExtraCatalog.problemWith(item('SILICONE', id: 'item-other'), items),
        contains('already'),
      );
      expect(
        ExtraCatalog.problemWith(
          item('SILICONE', id: 'item-other'),
          items,
          kurdish,
        ),
        isNot(contains('already')),
      );
      expect(ExtraCatalog.problemWith(item('Tape'), items), isNull);
    });

    test('added, changed, retired and offered again; nothing deleted; ids '
        'never given twice', () {
      var items = ExtraCatalog.put(const [], item('Silicone')).items!;
      items = ExtraCatalog.put(items, item('Labour', unit: 'hour')).items!;
      expect(items.map((i) => i.name), ['Silicone', 'Labour']);
      items = ExtraCatalog.put(
        items,
        items.first.copyWith(unitPriceCents: 350),
      ).items!;
      expect(items.first.unitPriceCents, 350);
      expect(items, hasLength(2));
      items = ExtraCatalog.retire(items, 'item-silicone');
      expect(items, hasLength(2));
      expect(ExtraCatalog.offeredIn(items, 'USD').map((i) => i.name), [
        'Labour',
      ]);
      expect(ExtraCatalog.idFor('Silicone', items), 'item-silicone-2');
      // Its name taken meanwhile: not offered again until it is free.
      final taken = ExtraCatalog.put(
        items,
        item('Silicone', id: 'item-silicone-2'),
      ).items!;
      expect(ExtraCatalog.restore(taken, 'item-silicone').problem, isNotNull);
      final back = ExtraCatalog.restore(items, 'item-silicone').items!;
      expect(ExtraCatalog.offeredIn(back, 'USD'), hasLength(2));
    });

    test('only items in the price\'s own currency are offered', () {
      final items = [item('Silicone'), item('Glue', currency: 'EUR')];
      expect(ExtraCatalog.offeredIn(items, 'USD').map((i) => i.name), [
        'Silicone',
      ]);
    });

    test(
      'kept by its own store, read by anybody, changed only with '
      'pricing.edit — adding a charge to a design does not give it',
      () async {
        final store = ExtraCatalogStore();
        expect(await store.load(), isEmpty);
        final kept = await store.save([
          item('Silicone'),
        ], by: WorkshopRole.owner);
        expect(kept.single.name, 'Silicone');
        expect((await ExtraCatalogStore().load()).single.unitPriceCents, 300);

        await expectLater(
          store.save(const [], by: WorkshopRole.staff),
          throwsA(isA<AccessDenied>()),
        );
        expect(await store.load(), hasLength(1), reason: 'nothing written');

        final staff = StaffStore();
        final member = await staff.add(
          name: 'Dilan',
          pin: '2468',
          capabilities: {
            ...Capability.viewOnly,
            Capability.extrasCreate,
            Capability.extrasEdit,
          },
          by: WorkshopRole.owner,
        );
        expect(member.can(Capability.extrasCreate), isTrue);
        await expectLater(
          store.save(const [], by: member),
          throwsA(isA<AccessDenied>()),
        );
        expect(await store.load(), hasLength(1));
      },
    );

    test('a record that cannot be read is no items, and is not written over '
        'by reading it', () async {
      SharedPreferences.setMockInitialValues({ExtraCatalogStore.key: '{bad'});
      expect(await ExtraCatalogStore().load(), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ExtraCatalogStore.key), '{bad');
    });

    test('the catalog is apart from the price list: changing it makes no '
        'kept price need recalculating', () async {
      final record = PriceRecord.calculate(glazed, glassCharged)!;
      await ExtraCatalogStore().save([
        item('Silicone'),
      ], by: WorkshopRole.owner);
      expect(
        DesignPriceState.of(glazed, glassCharged, record).status,
        DesignPriceStatus.current,
      );
    });
  });

  group('figures typed on a Kurdish or Persian keyboard', () {
    test('are read as the figures they are, and shown in Latin digits', () {
      expect(Numerals.latin('١٢٣٤٥٦٧٨٩٠'), '1234567890');
      expect(Numerals.latin('۱۲۳۴۵۶۷۸۹۰'), '1234567890');
      expect(Numerals.latin('٣٫٢٥'), '3.25');
      expect(Numerals.latin('١٬٢٠٠'), '1,200');
      expect(Numerals.latin('Door 2'), 'Door 2', reason: 'nothing else moves');
    });

    test('every reader of a typed figure takes them', () {
      expect(Units.parse('١٢٠'), Units.parse('120'));
      expect(Units.parse('٩٦٫٤'), Units.parse('96.4'));
      expect(ExtraCharge.readQuantity('٥').value, 5000);
      expect(ExtraCharge.readPrice('٣٫٢٥').value, 325);
      expect(ExtraCharge.readPrice('١٬٢٠٠').value, 120000);
      expect(PaymentLedger.readAmount('٥٠٠٫٥٠').cents, 50050);
      expect(CustomerDiscount.readPercent('١٠').value, 1000);
      expect(ColourCatalog.readRate('١٫٥').value, 1.5);
    });

    test('and what is not a figure is still refused, never read as zero', () {
      expect(ExtraCharge.readPrice('٣٫٢٫٥').value, isNull);
      expect(ExtraCharge.readQuantity('-٥').value, isNull);
      expect(Units.parse('abc'), isNull);
      expect(PaymentLedger.readAmount('').cents, isNull);
    });
  });

  group('a refusal is said in the language shown', () {
    test('a member of staff called the same as another', () async {
      final staff = StaffStore();
      await staff.add(
        name: 'Dilan',
        pin: '2468',
        capabilities: Capability.viewOnly,
        by: WorkshopRole.owner,
      );
      Object? caught;
      try {
        await staff.add(
          name: 'dilan',
          pin: '1357',
          capabilities: Capability.viewOnly,
          by: WorkshopRole.owner,
        );
      } on Object catch (e) {
        caught = e;
      }
      expect(caught, isA<ArgumentError>(), reason: 'as it always was');
      final refusal = caught! as Refusal;
      expect(refusal.messageIn(const EnglishWords()), isNotEmpty);
      expect(
        refusal.messageIn(kurdish),
        isNot(refusal.messageIn(const EnglishWords())),
      );
    });

    test(
      'an extra that charges again for what the price already has',
      () async {
        final store = CustomerStore();
        final adam = await store.create(name: 'Adam', by: WorkshopRole.owner);
        final glass = engine
            .price(glazed, glassCharged)
            .lines
            .where((l) => l.group == PriceGroup.glass);
        Object? caught;
        try {
          await store.saveExtra(
            adam.id,
            ExtraCharge(
              id: 'EXT-1',
              name: 'Glass',
              category: ExtraCategory.material,
              quantityMilli: 1000,
              unit: 'piece',
              unitPriceCents: 500,
              currency: 'USD',
              scope: ExtraScope.customer,
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
            by: WorkshopRole.owner,
            calculated: glass,
          );
        } on Object catch (e) {
          caught = e;
        }
        expect(caught, isA<StateError>(), reason: 'as it always was');
        final refusal = caught! as StateRefusal;
        expect(refusal.messageIn(const EnglishWords()), contains('USD'));
        expect(
          refusal.messageIn(kurdish),
          isNot(refusal.messageIn(const EnglishWords())),
        );
      },
    );
  });
}
