import '../model/materials.dart';
import '../text/names.dart';
import '../text/words.dart';
import 'price_list.dart';
import 'price_list_migration.dart';
import 'profile_selection.dart';

/// A colour as the owner has typed it: what it is called, its swatch, its
/// grade and, for each material it is to be sold in, what it adds there —
/// null where nothing was typed yet.
class ColourDraft {
  final String name;
  final int swatch;
  final ColourGrade grade;
  final Map<MaterialKind, ColourSurcharge?> rates;

  const ColourDraft({
    required this.name,
    required this.swatch,
    required this.rates,
    this.grade = ColourGrade.nonStandard,
  });

  /// [colour] as a draft to edit.
  factory ColourDraft.of(FactoryColour colour) => ColourDraft(
    name: colour.name,
    swatch: colour.swatch,
    grade: colour.grade,
    rates: colour.rates,
  );
}

/// The factory's colour catalog as the owner changes it: adding a colour,
/// editing or renaming one, retiring one and bringing one back.
///
/// **Each is a new price list, never a change in place.** The screen keeps
/// what comes back through the store (`PriceListStore.save`), which makes
/// it the next version of the list — so every price worked out before says
/// it needs recalculating, and every price kept before is left exactly as
/// it was, with the colour, its name, its rate and the version it was
/// worked out from (`PriceRecord`).
///
/// **Nothing is ever deleted.** A colour the factory stops selling is
/// retired: it is not offered for a new choice, and every design already
/// in it still says what it is and is still priced at its rate.
///
/// Every operation checks the draft first ([problemsWith]) and changes
/// nothing where there is a problem: the problems come back, keyed by what
/// they are about — `name`, `materials`, `rate.<material>`.
abstract final class ColourCatalog {
  /// The colour's name.
  static const nameField = 'name';

  /// Which materials it is sold in.
  static const materialsField = 'materials';

  /// Its rate on [m].
  static String rateField(MaterialKind m) => 'rate.${m.name}';

  /// [text] typed as a rate: a figure of 0 or more, or why it is not one.
  /// Empty is no figure — which is a problem only where a rate is needed.
  static ({double? value, String? problem}) readRate(
    String text, [
    Words w = const EnglishWords(),
  ]) {
    final words = text.trim();
    if (words.isEmpty) return (value: null, problem: null);
    final value = double.tryParse(words);
    if (value == null || !value.isFinite) {
      return (value: null, problem: w.ccEnterFigure);
    }
    if (value < 0) {
      return (value: null, problem: w.ccRateNotBelow);
    }
    return (value: value, problem: null);
  }

  /// What is wrong with [draft] as a colour of [list] — keyed by what each
  /// problem is about — where [editing] is the id of the colour it replaces,
  /// if it replaces one, and [active] whether it is to be offered.
  ///
  /// - A name is needed, and is kept trimmed.
  /// - Two active colours sold in the same material are never called the
  ///   same, whatever the case — a staff member choosing *Black* must know
  ///   which Black. A retired colour does not hold its name against a new
  ///   one.
  /// - It is sold in at least one material the list prices a profile in.
  /// - Every material it is sold in has a rate — so much a metre, which may
  ///   be nothing — and no rate is below nothing or not a number.
  static Map<String, String> problemsWith(
    PriceList list,
    ColourDraft draft, {
    String? editing,
    bool active = true,
    Words words = const EnglishWords(),
  }) {
    final w = words;
    final problems = <String, String>{};
    final name = draft.name.trim();
    if (name.isEmpty) problems[nameField] = w.ccNameRequired;

    final sold = profileMaterialsOf(list);
    final materials = [
      for (final m in MaterialKind.values)
        if (draft.rates.containsKey(m)) m,
    ];
    if (materials.isEmpty) {
      problems[materialsField] = w.ccChooseMaterial;
    } else if (materials.where((m) => !sold.contains(m)).firstOrNull
        case final m?) {
      problems[materialsField] = w.ccNoProfile(m.labelIn(w));
    }

    for (final m in materials) {
      final rate = draft.rates[m];
      if (rate == null) {
        problems[rateField(m)] = w.ccRateRequired(m.labelIn(w));
      } else if (!rate.perMetre.isFinite ||
          !rate.percent.isFinite ||
          rate.perMetre < 0 ||
          rate.percent < 0) {
        problems[rateField(m)] = w.ccRateNotBelow;
      }
    }

    if (name.isNotEmpty && active) {
      final same = name.toLowerCase();
      for (final other in list.colours) {
        if (other.id == editing || !other.active) continue;
        if (other.name.trim().toLowerCase() != same) continue;
        final shared = materials.where(other.appliesTo).firstOrNull;
        if (shared != null) {
          problems[nameField] = w.ccNameTaken(other.name, shared.labelIn(w));
          break;
        }
      }
    }
    return problems;
  }

  /// [list] with [draft] added as a new, active colour, listed last, under
  /// an id of its own that no colour — active or retired — has had.
  static ({PriceList? list, Map<String, String> problems, String? id}) add(
    PriceList list,
    ColourDraft draft, [
    Words w = const EnglishWords(),
  ]) {
    final problems = problemsWith(list, draft, words: w);
    if (problems.isNotEmpty) return (list: null, problems: problems, id: null);
    final id = PriceListMigration.idFor(draft.name.trim(), {
      for (final c in list.colours) c.id,
    });
    final order = list.colours.fold(-1, (o, c) => c.order > o ? c.order : o);
    final colour = FactoryColour(
      id: id,
      name: draft.name.trim(),
      swatch: draft.swatch,
      grade: draft.grade,
      rates: {for (final m in _materialsOf(draft)) m: draft.rates[m]},
      order: order + 1,
    );
    return (
      list: list.copyWith(colours: [...list.colours, colour]),
      problems: const {},
      id: id,
    );
  }

  /// [list] with the colour [id] as [draft] says: its name, swatch, grade,
  /// materials and rates. **Its id does not change** — renaming a colour is
  /// renaming it everywhere it is chosen — and neither do whether it is
  /// active or where it is listed.
  static ({PriceList? list, Map<String, String> problems}) update(
    PriceList list,
    String id,
    ColourDraft draft, [
    Words w = const EnglishWords(),
  ]) {
    final was = list.colourById(id);
    if (was == null) {
      return (list: null, problems: {nameField: w.ccNotInList});
    }
    final problems = problemsWith(
      list,
      draft,
      editing: id,
      active: was.active,
      words: w,
    );
    if (problems.isNotEmpty) return (list: null, problems: problems);
    final now = was.copyWith(
      name: draft.name.trim(),
      swatch: draft.swatch,
      grade: draft.grade,
      rates: {for (final m in _materialsOf(draft)) m: draft.rates[m]},
    );
    return (list: _replace(list, now), problems: const {});
  }

  /// [list] with the colour [id] retired: no longer offered for a new
  /// choice, and kept — with its name, swatch and rates — for every design
  /// already in it.
  static PriceList retire(PriceList list, String id) {
    final was = list.colourById(id);
    if (was == null || !was.active) return list;
    return _replace(list, was.copyWith(active: false));
  }

  /// [list] with the retired colour [id] offered again — refused where an
  /// active colour has taken its name on a material it is sold in since.
  static ({PriceList? list, Map<String, String> problems}) restore(
    PriceList list,
    String id, [
    Words w = const EnglishWords(),
  ]) {
    final was = list.colourById(id);
    if (was == null) {
      return (list: null, problems: {nameField: w.ccNotInList});
    }
    if (was.active) return (list: list, problems: const {});
    final problems = problemsWith(
      list,
      ColourDraft.of(was),
      editing: id,
      words: w,
    );
    if (problems.isNotEmpty) return (list: null, problems: problems);
    return (
      list: _replace(list, was.copyWith(active: true)),
      problems: const {},
    );
  }

  static List<MaterialKind> _materialsOf(ColourDraft draft) => [
    for (final m in MaterialKind.values)
      if (draft.rates.containsKey(m)) m,
  ];

  static PriceList _replace(PriceList list, FactoryColour now) => list.copyWith(
    colours: [for (final c in list.colours) c.id == now.id ? now : c],
  );
}
