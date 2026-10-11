import '../model/customer_discount.dart';
import '../model/design.dart';
import '../text/words.dart';
import 'extra_charge.dart';
import 'price_list.dart';
import 'price_result.dart';
import 'pricing_access.dart';
import 'pricing_engine.dart';
import 'profile_category.dart';

/// What a design's own price is made of beyond its geometry — its extras
/// and its discount — changed by somebody allowed to, and nothing else.
///
/// ```
/// design's own cost (automatic)  +  design's extras  −  design's discount
///                                                    =  design's price
/// ```
///
/// **Each change asks first, before anything is made** (`Authority.require`):
/// adding an extra needs `extras.create`, changing one `extras.edit`,
/// removing one `extras.delete`, giving or taking away the design's
/// discount `discounts.apply`, and including its glass or saying which
/// profile category its aluminium is `designs.edit` — they are how the
/// design is configured. A screen asking too only decides what to offer.
///
/// **Only the design's pricing choices change.** Not a line, a section, an
/// opening, a pane, a size or a finish: an extra is never geometry. The
/// design's kept price, if any, is then a previous calculation, because
/// what it was worked out from has changed (`PriceInputs`).
abstract final class DesignPricing {
  /// [design] with [extra] in it — added where it is new, in its place where
  /// it is already there by id — or why not.
  ///
  /// Where [extra] looks like something the design's price already works
  /// out from its geometry — its glass, its labour — in [calculated], it is
  /// kept only when [additional] says it is meant as a charge on top: the
  /// same glass is never charged twice by accident.
  static ({Design? design, String? problem}) putExtra(
    Design design,
    ExtraCharge extra, {
    required Authority by,
    Iterable<PriceLine> calculated = const [],
    bool additional = false,
    String Function(int cents)? money,
    Words words = const EnglishWords(),
  }) {
    final exists = design.pricing.extras.any((e) => e.id == extra.id);
    by.require(exists ? Capability.extrasEdit : Capability.extrasCreate);
    final problem =
        ExtraCharge.problemWith(
          name: extra.name,
          quantityMilli: extra.quantityMilli,
          unit: extra.unit,
          unitPriceCents: extra.unitPriceCents,
          words: words,
        ) ??
        _overlap(extra, calculated, additional, money, words);
    if (problem != null) return (design: null, problem: problem);
    return (
      design: design.copyWith(
        pricing: design.pricing.copyWith(
          extras: design.pricing.extras.withExtra(extra),
        ),
      ),
      problem: null,
    );
  }

  /// [design] without the extra [id].
  /// [design] with its glass charged for, or not. Nothing about the glass
  /// changes — not its area, not where it is — only whether the price
  /// includes it; turned on with no glass to measure, nothing is made up.
  static Design setGlassPriced(
    Design design,
    bool on, {
    required Authority by,
  }) {
    by.require(Capability.designsEdit);
    if (design.pricing.glassPriced == on) return design;
    return design.copyWith(pricing: design.pricing.copyWith(glassPriced: on));
  }

  /// [design] with its aluminium profile said to be [category] — every part
  /// of it, or, with [part], that one part (a frame member's or a bar's
  /// id). Null takes the choice away: the part follows the design again,
  /// or, for the design, nothing is chosen.
  ///
  /// Saying it for the whole design clears what single parts said, so the
  /// whole is what was asked for; a part said apart afterwards is kept.
  static Design setProfileCategory(
    Design design,
    ProfileCategory? category, {
    String? part,
    required Authority by,
  }) {
    by.require(Capability.designsEdit);
    final choices = design.pricing;
    if (part == null) {
      return design.copyWith(
        pricing: choices.copyWith(
          profileCategory: category,
          clearProfileCategory: category == null,
          profileCategoryOf: const {},
        ),
      );
    }
    final each = Map<String, ProfileCategory>.of(choices.profileCategoryOf);
    if (category == null) {
      each.remove(part);
    } else {
      each[part] = category;
    }
    return design.copyWith(pricing: choices.copyWith(profileCategoryOf: each));
  }

  static Design removeExtra(Design design, String id, {required Authority by}) {
    by.require(Capability.extrasDelete);
    if (design.pricing.extras.every((e) => e.id != id)) return design;
    return design.copyWith(
      pricing: design.pricing.copyWith(
        extras: design.pricing.extras.without(id),
      ),
    );
  }

  /// What [design] comes to before its own discount — its cost and its
  /// extras — in whole cents, priced from [list]; null where it cannot be
  /// priced.
  static int? subtotalCentsOf(
    Design design,
    PriceList list, {
    PricingEngine engine = const PricingEngine(),
  }) {
    final r = engine.price(
      design,
      list,
      choices: design.pricing.copyWith(clearDiscount: true),
    );
    return r.isPriced ? r.subtotalCents : null;
  }

  /// [design] with its own discount — [kind] at [value], a percentage in
  /// hundredths of a per cent or an amount in cents — or with none where
  /// [kind] is null; or why not. A fixed amount is checked against what
  /// the design comes to before the discount, from [list].
  static ({Design? design, String? problem}) setDiscount(
    Design design, {
    required DiscountKind? kind,
    required int? value,
    required PriceList list,
    required Authority by,
    required String Function(int cents) money,
    DateTime? at,
    Words words = const EnglishWords(),
  }) {
    by.require(Capability.discountsApply);
    if (kind == null) {
      return (
        design: design.copyWith(
          pricing: design.pricing.copyWith(clearDiscount: true),
        ),
        problem: null,
      );
    }
    final problem = CustomerDiscount.problemWith(
      kind: kind,
      value: value,
      subtotalCents: subtotalCentsOf(design, list),
      money: money,
      words: words,
    );
    if (problem != null) {
      // Said of one design, not of a customer's every design.
      return (
        design: null,
        problem: problem == words.discountNotFinal
            ? words.discountDesignNotFinal
            : problem,
      );
    }
    final discount = switch (kind) {
      DiscountKind.percent => Discount(
        percent: value! / 100,
        by: by.label,
        at: at ?? DateTime.now(),
      ),
      DiscountKind.fixed => Discount(
        amount: value! / 100,
        by: by.label,
        at: at ?? DateTime.now(),
      ),
    };
    return (
      design: design.copyWith(
        pricing: design.pricing.copyWith(discount: discount),
      ),
      problem: null,
    );
  }

  static String? _overlap(
    ExtraCharge extra,
    Iterable<PriceLine> calculated,
    bool additional,
    String Function(int cents)? money,
    Words w,
  ) {
    if (additional) return null;
    final same = ExtraCharge.alreadyCalculated(
      extra.name,
      extra.category,
      calculated,
    );
    if (same.isEmpty) return null;
    return ExtraCharge.alreadyCalculatedMessage(
      same,
      money ?? (c) => (c / 100).toStringAsFixed(2),
      w,
    );
  }
}
