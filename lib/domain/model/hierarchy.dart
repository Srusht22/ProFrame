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

  /// [dividers] and [sections] with every parent that names a section which
  /// *opens* rewritten to name the opening itself.
  ///
  /// This is the one stored form. A thing inside an opening names the
  /// **opening**, not the region the opening happens to be on. The
  /// difference matters because the two have very different lives: an
  /// `OpeningElement` is authored — it exists because the user drew a mark —
  /// while a `SectionElement` is derived, and `SectionBuilder` deletes and
  /// rebuilds every one of them on every edit. A child anchored to a section
  /// is anchored to the least stable object in the model; a child anchored
  /// to the opening is anchored to the user's own decision.
  ///
  /// Both forms are read everywhere — `Design.childDividersOf` and its
  /// neighbours resolve either — so nothing that asks the old question gets
  /// a different answer. Only what is *written down* changes, and it changes
  /// to the form that survives.
  ///
  /// Hardware is deliberately left naming the section for now. Moving it
  /// would mean changing how the solid finds a leaf's hinges, and that is
  /// not this phase's to touch.
  static ({List<DividerElement> dividers, List<SectionElement> sections})
      underOpenings(
    List<DividerElement> dividers,
    List<SectionElement> sections,
    List<OpeningElement> openings,
  ) {
    if (openings.isEmpty) return (dividers: dividers, sections: sections);

    final openingOn = <String, String>{
      for (final opening in openings) opening.sectionId: opening.id,
    };
    if (openingOn.isEmpty) return (dividers: dividers, sections: sections);

    return (
      dividers: [
        for (final divider in dividers)
          if (openingOn[divider.parentId] case final owner?)
            divider.copyWith(parentId: owner)
          else
            divider,
      ],
      sections: [
        for (final section in sections)
          if (openingOn[section.parentId] case final owner?)
            section.copyWith(parentId: owner)
          else
            section,
      ],
    );
  }

  /// [sections] with any parent that is not a section of this design, or
  /// that leads back round to the section itself, cleared.
  static List<SectionElement> settle(
    List<SectionElement> sections, [
    List<OpeningElement> openings = const [],
  ]) {
    // A parent may name an opening as well as a section, and an opening is
    // as real a parent as a section is. It is walked up through the section
    // it is on, so a loop is still a loop.
    final onwards = <String, String>{
      for (final opening in openings) opening.id: opening.sectionId,
    };
    final byId = {for (final section in sections) section.id: section};
    var changed = false;
    final out = <SectionElement>[];

    for (final section in sections) {
      if (_reaches(section, byId, onwards)) {
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
    List<SectionElement> sections, [
    List<OpeningElement> openings = const [],
  ]) {
    final live = {
      for (final section in sections) section.id,
      for (final opening in openings) opening.id,
    };
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
    Map<String, String> openingOnSection,
  ) {
    var at = section;
    for (var depth = 0; depth < deepest; depth++) {
      // A parent that names an opening is followed on to the section that
      // opening is on, which is where the walk carries on from.
      final parent = openingOnSection[at.parentId] ?? at.parentId;
      if (parent == null) return true;
      if (parent == section.id) return false;
      final next = byId[parent];
      if (next == null) return false;
      at = next;
    }
    return false;
  }
}
