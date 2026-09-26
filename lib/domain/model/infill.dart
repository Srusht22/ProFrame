import 'design.dart';
import 'design_tree.dart';
import 'elements.dart';
import 'materials.dart';

/// The parts of a design that are filled — with glass or with a panel — and
/// how what the user says about them is put on them.
///
/// **A part is one the user's own lines made.** Every part here is a pane of
/// the design tree: a main division nobody drew inside, or a pane of a
/// section somebody did — inside an opening as much as outside one. Nothing
/// here divides a part, joins two, adds a line or moves one, so saying what
/// a part is made of can never change what it is: the user's words, *material
/// selection changes material and appearance, not geometry*.
abstract final class Infill {
  /// Every part, in the order the drawing reads them.
  static List<SectionElement> partsOf(Design design) => [
    for (final branch in DesignTree.of(design).everySection)
      if (branch.isLeaf) ?design.sectionById(branch.sectionId),
  ];

  /// Whether [finish] is glass, of any look.
  static bool isGlass(Finish finish) => finish.material.isGlazing;

  /// Whether [finish] is a panel, of any colour.
  static bool isPanel(Finish finish) => finish.material == MaterialKind.panel;

  /// [design] with each part named in [finishes] filled as given, and
  /// nothing else touched — not an outline, not a bar, not another part.
  static Design fill(Design design, Map<String, Finish> finishes) {
    if (finishes.isEmpty) return design;
    return design.copyWith(
      sections: [
        for (final section in design.sections)
          if (finishes[section.id] case final finish?)
            section.copyWith(finish: finish)
          else
            section,
      ],
    );
  }

  /// What the user said a whole door is built of, put on it: every part
  /// there is now filled with [finish], and every part a later line makes
  /// starts as it too.
  static Design fillWhole(
    Design design,
    Construction construction,
    Finish finish,
  ) => fill(design, {
    for (final part in partsOf(design)) part.id: finish,
  }).copyWith(construction: construction, infill: finish);

  /// What to call [part] where the user is choosing between parts: its place
  /// in the drawing's reading order. [whereIs] says which opening it is in.
  static String nameOf(Design design, SectionElement part) {
    final index = partsOf(design).indexWhere((p) => p.id == part.id);
    return 'Part ${index + 1}';
  }

  /// Where [part] is, in the user's own terms: the opening it is, or is
  /// inside, or that it is a fixed part of the design.
  static String whereIs(Design design, SectionElement part) {
    final opening =
        design.openingOf(part.id) ?? design.openingHolding(part.parentId);
    return opening == null ? 'Fixed' : design.nameOf(opening);
  }
}
