import 'design.dart';
import 'elements.dart';

/// The design as a tree: what is inside what.
///
/// ```
/// Door/Window
/// ├── Frame                the outline, and nothing else's parent
/// ├── Bars                 the lines that divide the design
/// └── Sections             the main divisions, in reading order
///      ├── Opening         where the user marked one
///      ├── Bars            the lines drawn inside that section
///      └── Sections        the panes those lines make, each a branch again
/// ```
///
/// The hierarchy is already in the model — `parentId` on every divider and
/// every section — and this is that hierarchy read once. The elevation and
/// the solid both walk it, so there is one answer to what is inside what
/// rather than each view working it out again and the two disagreeing.
///
/// **It holds no geometry.** Every part is named by its id and looked up in
/// the design when it is drawn, so nothing here can drift from the design or
/// outlive an edit to it. The frame is not a section, so it is not a branch:
/// it cannot be inside anything and nothing is inside it.
///
/// A window is never an opening. Only a section the user marked opens, and it
/// appears as exactly one branch of this tree — never the root.
class DesignTree {
  /// The frame, or null when the outline has not been read yet.
  final String? frameId;

  /// The bars that divide the design as a whole.
  final List<String> barIds;

  /// The main divisions, in reading order.
  final List<TreeSection> sections;

  const DesignTree({
    required this.frameId,
    required this.barIds,
    required this.sections,
  });

  /// [design] read as a tree.
  static DesignTree of(Design design) => DesignTree(
        frameId: design.frame?.id,
        barIds: [for (final bar in design.topLevelDividers) bar.id],
        sections: [
          for (final section in design.topLevelSections)
            _branch(design, section, 0),
        ],
      );

  static TreeSection _branch(Design design, SectionElement section, int depth) {
    // The model's own guard against a cycle, kept here too: a tree that can
    // be walked is the whole point of this file.
    final panes = depth > 6
        ? const <TreeSection>[]
        : [
            for (final pane in design.childSectionsOf(section.id))
              _branch(design, pane, depth + 1),
          ];
    return TreeSection(
      sectionId: section.id,
      openingId: design.openingOf(section.id)?.id,
      barIds: [for (final bar in design.childDividersOf(section.id)) bar.id],
      panes: panes,
    );
  }

  /// Every section of the design, at any depth, parents before their panes.
  Iterable<TreeSection> get everySection =>
      sections.expand((section) => section.andItsPanes);

  /// The sections that open — one branch each, and never the whole design.
  List<TreeSection> get openings =>
      [for (final section in everySection) if (section.opens) section];

  /// The main divisions that do not open.
  List<TreeSection> get fixedSections =>
      [for (final section in sections) if (!section.opens) section];

  /// Every bar on the design, at any depth: the ones that divide the design
  /// and the ones drawn inside a section.
  Iterable<String> get everyBar sync* {
    yield* barIds;
    for (final section in everySection) {
      yield* section.barIds;
    }
  }
}

/// One section, and what the user drew inside it.
class TreeSection {
  final String sectionId;

  /// The opening on this section, or null when it does not open.
  final String? openingId;

  /// The bars drawn inside this section. They divide it and nothing else.
  final List<String> barIds;

  /// The panes those bars make, each a branch in its own right.
  final List<TreeSection> panes;

  const TreeSection({
    required this.sectionId,
    required this.openingId,
    required this.barIds,
    required this.panes,
  });

  /// True when the user marked this section, which is the only way a section
  /// ever opens.
  bool get opens => openingId != null;

  /// True when the user drew nothing inside it, so it is one pane.
  bool get isLeaf => panes.isEmpty;

  /// This section and every pane under it, itself first.
  Iterable<TreeSection> get andItsPanes sync* {
    yield this;
    for (final pane in panes) {
      yield* pane.andItsPanes;
    }
  }
}
