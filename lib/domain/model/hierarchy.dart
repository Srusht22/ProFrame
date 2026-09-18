import 'elements.dart';

/// What the design is allowed to say about what is inside what.
///
/// The hierarchy is the model:
///
/// ```
/// Door/Window                  the root — never an opening
/// ├── Outer frame              not a section, so not a parent and not a child
/// ├── Section A                fixed
/// ├── Section B                fixed
/// ├── Section X                the opening
/// │    ├── Divider             a line drawn inside it
/// │    ├── Section  glass      a pane that line makes
/// │    ├── Section  panel
/// │    └── Hardware            its hinges and its handle
/// └── Section C                fixed
/// ```
///
/// Every rule below is here so that an impossible document cannot be built,
/// rather than being maintained by each place that edits one. Four states
/// used to be expressible, and each was a phantom — stored in the document,
/// listed in the component tree, saved to disk, and built by neither view:
///
/// - **An opening on the root.** An opening naming the frame could be
///   stored. The frame is not a section, so nothing was ever built from it,
///   but the document said the whole door opened. It cannot be written now.
/// - **An opening on a section that has gone.** A dangling reference that
///   survived every edit and every save.
/// - **Two openings on one section.** Both stored; the first won everywhere
///   it was looked up, the second followed the design about for ever.
/// - **A section inside itself.** The section dropped out of the tree
///   altogether, taking its panes with it — geometry the user drew, lost to
///   a loop.
///
/// Nothing here removes geometry. A section or a bar whose parent has gone
/// goes back to dividing the design, which is what everything does until the
/// user puts it somewhere; only a record that says something impossible —
/// the second opening on a section — is dropped, and the user could never
/// have made one.
abstract final class Hierarchy {
  /// How deep the tree may go before a document is treated as looping.
  ///
  /// A drawing this deep is a sash in a sash in a sash; past it, something is
  /// wrong with the document rather than ambitious about the design.
  static const int deepest = 8;

  /// [sections] with any parent that is not a section of this design, or
  /// that leads back round to the section itself, cleared.
  static List<SectionElement> settle(List<SectionElement> sections) {
    final byId = {for (final section in sections) section.id: section};
    var changed = false;
    final out = <SectionElement>[];

    for (final section in sections) {
      if (_reaches(section, byId)) {
        out.add(section);
        continue;
      }
      changed = true;
      out.add(section.copyWith(clearParent: true));
    }
    return changed ? out : sections;
  }

  /// [dividers] with any parent that is not one of [sections] cleared, so a
  /// bar always divides either the design or a section that is really there.
  static List<DividerElement> settleDividers(
    List<DividerElement> dividers,
    List<SectionElement> sections,
  ) {
    final live = {for (final section in sections) section.id};
    if (dividers.every((d) => d.parentId == null || live.contains(d.parentId))) {
      return dividers;
    }
    return [
      for (final divider in dividers)
        if (divider.parentId == null || live.contains(divider.parentId))
          divider
        else
          divider.copyWith(clearParent: true),
    ];
  }

  /// The openings this design can have: one per section, each naming a
  /// section that exists.
  ///
  /// The frame is not a section, so an opening can never name it. That is
  /// what makes *the whole door or window is not an opening* a fact about
  /// the model rather than a rule someone has to remember.
  static List<OpeningElement> settleOpenings(
    List<OpeningElement> openings,
    List<SectionElement> sections,
  ) {
    final live = {for (final section in sections) section.id};
    final taken = <String>{};
    var changed = false;
    final out = <OpeningElement>[];

    for (final opening in openings) {
      if (!live.contains(opening.sectionId) || !taken.add(opening.sectionId)) {
        changed = true;
        continue;
      }
      out.add(opening);
    }
    return changed ? out : openings;
  }

  /// True when [section] can be walked up to a root without meeting a parent
  /// that is not there, and without coming back to itself.
  static bool _reaches(
    SectionElement section,
    Map<String, SectionElement> byId,
  ) {
    var at = section;
    for (var depth = 0; depth < deepest; depth++) {
      final parent = at.parentId;
      if (parent == null) return true;
      if (parent == section.id) return false;
      final next = byId[parent];
      if (next == null) return false;
      at = next;
    }
    return false;
  }
}
