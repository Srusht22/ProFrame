import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/design.dart';
import '../../domain/model/elements.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';

/// Every part of the design, listed.
///
/// It is the same set of parts the canvas draws and the model builds, in the
/// order a drawing reads. Picking one here picks it everywhere.
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

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _Row(
          element: design.frame!,
          detail: '${design.widthMm.round()} × ${design.heightMm.round()} mm',
          icon: Icons.crop_square,
          selected: state.selectedId == design.frame!.id,
          onTap: () => controller.select(design.frame!.id),
        ),
        for (final member in design.frameMembers)
          _Row(
            element: member,
            detail: '${member.lengthMm.round()} mm',
            icon: member.run.isVerticalish
                ? Icons.vertical_align_center
                : Icons.horizontal_rule,
            indent: 1,
            selected: state.selectedId == member.id,
            onTap: () => controller.select(member.id),
          ),
        if (design.topLevelDividers.isNotEmpty) const _GroupLabel('Bars'),
        for (final divider in design.topLevelDividers)
          _Row(
            element: divider,
            detail: '${divider.lengthMm.round()} mm · '
                '${divider.segment.headingDegrees.toStringAsFixed(0)}°',
            icon: divider.isVertical
                ? Icons.vertical_align_center
                : Icons.horizontal_rule,
            indent: 1,
            selected: state.selectedId == divider.id,
            onTap: () => controller.select(divider.id),
          ),
        if (design.topLevelSections.isNotEmpty)
          const _GroupLabel('Sections'),
        for (final section in design.topLevelSections)
          ..._sectionRows(design, state, controller, section, 1),
        if (design.hardware.isNotEmpty) const _GroupLabel('Hardware'),
        for (final piece in design.hardware)
          _Row(
            element: piece,
            detail: '${piece.at.x.round()}, ${piece.at.y.round()} mm',
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
  SectionElement section,
  int indent,
) {
  final opening = design.openingOf(section.id);
  final bars = design.childDividersOf(section.id);
  final children = design.childSectionsOf(section.id);
  final holds = children.isNotEmpty;

  return [
    _Row(
      element: section,
      detail: holds
          ? '${section.widthMm.round()} × ${section.heightMm.round()} mm · '
              'holds ${children.length}'
          : '${section.widthMm.round()} × ${section.heightMm.round()} mm · '
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
        detail: opening.mechanism.description,
        icon: Icons.door_front_door_outlined,
        indent: indent + 1,
        selected: state.selectedId == opening.id,
        onTap: () => controller.select(opening.id),
      ),
    for (final bar in bars)
      _Row(
        element: bar,
        detail: '${bar.lengthMm.round()} mm · inside',
        icon: bar.isVertical
            ? Icons.vertical_align_center
            : Icons.horizontal_rule,
        indent: indent + 1,
        selected: state.selectedId == bar.id,
        onTap: () => controller.select(bar.id),
      ),
    for (final child in children)
      ..._sectionRows(design, state, controller, child, indent + 1),
  ];
}

class _Row extends StatelessWidget {
  final DesignElement element;
  final String detail;
  final IconData icon;
  final int indent;
  final bool selected;
  final VoidCallback onTap;

  const _Row({
    required this.element,
    required this.detail,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.indent = 0,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          color: selected
              ? AppTheme.selection.withValues(alpha: 0.12)
              : Colors.transparent,
          padding: EdgeInsets.fromLTRB(14 + indent * 16.0, 9, 14, 9),
          child: Row(
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? AppTheme.selection : AppTheme.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      element.label,
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
