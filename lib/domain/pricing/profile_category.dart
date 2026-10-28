import '../model/design.dart';
import '../model/materials.dart';
import '../text/names.dart';
import '../text/words.dart';

/// A kind of profile within one material, each sold at a rate of its own.
///
/// Aluminium is two: **System Aluminium** and **Bend Shoulder Aluminium**,
/// different extrusions the factory buys and prices apart. They are a
/// question about the *price*, not about the shape: the frame is drawn and
/// built in its material (`MaterialKind.aluminium`) whichever it is, so
/// nothing here reaches the geometry, the technical drawing or the solid.
///
/// A material with no categories — uPVC, wood, steel — is priced by its
/// own normal rate, exactly as before. A later category is one more value
/// here and one more rate in the list; nothing that prices changes.
///
/// **Which category a part is, is never worked out.** Nothing in the
/// drawing says whether a line is a System or a Bend Shoulder extrusion,
/// so it is the user's choice ([ProfileAllocation]), and a part nobody has
/// chosen for is not priced at either rate.
enum ProfileCategory {
  systemAluminium('System Aluminium', MaterialKind.aluminium),
  bendShoulderAluminium('Bend Shoulder Aluminium', MaterialKind.aluminium);

  const ProfileCategory(this.label, this.material);

  final String label;

  /// The material it is a kind of.
  final MaterialKind material;

  /// The categories [material] is sold in — none for a material priced by
  /// one rate.
  static List<ProfileCategory> of(MaterialKind material) => [
    for (final c in values)
      if (c.material == material) c,
  ];

  /// Whether [material]'s normal profile is priced by category.
  static bool divides(MaterialKind material) => of(material).isNotEmpty;

  /// The category kept as [name], or null for anything else.
  static ProfileCategory? byName(Object? name) =>
      values.where((c) => c.name == name).firstOrNull;
}

/// Whether a part cut from the normal profile is the frame's border or a
/// line — a bar of the design or a line inside an opening. They share a
/// rate and are measured, priced and shown apart.
enum ProfilePart {
  border('Border'),
  lines('Internal lines');

  const ProfilePart(this.label);
  final String label;

  static ProfilePart? byName(Object? name) =>
      values.where((p) => p.name == name).firstOrNull;
}

/// One part of a design cut from the normal profile: a side of the frame or
/// a line. Named so the user can say which category it is.
class AllocatedPart {
  /// The key its category is kept under: the frame member's id or the
  /// bar's.
  final String key;
  final String name;

  /// [name], said in a language.
  final String Function(Words w)? sayName;
  final ProfilePart part;
  final MaterialKind material;

  /// The category it is priced as, or null where nobody has said.
  final ProfileCategory? category;

  const AllocatedPart({
    required this.key,
    required this.name,
    required this.part,
    required this.material,
    required this.category,
    this.sayName,
  });

  /// [name], in [w].
  String nameIn(Words w) => sayName?.call(w) ?? name;

  /// Whether it needs a category and has none.
  bool get unallocated => ProfileCategory.divides(material) && category == null;
}

/// Which category each part of a design's normal profile is, as the user
/// said: one choice for the whole design, and any part set on its own.
abstract final class ProfileAllocation {
  /// The category the part kept under [key] is, in [design]: its own
  /// choice where it has one, else the design's — never a guess.
  static ProfileCategory? of(Design design, String key) =>
      design.pricing.profileCategoryOf[key] ?? design.pricing.profileCategory;

  /// Every part of [design] cut from the normal profile: each side of the
  /// frame that carries a member, then every bar, in the order the design
  /// keeps them.
  static List<AllocatedPart> partsOf(Design design) {
    final frame = design.frame;
    if (frame == null) return const [];
    String lineName(Words w, int n, String? parentId) => parentId != null
        ? w.lineInside(n, _openingName(w, design, parentId))
        : w.lineNumbered(n);
    return [
      for (final member in design.frameMembers)
        AllocatedPart(
          key: member.id,
          name: member.placement,
          sayName: (w) => placementIn(w, member.placement),
          part: ProfilePart.border,
          material: frame.finish.material,
          category: _fits(of(design, member.id), frame.finish.material),
        ),
      for (final (i, d) in design.dividers.indexed)
        AllocatedPart(
          key: d.id,
          name: lineName(
            const EnglishWords(),
            i + 1,
            d.isInternal ? d.parentId : null,
          ),
          sayName: (w) => lineName(w, i + 1, d.isInternal ? d.parentId : null),
          part: ProfilePart.lines,
          material: d.finish.material,
          category: _fits(of(design, d.id), d.finish.material),
        ),
    ];
  }

  /// The parts that need a category and have none.
  static List<AllocatedPart> unallocatedIn(Design design) => [
    for (final p in partsOf(design))
      if (p.unallocated) p,
  ];

  /// Whether any part of [design] is in a material priced by category.
  static bool asksIn(Design design) =>
      partsOf(design).any((p) => ProfileCategory.divides(p.material));

  /// A category is only what it is for its own material: one chosen for
  /// aluminium says nothing about a uPVC bar.
  static ProfileCategory? _fits(ProfileCategory? c, MaterialKind material) =>
      c != null && c.material == material ? c : null;

  static String _openingName(Words w, Design design, String? parentId) {
    final opening = design.openingHolding(parentId);
    if (opening == null) return w.partA;
    return design.plainNameOfIn(w, opening);
  }
}
