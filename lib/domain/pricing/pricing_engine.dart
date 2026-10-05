import '../model/design.dart';
import '../model/materials.dart';
import 'measurement.dart';
import 'price_list.dart';
import 'price_readiness.dart';
import 'price_result.dart';
import 'takeoff.dart';

/// Prices a design: the design and the price list in, a [PriceResult] out.
///
/// ```
/// Design ─ PricingTakeoff ─ CategoryPricing ─ lines ─ labour,
///        (canonical          (each measurement        installation,
///         geometry,           at its own rate)        discount
///         read only)                                       │
///                                                     PriceResult
///                                              (measurements + breakdown)
/// ```
///
/// **It reads and never writes.** The design goes in and comes out exactly
/// as it was: nothing is drawn, squared, measured afresh or stored. The
/// only figures it multiplies are the price list's.
///
/// **A category is priced by the strategy registered for it**, by name, and
/// a category with none — or with no rate in the price list — is not priced
/// at all: it is never priced as a window or as anything else it is not.
/// A later category is added by registering its strategy and giving the
/// price list its rate; nothing already here changes.
class PricingEngine {
  final Map<String, CategoryPricing> strategies;

  const PricingEngine([this.strategies = standard]);

  /// The strategies for the five categories this version has. Door, window
  /// and door & window differ in the design — which openings it has, and
  /// what each is — not in a rule, so they share one; a sliding design adds
  /// the rollers its panels run on.
  static const Map<String, CategoryPricing> standard = {
    'door': FramedPricing(),
    'window': FramedPricing(),
    'both': FramedPricing(),
    'sliding': SlidingPricing(),
    'angled': FramedPricing(),
  };

  /// The name [design]'s category is priced under: its own, or — for one
  /// this version does not know — the name it was saved with, where that is
  /// a name at all.
  static String categoryOf(Design design) {
    if (!design.isUnsupported) return design.kind.name;
    final saved = design.savedCategory;
    return saved is String ? saved : '';
  }

  /// [design] priced from [list]. [choices] are the design's own unless
  /// given.
  PriceResult price(Design design, PriceList list, {PricingChoices? choices}) {
    final said = choices ?? design.pricing;
    final category = categoryOf(design);
    PriceResult unavailable(PriceStatus status, String why) =>
        PriceResult.unavailable(
          status,
          why,
          currency: list.currency,
          category: category,
          priceListVersion: list.version,
        );

    final strategy = design.isUnsupported ? null : strategies[category];
    if (strategy == null) {
      return unavailable(
        PriceStatus.unsupportedCategory,
        'This version of ProFrame cannot price a design of this category.',
      );
    }
    final rate = list.categories[category];
    if (rate == null) {
      return unavailable(
        PriceStatus.notConfigured,
        'The price list has no prices for ${design.kind.label} designs.',
      );
    }
    // Nothing is priced that is not complete: the one answer every screen
    // reads, so the engine cannot price what a button says cannot be.
    final readiness = PriceReadiness.of(design);
    if (!readiness.isPriceCalculable) {
      return unavailable(
        switch (readiness.missing.first.kind) {
          PriceRequirementKind.unsupportedCategory =>
            PriceStatus.unsupportedCategory,
          PriceRequirementKind.notRead => PriceStatus.notRead,
          PriceRequirementKind.frame => PriceStatus.nothingToPrice,
          PriceRequirementKind.geometry => PriceStatus.invalid,
          PriceRequirementKind.sizes => PriceStatus.needsSizes,
          _ => PriceStatus.incomplete,
        },
        readiness.message,
      );
    }

    final takeoff = PricingTakeoff.of(design);
    final sheet = PriceSheet(list);
    strategy.price(takeoff, sheet);

    // Labour, by the category's own rate.
    final made = sheet.lines.fold<double>(0, (sum, l) => sum + l.amount);
    final labour = rate.labour;
    sheet
      ..add(PriceGroup.labour, 'Making', 1, PriceUnit.fixed, labour.fixed)
      ..add(
        PriceGroup.labour,
        'Making, by area',
        takeoff.area.value,
        PriceUnit.squareMetre,
        labour.perSquareMetre,
      )
      ..addPercent(
        PriceGroup.labour,
        'Making, on materials',
        labour.percent,
        made,
      );

    // Installation, only where the user asked for it.
    if (said.installation) {
      final fit = list.installation;
      sheet
        ..add(
          PriceGroup.installation,
          'Installation',
          1,
          PriceUnit.fixed,
          fit.fixed,
        )
        ..add(
          PriceGroup.installation,
          'Installation, by area',
          takeoff.area.value,
          PriceUnit.squareMetre,
          fit.perSquareMetre,
        );
    }

    final blocking = sheet.issues.where((i) => i.blocking).toList();
    return PriceResult(
      status: blocking.isEmpty ? PriceStatus.priced : PriceStatus.notConfigured,
      currency: list.currency,
      category: category,
      priceListVersion: list.version,
      lines: sheet.lines,
      issues: sheet.issues,
      discount: said.discount,
      measurements: takeoff.summary,
    );
  }
}

/// Where a strategy writes its lines, with the price list it reads.
///
/// A line with nothing to charge — a quantity of nothing, a rate of
/// nothing — is not written, and an amount that is not a number is never
/// written: what comes out is always a finite price no less than nothing.
class PriceSheet {
  final PriceList list;
  final lines = <PriceLine>[];
  final issues = <PriceIssue>[];

  PriceSheet(this.list);

  void add(
    PriceGroup group,
    String label,
    double quantity,
    PriceUnit unit,
    double rate, {
    String? partId,
  }) {
    if (!quantity.isFinite || !rate.isFinite || quantity <= 0 || rate <= 0) {
      return;
    }
    lines.add(
      PriceLine(
        group: group,
        label: label,
        quantity: quantity,
        unit: unit,
        rate: rate,
        // Charged to the cent here, once; only cents are added after.
        amount: quantity * rate,
        partId: partId,
      ),
    );
  }

  void addPercent(
    PriceGroup group,
    String label,
    double percent,
    double of, {
    String? partId,
  }) {
    if (!percent.isFinite || !of.isFinite || percent <= 0 || of <= 0) return;
    lines.add(
      PriceLine(
        group: group,
        label: label,
        quantity: percent,
        unit: PriceUnit.percent,
        rate: of,
        amount: of * percent / 100,
        partId: partId,
      ),
    );
  }

  /// Something the price list has no price for: the design cannot be
  /// priced until it has.
  void missing(String what) {
    final message = 'The price list has no price for $what.';
    if (issues.every((i) => i.message != message)) {
      issues.add(PriceIssue(message));
    }
  }

  /// What [group]'s lines come to: their cents, summed.
  double sumOf(PriceGroup group) =>
      lines
          .where((l) => l.group == group)
          .fold(0, (sum, l) => sum + l.amountCents) /
      100;
}

/// What a category charges for. One per category, registered with the
/// engine by name; the rates are the price list's.
abstract class CategoryPricing {
  const CategoryPricing();

  void price(PricingTakeoff takeoff, PriceSheet sheet);
}

/// A framed design, the factory's way: each measurement at its own rate.
///
/// - **Normal profile** — the frame's border and every bar and line, each
///   in its own material — by the metre at that material's normal rate.
/// - **Opening profile** — round each opening, in the frame's material —
///   by the metre at that material's opening rate. Never the normal rate,
///   and never added into the normal profile.
/// - **Colour** — what each colour on each material adds, by the metre of
///   profile in it and as a share of that profile's price.
/// - **Glass** by its look and **panel** by its colour, each by the square
///   metre as cut.
/// - **Hardware**, every piece the design carries, counted.
/// - **Other profile** — a sliding track — by the metre.
class FramedPricing extends CategoryPricing {
  const FramedPricing();

  @override
  void price(PricingTakeoff takeoff, PriceSheet sheet) {
    final list = sheet.list;

    // Profile, by material and use; and by material and colour for what
    // the colour adds.
    // Lengths are added as the millimetres they are kept in, so every sum
    // is exact; a length becomes metres only where it is multiplied.
    final normal = <MaterialKind, Metres>{};
    final opening = <MaterialKind, Metres>{};
    final byColour = <(MaterialKind, int), ({Metres metres, double cost})>{};
    var track = Metres.zero;
    for (final run in takeoff.runs) {
      final metres = run.length;
      if (run.use == ProfileUse.track) {
        track += metres;
        continue;
      }
      final material = run.finish.material;
      final profile = list.profiles[material];
      if (profile == null) {
        sheet.missing('${material.label} profile');
        continue;
      }
      final isOpening = run.use == ProfileUse.opening;
      final into = isOpening ? opening : normal;
      into[material] = (into[material] ?? Metres.zero) + metres;
      final rate = isOpening ? profile.openingPerMetre : profile.normalPerMetre;
      final key = (material, run.finish.colour);
      final was = byColour[key] ?? (metres: Metres.zero, cost: 0.0);
      byColour[key] = (
        metres: was.metres + metres,
        cost: was.cost + metres.value * rate,
      );
    }
    for (final MapEntry(key: m, value: metres) in normal.entries) {
      sheet.add(
        PriceGroup.normalProfile,
        'Normal profile — ${m.label}',
        metres.value,
        PriceUnit.metre,
        list.profiles[m]!.normalPerMetre,
      );
    }
    for (final MapEntry(key: m, value: metres) in opening.entries) {
      sheet.add(
        PriceGroup.openingProfile,
        'Opening profile — ${m.label}',
        metres.value,
        PriceUnit.metre,
        list.profiles[m]!.openingPerMetre,
      );
    }
    for (final MapEntry(key: (m, colour), value: used) in byColour.entries) {
      final rate = list.profiles[m]!.colourOf(colour);
      final what =
          '${rate.name} ${m.label} (${rate.grade.label.toLowerCase()})';
      sheet
        ..add(
          PriceGroup.colour,
          what,
          used.metres.value,
          PriceUnit.metre,
          rate.surcharge.perMetre,
        )
        ..addPercent(
          PriceGroup.colour,
          what,
          rate.surcharge.percent,
          used.cost,
        );
    }
    sheet.add(
      PriceGroup.otherProfile,
      'Sliding track',
      track.value,
      PriceUnit.metre,
      list.trackPerMetre,
    );

    // Glass by look and panel by colour, each by its whole area. Glass the
    // solid builds as a sealed unit — two sheets and a cavity — is priced
    // at the sealed unit's own rate for its look, and a single sheet at the
    // glass rate: one is never priced as the other.
    final glass = <String, ({SquareMetres area, double? rate})>{};
    final panel = <String, ({SquareMetres area, double? rate})>{};
    for (final region in takeoff.regions) {
      if (region.isGlass) {
        final look = GlassLook.of(region.finish);
        final kind = '${look?.label ?? 'Custom'} glass';
        final name = region.sealed ? 'Sealed unit — $kind' : kind;
        final rate = switch ((region.sealed, look)) {
          (true, null) => list.customSealedGlassPerM2,
          (true, final look?) => list.sealedGlassPerM2[look],
          (false, null) => list.customGlassPerM2,
          (false, final look?) => list.glassPerM2[look],
        };
        final was = glass[name]?.area ?? SquareMetres.zero;
        glass[name] = (area: was + region.area, rate: rate);
      } else if (region.isPanel) {
        final colour = PanelColour.of(region.finish);
        final name = '${colour?.label ?? 'Custom'} panel';
        final rate = colour == null
            ? list.customPanelPerM2
            : list.panelPerM2[colour];
        final was = panel[name]?.area ?? SquareMetres.zero;
        panel[name] = (area: was + region.area, rate: rate);
      } else {
        sheet.missing('${region.finish.material.label.toLowerCase()} infill');
      }
    }
    for (final (group, by) in [
      (PriceGroup.glass, glass),
      (PriceGroup.panel, panel),
    ]) {
      for (final MapEntry(key: name, value: v) in by.entries) {
        final rate = v.rate;
        if (rate == null) {
          sheet.missing(name.toLowerCase());
          continue;
        }
        sheet.add(group, name, v.area.value, PriceUnit.squareMetre, rate);
      }
    }

    // Every piece of ironmongery it carries, counted.
    for (final MapEntry(key: kind, value: count)
        in takeoff.hardwareCounts.entries) {
      final each = list.hardwareEach[kind];
      if (each == null) {
        sheet.missing('a ${kind.label.toLowerCase()}');
        continue;
      }
      sheet.add(
        PriceGroup.hardware,
        count == 1 ? kind.label : '${kind.label}s',
        count.toDouble(),
        PriceUnit.each,
        each,
      );
    }
  }
}

/// A sliding design: framed like the rest, its track priced as other
/// profile, and the rollers its sliding panels run on.
class SlidingPricing extends FramedPricing {
  const SlidingPricing();

  @override
  void price(PricingTakeoff takeoff, PriceSheet sheet) {
    super.price(takeoff, sheet);
    final list = sheet.list;
    // The roller rule: every panel that slides runs on the price list's
    // number of rollers (`rollersPerSlidingPanel`); a fixed panel stands in
    // its track on none.
    final sliders = takeoff.openings.where((o) => o.slides).length;
    sheet.add(
      PriceGroup.hardware,
      'Rollers',
      (sliders * list.rollersPerSlidingPanel).toDouble(),
      PriceUnit.each,
      list.rollerEach,
    );
  }
}
