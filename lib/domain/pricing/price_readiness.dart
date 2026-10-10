import '../dimensions/measurements.dart';
import '../model/design.dart';
import '../model/elements.dart';
import '../recognition/geometry_feedback.dart';
import 'profile_category.dart';
import 'profile_selection.dart';
import 'takeoff.dart';

/// Whether a design holds everything its price is worked out from, and if
/// not, what is still to be done.
///
/// **One answer, read everywhere a price is.** The engine asks it before it
/// prices anything, the workspace's **Calculate price** and every design
/// card's **Price** are enabled by it, and a customer's total counts a
/// design only where it says yes — so no two screens can disagree about
/// whether a design can be priced.
///
/// It decides nothing of its own. Each requirement is a question the
/// application already asks, read from where it is kept:
///
/// | Requirement | Read from |
/// | --- | --- |
/// | A category this version can price | `Design.isUnsupported` |
/// | A drawing read since it last changed | `Design.sketchUnread` |
/// | An outer frame | `Design.frame` |
/// | Geometry that can be measured | `PricingTakeoff.problemWith`, and the angled check's errors (`GeometryFeedback`) |
/// | What a door is built of | `Design.construction` |
/// | Which parts are glass and which panel | `Design.partsAsked` |
/// | What each opening is — door or window | `Design.kindOf` |
/// | Every size the design asks for | `Measurements.of`, against `Design.measured` |
/// | The profile's material and colour, chosen | `ProfileSelection.of` |
/// | Each aluminium part's profile category — System or Bend Shoulder — chosen | `ProfileAllocation.unallocatedIn` |
///
/// So what is required follows the design and its category: a window is
/// never asked what it is built of, and a door design's leaves are doors
/// without being asked. **Nothing is assumed to fill a gap** — no size is
/// read off the sketch, no glass or panel is chosen, no opening is guessed
/// — because a price worked out over a gap is a price nobody should quote.
class PriceReadiness {
  /// What is still to be done, most fundamental first. Empty when the
  /// design can be priced.
  final List<PriceRequirement> missing;

  const PriceReadiness._(this.missing);

  static const ready = PriceReadiness._([]);

  bool get isPriceCalculable => missing.isEmpty;

  /// What to tell the user: the first thing to complete, naming it, and how
  /// many more there are after it.
  String get message {
    if (missing.isEmpty) return '';
    final first = missing.first.message;
    final more = missing.length - 1;
    if (more == 0) return first;
    return '$first $more more ${more == 1 ? 'thing needs' : 'things need'} '
        'completing too.';
  }

  /// A design is immutable, so its answer is worked out once and kept with
  /// the object; an edit is a new design and is asked afresh.
  static final _asked = Expando<PriceReadiness>();

  static PriceReadiness of(Design design) =>
      _asked[design] ??= PriceReadiness._(List.unmodifiable(_missing(design)));

  static List<PriceRequirement> _missing(Design design) {
    if (design.isUnsupported) {
      return const [
        PriceRequirement(
          PriceRequirementKind.unsupportedCategory,
          'This design\'s category is not supported by this version of '
          'ProFrame, so its price is unavailable.',
        ),
      ];
    }
    // Lines drawn or rubbed out since the last reading: the geometry is an
    // older reading of the sheet than the one on the screen, and a price of
    // it would be the price of a drawing nobody is looking at. Nothing else
    // is asked until the sheet is read, because everything else is asked of
    // the geometry the reading will replace.
    if (design.sketchUnread) {
      return const [
        PriceRequirement(
          PriceRequirementKind.notRead,
          'The drawing has changes that have not been read. Please Read the '
          'drawing before calculating the price.',
        ),
      ];
    }
    if (design.frame == null) {
      final drawn = design.sketch.strokes.isNotEmpty;
      return [
        PriceRequirement(
          PriceRequirementKind.frame,
          drawn
              ? 'Please complete the outer frame to calculate the price.'
              : 'Please draw the design to calculate the price.',
        ),
      ];
    }
    if (PricingTakeoff.problemWith(design) case final problem?) {
      return [
        PriceRequirement(
          PriceRequirementKind.geometry,
          'Please correct the geometry to calculate the price: $problem',
        ),
      ];
    }

    final missing = <PriceRequirement>[
      for (final notice in GeometryFeedback.of(design).notices)
        if (notice.isError)
          PriceRequirement(
            PriceRequirementKind.geometry,
            'Please correct the geometry to calculate the price: '
            '${notice.message}',
            elementId: notice.problem.elementId,
          ),
    ];

    switch (design.construction) {
      case Construction.pending:
        missing.add(
          const PriceRequirement(
            PriceRequirementKind.construction,
            'Please choose what the door is built of — panel, glass or '
            'both — to calculate the price.',
          ),
        );
      case Construction.both when !design.partsAsked:
        missing.add(
          const PriceRequirement(
            PriceRequirementKind.panelOrGlass,
            'Please complete the panel/glass selection to calculate the '
            'price.',
          ),
        );
      default:
    }

    for (final opening in design.openingsInOrder) {
      if (design.kindOf(opening) != null) continue;
      missing.add(
        PriceRequirement(
          PriceRequirementKind.openingKind,
          'Please say whether ${_plain(design, opening)} is a door or a '
          'window to calculate the price.',
          elementId: opening.id,
        ),
      );
    }

    // Every size the design asks for. A design kept before sizes were
    // asked has nothing outstanding, as everywhere else.
    final said = design.measured;
    if (said != null) {
      final outstanding = [
        for (final m in Measurements.of(design))
          if (m.asked && !said.contains(m.key)) m,
      ];
      final byGroup = <String, List<Measure>>{};
      for (final m in outstanding) {
        (byGroup[m.group] ??= []).add(m);
      }
      for (final MapEntry(key: named, value: sizes) in byGroup.entries) {
        // The form's heading for it, without the opening's mark.
        var group = named;
        for (final o in design.openings) {
          group = group.replaceAll(design.nameOf(o), _plain(design, o));
        }
        final which = sizes.map((m) => m.label.toLowerCase()).join(' and ');
        missing.add(
          PriceRequirement(
            PriceRequirementKind.sizes,
            group == 'Frame'
                ? 'Please give the $which to calculate the price.'
                : 'Please complete the dimensions of $group (its $which) to '
                      'calculate the price.',
            elementId: sizes.first.sectionId,
          ),
        );
      }
    }

    // What the profile is made of — the material and its colour — chosen
    // by somebody, never the stock finish a new frame is read in.
    if (!ProfileSelection.of(design).isChosen) {
      missing.add(
        const PriceRequirement(
          PriceRequirementKind.profile,
          'Please choose the material and colour of the profile to '
          'calculate the price.',
        ),
      );
    }

    // Which profile category each part in a material sold by category is —
    // System or Bend Shoulder aluminium — said by somebody, never guessed
    // from how the design looks.
    final unallocated = ProfileAllocation.unallocatedIn(design);
    if (unallocated.isNotEmpty) {
      final material = unallocated.first.material;
      final choices = ProfileCategory.of(material)
          .map((c) => c.label)
          .join(' or ');
      final all = ProfileAllocation.partsOf(design)
          .where((p) => p.material == material)
          .length;
      missing.add(
        PriceRequirement(
          PriceRequirementKind.profileCategory,
          unallocated.length == all
              ? 'Please choose whether the ${material.label.toLowerCase()} '
                    'profile is $choices to calculate the price.'
              : 'Please choose $choices for '
                    '${unallocated.map((p) => p.name).join(', ')} to '
                    'calculate the price.',
          elementId: unallocated.first.key,
        ),
      );
    }
    return missing;
  }

  /// An opening as a sentence names it: *Opening 2*, without its mark.
  static String _plain(Design design, OpeningElement opening) {
    final n = design.numberOf(opening);
    return n > 0 ? 'Opening $n' : 'the opening';
  }
}

/// What kind of thing is still to be completed.
enum PriceRequirementKind {
  unsupportedCategory,

  /// The drawing has strokes the geometry has not been read from.
  notRead,
  frame,
  geometry,
  construction,
  panelOrGlass,
  openingKind,
  sizes,

  /// Nobody has chosen the material and colour of the profile.
  profile,

  /// A part in a material sold by profile category — aluminium — has no
  /// category: System or Bend Shoulder.
  profileCategory,
}

/// One thing a design needs before it can be priced, said in words that
/// name it.
class PriceRequirement {
  final PriceRequirementKind kind;
  final String message;

  /// The part it is about, where there is one.
  final String? elementId;

  const PriceRequirement(this.kind, this.message, {this.elementId});
}
