import '../model/design.dart';
import '../model/materials.dart';
import 'measurement.dart';
import 'price_list.dart';
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
    if (design.frame == null) {
      return unavailable(
        PriceStatus.nothingToPrice,
        'Nothing has been drawn yet.',
      );
    }
    if (PricingTakeoff.problemWith(design) case final problem?) {
      return unavailable(PriceStatus.invalid, problem);
    }
    if (!PricingTakeoff.sizesGiven(design)) {
      return unavailable(
        PriceStatus.needsSizes,
        'Give the width and the height to price this design.',
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
        amount: _money(quantity * rate),
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
        rate: _money(of),
        amount: _money(of * percent / 100),
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

  double sumOf(PriceGroup group) =>
      lines.where((l) => l.group == group).fold(0, (sum, l) => sum + l.amount);

  /// To the hundredth: no price carries a fraction of a fraction.
  static double _money(double v) => (v * 100).roundToDouble() / 100;
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
    final normal = <MaterialKind, double>{};
    final opening = <MaterialKind, double>{};
    final byColour = <(MaterialKind, int), ({double metres, double cost})>{};
    var track = 0.0;
    for (final run in takeoff.runs) {
      final metres = run.length.value;
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
      into[material] = (into[material] ?? 0) + metres;
      final rate = isOpening ? profile.openingPerMetre : profile.normalPerMetre;
      final key = (material, run.finish.colour);
      final was = byColour[key] ?? (metres: 0.0, cost: 0.0);
      byColour[key] = (
        metres: was.metres + metres,
        cost: was.cost + metres * rate,
      );
    }
    for (final MapEntry(key: m, value: metres) in normal.entries) {
      sheet.add(
        PriceGroup.normalProfile,
        'Normal profile — ${m.label}',
        metres,
        PriceUnit.metre,
        list.profiles[m]!.normalPerMetre,
      );
    }
    for (final MapEntry(key: m, value: metres) in opening.entries) {
      sheet.add(
        PriceGroup.openingProfile,
        'Opening profile — ${m.label}',
        metres,
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
          used.metres,
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
      track,
      PriceUnit.metre,
      list.trackPerMetre,
    );

    // Glass by look and panel by colour, each by its whole area.
    final glass = <String, ({double area, double? rate})>{};
    final panel = <String, ({double area, double? rate})>{};
    for (final region in takeoff.regions) {
      if (region.isGlass) {
        final look = GlassLook.of(region.finish);
        final name = '${look?.label ?? 'Custom'} glass';
        final rate = look == null
            ? list.customGlassPerM2
            : list.glassPerM2[look];
        final was = glass[name]?.area ?? 0;
        glass[name] = (area: was + region.area.value, rate: rate);
      } else if (region.isPanel) {
        final colour = PanelColour.of(region.finish);
        final name = '${colour?.label ?? 'Custom'} panel';
        final rate = colour == null
            ? list.customPanelPerM2
            : list.panelPerM2[colour];
        final was = panel[name]?.area ?? 0;
        panel[name] = (area: was + region.area.value, rate: rate);
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
        sheet.add(group, name, v.area, PriceUnit.squareMetre, rate);
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

/// What a customer's designs come to: each priced on its own, and the
/// totals of all of them.
///
/// **Worked out from the designs, never kept on the customer**, so it is
/// never out of date: a design changed is priced afresh, and the customer's
/// total with it. A design that cannot be priced — sizes not given, a
/// category this version does not know — is listed and left out of the
/// total, and [complete] says so.
class CustomerPricing {
  final List<DesignPrice> designs;
  final String currency;

  const CustomerPricing(this.designs, this.currency);

  static CustomerPricing of(
    Iterable<Design> designs,
    PriceList list, {
    PricingEngine engine = const PricingEngine(),
  }) => CustomerPricing([
    for (final d in designs)
      DesignPrice(
        designId: d.id,
        name: d.shownName,
        result: engine.price(d, list),
      ),
  ], list.currency);

  List<DesignPrice> get priced => [
    for (final d in designs)
      if (d.result.isPriced) d,
  ];

  List<DesignPrice> get unpriced => [
    for (final d in designs)
      if (!d.result.isPriced) d,
  ];

  /// Whether every design was priced, so [total] is the whole.
  bool get complete => unpriced.isEmpty;

  /// The sum of the priced designs' totals.
  double get total => priced.fold(0, (sum, d) => sum + (d.result.total ?? 0));

  /// Everything the measured designs measure, together.
  MeasurementSummary get measurements => designs.fold(
    MeasurementSummary.none,
    (sum, d) => sum + d.result.measurements,
  );
}

/// One design's price, among a customer's.
class DesignPrice {
  final String designId;
  final String name;
  final PriceResult result;

  const DesignPrice({
    required this.designId,
    required this.name,
    required this.result,
  });
}
