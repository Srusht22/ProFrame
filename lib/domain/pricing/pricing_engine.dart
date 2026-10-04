import '../model/design.dart';
import '../model/materials.dart';
import 'price_list.dart';
import 'price_result.dart';
import 'takeoff.dart';

/// Prices a design: the design and the price list in, a [PriceResult] out.
///
/// ```
/// Design ─ PricingTakeoff ─ CategoryPricing ─ lines ─ labour,
///        (canonical          (what is charged,          installation,
///         geometry,           by category)              discount
///         read only)                                         │
///                                                       PriceResult
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

  /// The strategies for the five categories this version has.
  static const Map<String, CategoryPricing> standard = {
    'door': FramedPricing(),
    'window': FramedPricing(),
    // Each leaf of a door & window set is charged as what it is, which is
    // what FramedPricing already does leaf by leaf.
    'both': FramedPricing(),
    'sliding': SlidingPricing(),
    'angled': AngledPricing(),
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
        'This version of ProFrame cannot price a design of this category. '
        'Price unavailable.',
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
    final made =
        sheet.sumOf(PriceGroup.material) + sheet.sumOf(PriceGroup.hardware);
    final labour = rate.labour;
    sheet
      ..add(PriceGroup.labour, 'Making', 1, PriceUnit.fixed, labour.fixed)
      ..add(
        PriceGroup.labour,
        'Making, by area',
        takeoff.areaM2,
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
          takeoff.areaM2,
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

/// A framed design: its frame and bars by the metre of their own material,
/// with what their colour adds; each pane by its own glass or panel, by the
/// square metre it is cut to; each leaf by what it is; and every piece of
/// ironmongery it actually carries.
///
/// Door, window and door & window are priced this way: the difference
/// between them is in the design — which leaves it has and what each is —
/// not in a rule here, so a door & window set is charged leaf by leaf as
/// the leaves it has, never as one door or one window.
class FramedPricing extends CategoryPricing {
  const FramedPricing();

  @override
  void price(PricingTakeoff takeoff, PriceSheet sheet) {
    final list = sheet.list;

    // The frame, by the metre of its own material.
    final frameFinish = takeoff.frameFinish;
    final frame = list.profiles[frameFinish.material];
    if (frame == null) {
      sheet.missing('a ${frameFinish.material.label} frame');
    } else {
      final before = sheet.lines.length;
      sheet.add(
        PriceGroup.material,
        '${frameFinish.material.label} frame',
        takeoff.frameMetres,
        PriceUnit.metre,
        frame.framePerMetre,
      );
      for (final leaf in takeoff.leaves) {
        sheet.add(
          PriceGroup.material,
          '${frameFinish.material.label} sash — ${leaf.name}',
          leaf.metres,
          PriceUnit.metre,
          frame.sashPerMetre,
          partId: leaf.id,
        );
      }
      _colour(sheet, frame, frameFinish, 'frame', before);
    }

    // Each bar, by the metre of its own material.
    for (final bar in takeoff.bars) {
      final profile = list.profiles[bar.finish.material];
      if (profile == null) {
        sheet.missing('a ${bar.finish.material.label} bar');
        continue;
      }
      final before = sheet.lines.length;
      sheet.add(
        PriceGroup.material,
        bar.openingId == null
            ? '${bar.finish.material.label} bar'
            : '${bar.finish.material.label} divider inside an opening',
        bar.metres,
        PriceUnit.metre,
        profile.barPerMetre,
        partId: bar.id,
      );
      _colour(sheet, profile, bar.finish, 'bar', before);
    }

    // Each pane, by what fills it.
    for (final pane in takeoff.panes) {
      if (pane.isGlass) {
        final look = GlassLook.of(pane.finish);
        final rate = look == null
            ? list.customGlassPerM2
            : list.glassPerM2[look];
        if (rate == null) {
          sheet.missing('${look?.label ?? 'custom'} glass');
          continue;
        }
        sheet.add(
          PriceGroup.material,
          '${look?.label ?? 'Custom'} glass — ${pane.name}',
          pane.areaM2,
          PriceUnit.squareMetre,
          rate,
          partId: pane.id,
        );
      } else if (pane.isPanel) {
        final colour = PanelColour.of(pane.finish);
        final rate = colour == null
            ? list.customPanelPerM2
            : list.panelPerM2[colour];
        if (rate == null) {
          sheet.missing('a ${colour?.label.toLowerCase() ?? 'custom'} panel');
          continue;
        }
        sheet.add(
          PriceGroup.material,
          '${colour?.label ?? 'Custom'} panel — ${pane.name}',
          pane.areaM2,
          PriceUnit.squareMetre,
          rate,
          partId: pane.id,
        );
      } else {
        sheet.missing('${pane.finish.material.label.toLowerCase()} infill');
      }
    }

    // Each leaf, as what it is.
    final leaves = <LeafRate, int>{};
    for (final leaf in takeoff.leaves) {
      final rate = leafRateOf(leaf);
      leaves[rate] = (leaves[rate] ?? 0) + 1;
    }
    for (final MapEntry(key: kind, value: count) in leaves.entries) {
      final each = list.leafEach[kind];
      if (each == null) {
        sheet.missing('a ${kind.label.toLowerCase()}');
        continue;
      }
      sheet.add(
        PriceGroup.material,
        count == 1 ? kind.label : '${kind.label}s',
        count.toDouble(),
        PriceUnit.each,
        each,
      );
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

  /// What [leaf] is charged as: a sliding panel where it slides, otherwise
  /// its own kind — and a leaf nobody has named yet as just a leaf, never
  /// guessed to be a door or a window.
  LeafRate leafRateOf(LeafTakeoff leaf) {
    if (leaf.slides) return LeafRate.sliding;
    return switch (leaf.kind) {
      DesignKind.door => LeafRate.door,
      DesignKind.window => LeafRate.window,
      _ => LeafRate.unnamed,
    };
  }

  /// What [finish]'s colour adds to the profile lines written since
  /// [from], as one line of its own so the breakdown says why.
  static void _colour(
    PriceSheet sheet,
    ProfileRate profile,
    Finish finish,
    String what,
    int from,
  ) {
    final colour = profile.colourOf(finish.colour);
    final profileCost = sheet.lines
        .skip(from)
        .fold<double>(0, (sum, l) => sum + l.amount);
    sheet.addPercent(
      PriceGroup.material,
      '${colour.name} $what (${colour.grade.label.toLowerCase()})',
      colour.surchargePercent,
      profileCost,
    );
  }
}

/// A sliding design: framed like the rest, its panels charged as sliding
/// panels, and the track and the rollers they run on.
class SlidingPricing extends FramedPricing {
  const SlidingPricing();

  @override
  void price(PricingTakeoff takeoff, PriceSheet sheet) {
    super.price(takeoff, sheet);
    final list = sheet.list;
    sheet.add(
      PriceGroup.material,
      'Sliding track',
      takeoff.widthM,
      PriceUnit.metre,
      list.trackPerMetre,
    );
    final sliders = takeoff.leaves.where((l) => l.slides).length;
    sheet.add(
      PriceGroup.hardware,
      'Rollers',
      (sliders * list.rollersPerSlidingPanel).toDouble(),
      PriceUnit.each,
      list.rollerEach,
    );
  }
}

/// An angled design: framed like the rest — every area its own polygon's,
/// never a box round it — and each joint cut at an angle charged.
class AngledPricing extends FramedPricing {
  const AngledPricing();

  @override
  void price(PricingTakeoff takeoff, PriceSheet sheet) {
    super.price(takeoff, sheet);
    sheet.add(
      PriceGroup.material,
      'Angled joints',
      takeoff.angledJoints.toDouble(),
      PriceUnit.each,
      sheet.list.angledJointEach,
    );
  }
}
