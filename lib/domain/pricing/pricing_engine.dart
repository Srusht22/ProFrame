import '../model/design.dart';
import '../model/materials.dart';
import '../text/line_name.dart';
import '../text/names.dart';
import '../text/words.dart';
import 'extra_charge.dart';
import 'measurement.dart';
import 'price_list.dart';
import 'price_readiness.dart';
import 'price_result.dart';
import 'profile_category.dart';
import 'profile_selection.dart';
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
    PriceResult unavailable(
      PriceStatus status,
      String Function(Words w) why,
    ) => PriceResult.unavailable(
      status,
      why(const EnglishWords()),
      currency: list.currency,
      category: category,
      priceListVersion: list.version,
      say: why,
    );

    final strategy = design.isUnsupported ? null : strategies[category];
    if (strategy == null) {
      return unavailable(
        PriceStatus.unsupportedCategory,
        (w) => w.engineUnsupported,
      );
    }
    final rate = list.categories[category];
    if (rate == null) {
      return unavailable(
        PriceStatus.notConfigured,
        (w) => w.engineNoCategory(design.kind.labelIn(w)),
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
        readiness.messageIn,
      );
    }

    // The profile's colour, by material and colour together: a colour that
    // needs choosing again stops the price — nothing is put in its place.
    // One the list does not price on this material is said where the
    // colour is charged, below, with everything else the list lacks.
    final chosen = ProfileSelection.of(design);
    if (chosen.colourIn(list) case final colour? when colour.needsSelection) {
      return unavailable(
        PriceStatus.incomplete,
        (w) => colour.problemIn(w)!,
      );
    }

    final takeoff = PricingTakeoff.of(design);
    final sheet = PriceSheet(
      list,
      profile: chosen,
      glassPriced: said.glassPriced,
      categoryFor: said.categoryFor,
    );
    strategy.price(takeoff, sheet);

    // Labour, by the category's own rate.
    final made = sheet.lines.fold<double>(0, (sum, l) => sum + l.amount);
    final labour = rate.labour;
    sheet
      ..addNamed(
        PriceGroup.labour,
        const LineName('making'),
        1,
        PriceUnit.fixed,
        labour.fixed,
      )
      ..addNamed(
        PriceGroup.labour,
        const LineName('makingArea'),
        takeoff.area.value,
        PriceUnit.squareMetre,
        labour.perSquareMetre,
      )
      ..addPercent(
        PriceGroup.labour,
        const LineName('makingMaterials').english,
        labour.percent,
        made,
        name: const LineName('makingMaterials'),
      );

    // Installation, only where the user asked for it.
    if (said.installation) {
      final fit = list.installation;
      sheet
        ..addNamed(
          PriceGroup.installation,
          const LineName('installation'),
          1,
          PriceUnit.fixed,
          fit.fixed,
        )
        ..addNamed(
          PriceGroup.installation,
          const LineName('installationArea'),
          takeoff.area.value,
          PriceUnit.squareMetre,
          fit.perSquareMetre,
        );
    }

    // The extras the factory added by hand, each quantity × unit price,
    // kept beside the design's own cost and never folded into a line of it.
    // One in another currency is never added to this one: it stops the
    // price until it is written in the list's currency.
    for (final e in said.extras.notIn(list.currency)) {
      sheet.unavailable(
        (w) => w.engineExtraCurrency(e.name, e.currency, list.currency),
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
      extras: said.extras,
      measurements: takeoff.summary,
      glassPriced: said.glassPriced,
      profile: switch (chosen) {
        ProfileSelection(:final material?, :final colour?) && final p =>
          PricedProfile(
            material: material.name,
            materialLabel: material.label,
            colour: colour,
            colourName: p.colourName(list),
            colourId: p.catalogColourIn(list)?.id,
            colourRate: p.colourIn(list)?.surcharge,
          ),
        _ => null,
      },
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

  /// What the design's profile was chosen as — its colour is looked up by
  /// the catalog id it was chosen under.
  final ProfileSelection profile;

  /// Whether the design's glass is charged for: the user's switch, off
  /// unless they turned it on.
  final bool glassPriced;

  /// The profile category the part kept under a key was said to be, or
  /// null where nobody said — see `ProfileAllocation`.
  final ProfileCategory? Function(String key) categoryFor;

  PriceSheet(
    this.list, {
    this.profile = ProfileSelection.notChosen,
    this.glassPriced = false,
    this.categoryFor = _nobodySaid,
  });

  static ProfileCategory? _nobodySaid(String key) => null;

  void add(
    PriceGroup group,
    String label,
    double quantity,
    PriceUnit unit,
    double rate, {
    String? partId,
    ProfilePart? part,
    ProfileCategory? category,
    LineName? name,
  }) {
    if (!quantity.isFinite || !rate.isFinite || quantity <= 0 || rate <= 0) {
      return;
    }
    lines.add(
      PriceLine(
        group: group,
        label: label,
        name: name,
        quantity: quantity,
        unit: unit,
        rate: rate,
        // Charged to the cent here, once; only cents are added after.
        amount: quantity * rate,
        partId: partId,
        part: part,
        category: category,
      ),
    );
  }

  /// [add], for a line said by [name] — its label the English of it.
  void addNamed(
    PriceGroup group,
    LineName name,
    double quantity,
    PriceUnit unit,
    double rate, {
    ProfilePart? part,
    ProfileCategory? category,
  }) => add(
    group,
    name.english,
    quantity,
    unit,
    rate,
    part: part,
    category: category,
    name: name,
  );

  void addPercent(
    PriceGroup group,
    String label,
    double percent,
    double of, {
    String? partId,
    LineName? name,
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
        name: name,
      ),
    );
  }

  /// Something that stops the design being priced, said as it is.
  void unavailable(String Function(Words w) say) {
    final issue = PriceIssue.said(say);
    if (issues.every((i) => i.message != issue.message)) issues.add(issue);
  }

  /// Something the price list has no price for: the design cannot be
  /// priced until it has.
  void missing(String Function(Words w) what) =>
      unavailable((w) => w.engineMissing(what(w)));

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
/// - **Border and internal lines** — the frame's border and every bar and
///   line, each in its own material — by the metre at that material's
///   normal rate, or, for a material sold by profile category (System and
///   Bend Shoulder aluminium), at the rate of the category each part was
///   said to be. The border and the lines are measured and charged as two
///   lines at the rate they share, never folded into one; a part in such a
///   material that nobody said the category of is not priced at all.
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
    // Border and lines by material, by category where the material is
    // sold by category, and by which of the two they are.
    final normal = <(MaterialKind, ProfileCategory?, ProfilePart), Metres>{};
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
        sheet.missing((w) => w.missProfile(material.labelIn(w)));
        continue;
      }
      final isOpening = run.use == ProfileUse.opening;
      final double rate;
      if (isOpening) {
        opening[material] = (opening[material] ?? Metres.zero) + metres;
        rate = profile.openingPerMetre;
      } else {
        ProfileCategory? category;
        if (ProfileCategory.divides(material)) {
          category = switch (sheet.categoryFor(run.id)) {
            final c? when c.material == material => c,
            _ => null,
          };
          // Never charged at a category nobody chose.
          if (category == null) {
            sheet.unavailable(
              (w) => w.reqCategoryAll(
                material.labelIn(w).toLowerCase(),
                [
                  for (final c in ProfileCategory.of(material)) c.labelIn(w),
                ].reduce(w.joinOr),
              ),
            );
            continue;
          }
        }
        final perMetre = profile.normalRateFor(category);
        if (perMetre == null) {
          sheet.missing(
            (w) => w.missBorderLines(
              category == null ? material.labelIn(w) : category.labelIn(w),
            ),
          );
          continue;
        }
        rate = perMetre;
        final part = run.use == ProfileUse.border
            ? ProfilePart.border
            : ProfilePart.lines;
        final key = (material, category, part);
        normal[key] = (normal[key] ?? Metres.zero) + metres;
      }
      final key = (material, run.finish.colour);
      final was = byColour[key] ?? (metres: Metres.zero, cost: 0.0);
      byColour[key] = (
        metres: was.metres + metres,
        cost: was.cost + metres.value * rate,
      );
    }
    // Each category's border, then its lines; the order the factory reads
    // them in, whatever order the parts were drawn in.
    final keys = normal.keys.toList()
      ..sort((a, b) {
        final m = a.$1.index.compareTo(b.$1.index);
        if (m != 0) return m;
        final c = (a.$2?.index ?? -1).compareTo(b.$2?.index ?? -1);
        return c != 0 ? c : a.$3.index.compareTo(b.$3.index);
      });
    for (final key in keys) {
      final (m, category, part) = key;
      sheet.addNamed(
        PriceGroup.normalProfile,
        LineName('profile', [
          category == null ? 'mat:${m.name}' : 'cat:${category.name}',
          part.name,
        ]),
        normal[key]!.value,
        PriceUnit.metre,
        list.profiles[m]!.normalRateFor(category)!,
        part: part,
        category: category,
      );
    }
    for (final MapEntry(key: m, value: metres) in opening.entries) {
      sheet.addNamed(
        PriceGroup.openingProfile,
        LineName('opening', [m.name]),
        metres.value,
        PriceUnit.metre,
        list.profiles[m]!.openingPerMetre,
      );
    }
    // Each colour is looked up by material and colour together, and what
    // it adds is charged once, on all the profile in it: so much a metre
    // and so much in a hundred of what that profile cost.
    for (final MapEntry(key: (m, colour), value: used) in byColour.entries) {
      final chosen = sheet.profile;
      final id = chosen.material == m && chosen.colour == colour
          ? chosen.colourId
          : null;
      final rate = list.colourFor(m, colour, id: id);
      if (!rate.isPriced) {
        sheet.unavailable((w) => rate.problemIn(w)!);
        continue;
      }
      final what = LineName('colour', [
        rate.entry?.name ?? '',
        m.name,
        rate.grade.name,
      ]);
      sheet
        ..addNamed(
          PriceGroup.colour,
          what,
          used.metres.value,
          PriceUnit.metre,
          rate.surcharge.perMetre,
        )
        ..addPercent(
          PriceGroup.colour,
          what.english,
          rate.surcharge.percent,
          used.cost,
          name: what,
        );
    }
    sheet.addNamed(
      PriceGroup.otherProfile,
      const LineName('track'),
      track.value,
      PriceUnit.metre,
      list.trackPerMetre,
    );

    // Glass by look and panel by colour, each by its whole area. Glass the
    // solid builds as a sealed unit — two sheets and a cavity — is priced
    // at the sealed unit's own rate for its look, and a single sheet at the
    // glass rate: one is never priced as the other.
    final glass = <LineName, ({SquareMetres area, double? rate})>{};
    final panel = <LineName, ({SquareMetres area, double? rate})>{};
    for (final region in takeoff.regions) {
      // Glass is charged only where the user included it: the area is
      // still measured, and said, but not charged.
      if (region.isGlass && !sheet.glassPriced) continue;
      if (region.isGlass) {
        final look = GlassLook.of(region.finish);
        final name = LineName('glass', [
          look?.name ?? 'custom',
          if (region.sealed) 'sealed',
        ]);
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
        final name = LineName('panel', [colour?.name ?? 'custom']);
        final rate = colour == null
            ? list.customPanelPerM2
            : list.panelPerM2[colour];
        final was = panel[name]?.area ?? SquareMetres.zero;
        panel[name] = (area: was + region.area, rate: rate);
      } else {
        sheet.missing(
          (w) => w.missInfill(region.finish.material.labelIn(w).toLowerCase()),
        );
      }
    }
    for (final (group, by) in [
      (PriceGroup.glass, glass),
      (PriceGroup.panel, panel),
    ]) {
      for (final MapEntry(key: name, value: v) in by.entries) {
        final rate = v.rate;
        if (rate == null) {
          sheet.missing((w) => name.sayIn(w)!.toLowerCase());
          continue;
        }
        sheet.addNamed(group, name, v.area.value, PriceUnit.squareMetre, rate);
      }
    }

    // Every piece of ironmongery it carries, counted.
    for (final MapEntry(key: kind, value: count)
        in takeoff.hardwareCounts.entries) {
      final each = list.hardwareEach[kind];
      if (each == null) {
        sheet.missing((w) => w.missPiece(kind.labelIn(w).toLowerCase()));
        continue;
      }
      sheet.addNamed(
        PriceGroup.hardware,
        LineName('pieces', [kind.name, if (count == 1) 'one']),
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
    sheet.addNamed(
      PriceGroup.hardware,
      const LineName('rollers'),
      (sliders * list.rollersPerSlidingPanel).toDouble(),
      PriceUnit.each,
      list.rollerEach,
    );
  }
}
