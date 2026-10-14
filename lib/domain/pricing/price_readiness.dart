import '../dimensions/measurements.dart';
import '../model/design.dart';
import '../recognition/geometry_feedback.dart';
import '../text/names.dart';
import '../text/words.dart';
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
  String get message => messageIn(const EnglishWords());

  /// [message], in [w].
  String messageIn(Words w) {
    if (missing.isEmpty) return '';
    final first = missing.first.messageIn(w);
    final more = missing.length - 1;
    if (more == 0) return first;
    return more == 1
        ? w.readinessMoreOne(first, more)
        : w.readinessMoreMany(first, more);
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
          _unsupported,
        ),
      ];
    }
    // Lines drawn or rubbed out since the last reading: the geometry is an
    // older reading of the sheet than the one on the screen, and a price of
    // it would be the price of a drawing nobody is looking at. Nothing else
    // is asked until the sheet is read, because everything else is asked of
    // the geometry the reading will replace.
    if (design.sketchUnread) {
      return const [PriceRequirement(PriceRequirementKind.notRead, _notRead)];
    }
    if (design.frame == null) {
      final drawn = design.sketch.strokes.isNotEmpty;
      return [
        PriceRequirement(PriceRequirementKind.frame, drawn ? _frame : _draw),
      ];
    }
    if (PricingTakeoff.problemWith(design) != null) {
      return [
        PriceRequirement(
          PriceRequirementKind.geometry,
          (w) => w.reqGeometry(PricingTakeoff.problemWith(design, w)!),
        ),
      ];
    }

    final missing = <PriceRequirement>[
      for (final notice in GeometryFeedback.of(design).notices)
        if (notice.isError)
          PriceRequirement(
            PriceRequirementKind.geometry,
            (w) => w.reqGeometry(notice.messageIn(w)),
            elementId: notice.problem.elementId,
          ),
    ];

    switch (design.construction) {
      case Construction.pending:
        missing.add(
          const PriceRequirement(
            PriceRequirementKind.construction,
            _construction,
          ),
        );
      case Construction.both when !design.partsAsked:
        missing.add(
          const PriceRequirement(
            PriceRequirementKind.panelOrGlass,
            _panelOrGlass,
          ),
        );
      default:
    }

    for (final opening in design.openingsInOrder) {
      if (design.kindOf(opening) != null) continue;
      missing.add(
        PriceRequirement(
          PriceRequirementKind.openingKind,
          (w) => w.reqOpeningKind(design.plainNameOfIn(w, opening)),
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
        String say(Words w) {
          // The form's heading for it, without the opening's mark.
          var group = sizes.first.groupIn(w);
          for (final o in design.openings) {
            group = group.replaceAll(
              design.nameOfIn(w, o),
              design.plainNameOfIn(w, o),
            );
          }
          final which = [for (final m in sizes) m.labelIn(w).toLowerCase()]
              .reduce(w.joinAnd);
          return named == 'Frame'
              ? w.reqFrameSizes(which)
              : w.reqGroupSizes(group, which);
        }

        missing.add(
          PriceRequirement(
            PriceRequirementKind.sizes,
            say,
            elementId: sizes.first.sectionId,
          ),
        );
      }
    }

    // What the profile is made of — the material and its colour — chosen
    // by somebody, never the stock finish a new frame is read in.
    if (!ProfileSelection.of(design).isChosen) {
      missing.add(
        const PriceRequirement(PriceRequirementKind.profile, _profile),
      );
    }

    // Which profile category each part in a material sold by category is —
    // System or Bend Shoulder aluminium — said by somebody, never guessed
    // from how the design looks.
    final unallocated = ProfileAllocation.unallocatedIn(design);
    if (unallocated.isNotEmpty) {
      final material = unallocated.first.material;
      final all = ProfileAllocation.partsOf(design)
          .where((p) => p.material == material)
          .length;
      String say(Words w) {
        final choices = [
          for (final c in ProfileCategory.of(material)) c.labelIn(w),
        ].reduce(w.joinOr);
        return unallocated.length == all
            ? w.reqCategoryAll(material.labelIn(w).toLowerCase(), choices)
            : w.reqCategorySome(
                choices,
                unallocated.map((p) => p.nameIn(w)).join(', '),
              );
      }

      missing.add(
        PriceRequirement(
          PriceRequirementKind.profileCategory,
          say,
          elementId: unallocated.first.key,
        ),
      );
    }
    return missing;
  }

  static String _unsupported(Words w) => w.reqUnsupported;
  static String _notRead(Words w) => w.reqNotRead;
  static String _frame(Words w) => w.reqFrame;
  static String _draw(Words w) => w.reqDraw;
  static String _construction(Words w) => w.reqConstruction;
  static String _panelOrGlass(Words w) => w.reqPanelOrGlass;
  static String _profile(Words w) => w.reqProfile;
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

  /// What it says, in a language.
  final String Function(Words w) say;

  /// The part it is about, where there is one.
  final String? elementId;

  const PriceRequirement(this.kind, this.say, {this.elementId});

  /// What it says, in English.
  String get message => say(const EnglishWords());

  /// What it says, in [w].
  String messageIn(Words w) => say(w);
}
