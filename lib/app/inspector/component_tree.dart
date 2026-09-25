import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dimensions/units.dart';
import '../../domain/hardware/opening_hardware.dart';
import '../../domain/model/design.dart';
import '../../domain/model/design_tree.dart';
import '../../domain/model/elements.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';

/// Every part of the design, listed.
///
/// It is the same set of parts the canvas draws and the model builds, in the
/// order a drawing reads. Picking one here picks it everywhere.
///
/// It walks `DesignTree` — the same tree the elevation and the solid walk —
/// rather than working the hierarchy out again from `parentId`. This is the
/// one place the user actually *sees* the tree named, so a list that decided
/// for itself what was inside what could tell them something the drawing
/// beside it does not show.
class ComponentTree extends ConsumerWidget {
  const ComponentTree({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspaceProvider);
    final controller = ref.read(workspaceProvider.notifier);
    final design = state.design;

    if (design.frame == null) {
      return Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          'Nothing has been read from your drawing yet.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    // An opening's hinges and handle are listed under the opening, because
    // that is whose they are. What is left here is what the user placed on
    // the design themselves.
    final placedByHand = OpeningHardware.placedByHand(design);
    final tree = DesignTree.of(design);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _Row(
          element: design.frame!,
          detail: '${Units.format(design.widthMm)} × '
              '${Units.label(design.heightMm)}',
          icon: Icons.crop_square,
          selected: state.selectedId == design.frame!.id,
          onTap: () => controller.select(design.frame!.id),
        ),
        for (final member in design.frameMembers)
          _Row(
            element: member,
            detail: Units.label(member.lengthMm),
            icon: member.run.isVerticalish
                ? Icons.vertical_align_center
                : Icons.horizontal_rule,
            indent: 1,
            selected: state.selectedId == member.id,
            onTap: () => controller.select(member.id),
          ),
        if (tree.barIds.isNotEmpty) const _GroupLabel('Bars'),
        for (final divider in [
          for (final id in tree.barIds) ?design.dividerById(id),
        ])
          _Row(
            element: divider,
            detail: '${Units.label(divider.lengthMm)} · '
                '${divider.segment.headingDegrees.toStringAsFixed(0)}°',
            icon: divider.isVertical
                ? Icons.vertical_align_center
                : Icons.horizontal_rule,
            indent: 1,
            selected: state.selectedId == divider.id,
            onTap: () => controller.select(divider.id),
          ),
        if (tree.sections.isNotEmpty) const _GroupLabel('Sections'),
        for (final branch in tree.sections)
          ..._sectionRows(design, state, controller, branch, 1),
        if (placedByHand.isNotEmpty) const _GroupLabel('Hardware'),
        for (final piece in placedByHand)
          _Row(
            element: piece,
            detail: '${Units.format(piece.at.x)}, '
                '${Units.label(piece.at.y)}',
            icon: Icons.radio_button_checked,
            indent: 1,
            selected: state.selectedId == piece.id,
            onTap: () => controller.select(piece.id),
          ),
        if (design.dimensions.isNotEmpty) const _GroupLabel('Dimensions'),
        for (final dimension in design.dimensions)
          _Row(
            element: dimension,
            detail: dimension.isStated ? 'you typed this' : 'as drawn',
            icon: Icons.straighten,
            indent: 1,
            selected: state.selectedId == dimension.id,
            onTap: () => controller.select(dimension.id),
          ),
        if (design.texts.isNotEmpty) const _GroupLabel('Notes'),
        for (final note in design.texts)
          _Row(
            element: note,
            detail: '',
            icon: Icons.sticky_note_2_outlined,
            indent: 1,
            selected: state.selectedId == note.id,
            onTap: () => controller.select(note.id),
          ),
      ],
    );
  }
}

/// One section and everything inside it.
///
/// A section that has lines drawn in it is a branch: its opening, then the
/// bars drawn inside it, then the sections those bars make — each of which
/// may be a branch in turn. This is the shape of the drawing, so it is the
/// shape of the list.
List<Widget> _sectionRows(
  Design design,
  WorkspaceState state,
  WorkspaceController controller,
  TreeSection branch,
  int indent,
) {
  final section = design.sectionById(branch.sectionId);
  if (section == null) return const [];

  final opening =
      branch.opens ? design.openingById(branch.openingId!) : null;
  final bars = [
    for (final id in branch.barIds) ?design.dividerById(id),
  ];
  final holds = !branch.isLeaf;

  return [
    _Row(
      element: section,
      detail: holds
          ? '${Units.format(section.widthMm)} × '
              '${Units.label(section.heightMm)} · holds ${branch.panes.length}'
          : '${Units.format(section.widthMm)} × '
              '${Units.label(section.heightMm)} · '
              '${section.finish.material.label}',
      icon: holds
          ? Icons.account_tree_outlined
          : section.finish.material.isGlazing
              ? Icons.window_outlined
              : Icons.rectangle_outlined,
      indent: indent,
      selected: state.selectedId == section.id,
      onTap: () => controller.select(section.id),
    ),
    if (opening != null)
      _Row(
        element: opening,
        title: design.nameOf(opening),
        detail: opening.mechanism.description,
        icon: Icons.door_front_door_outlined,
        indent: indent + 1,
        selected: state.selectedId == opening.id,
        onTap: () => controller.select(opening.id),
      ),
    for (final piece in design.hardware)
      if (design.sectionHolding(piece.parentId) == section.id)
        _Row(
          element: piece,
          detail: _placeOn(piece, section, opening),
          icon: piece.kind == HardwareKind.hinge
              ? Icons.blur_linear
              : Icons.radio_button_checked,
          indent: indent + 2,
          selected: state.selectedId == piece.id,
          onTap: () => controller.select(piece.id),
        ),
    for (final bar in bars)
      _Row(
        element: bar,
        detail: '${Units.label(bar.lengthMm)} · inside',
        icon: bar.isVertical
            ? Icons.vertical_align_center
            : Icons.horizontal_rule,
        indent: indent + 1,
        selected: state.selectedId == bar.id,
        onTap: () => controller.select(bar.id),
      ),
    for (final pane in branch.panes)
      ..._sectionRows(design, state, controller, pane, indent + 1),
  ];
}

class _Row extends StatelessWidget {
  final DesignElement element;
  final String detail;
  final IconData icon;
  final int indent;
  final bool selected;
  final VoidCallback onTap;

  /// What to call it, where the element's own label is not enough on its
  /// own. A design holds as many openings as the user marked, and three
  /// leaves in a row all call themselves "Hinged left": which one of them a
  /// row is has to come from the design, because it is the design that
  /// knows how many there are.
  final String? title;

  const _Row({
    required this.element,
    required this.detail,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.indent = 0,
    this.title,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          color: selected
              ? context.palette.selection.withValues(alpha: 0.12)
              : Colors.transparent,
          padding: EdgeInsets.fromLTRB(14 + indent * 16.0, 9, 14, 9),
          child: Row(
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? context.palette.selection : context.palette.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title ?? element.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w500,
                          ),
                    ),
                    if (detail.isNotEmpty)
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge,
        ),
      );
}

/// Where a piece of ironmongery sits on its leaf, measured the way the
/// opening's own panel measures it.
///
/// Along the edge it is on: up from the bottom on a side hung leaf, and in
/// from the left on a top or bottom hung one, whose hinges run along a rail.
/// Measuring *up* there gave both hinges of a bottom hung sash as "0 cm up",
/// which is true and says nothing about either of them.
String _placeOn(
  HardwareElement piece,
  SectionElement section,
  OpeningElement? opening,
) {
  final edge = opening?.mechanism.hingeEdge ?? opening?.mechanism.slideEdge;
  final alongARail = edge == OpeningEdge.top || edge == OpeningEdge.bottom;
  final figure = alongARail
      ? '${Units.label(piece.at.x - section.outline.left)} from the left'
      : '${Units.label(section.outline.bottom - piece.at.y)} up';
  return piece.kind == HardwareKind.hinge ? figure : '$figure · on the opening';
}
