import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../core/i18n/product_labels.dart';
import '../../core/i18n/strings.dart';
import '../../domain/panel.dart';
import '../../domain/product/opening.dart';
import '../../domain/product/product_basics.dart';

import 'notice.dart';

/// What the user asked to change about a panel.
///
/// A result object rather than a pile of callbacks, so the sheet stays a
/// dumb form and every edit goes through the controller in one place.
sealed class PanelEdit {
  const PanelEdit();
}

class MakeFixed extends PanelEdit {
  const MakeFixed();
}

class SetOpening extends PanelEdit {
  final OpeningSpec spec;

  const SetOpening(this.spec);
}

class SetMesh extends PanelEdit {
  final bool value;

  const SetMesh(this.value);
}

class SetEmpty extends PanelEdit {
  final bool value;

  const SetEmpty(this.value);
}

/// Add a note when [noteId] is null, otherwise edit that one.
class EditNote extends PanelEdit {
  final String? noteId;

  const EditNote(this.noteId);
}

class DeleteNote extends PanelEdit {
  final String noteId;

  const DeleteNote(this.noteId);
}

class ToggleNoteVisible extends PanelEdit {
  final String noteId;
  final bool visible;

  const ToggleNoteVisible(this.noteId, this.visible);
}

/// The panel properties sheet, opened by a long press (spec Phase 2, item 5).
///
/// Every mechanism listed here has geometry behind it and an animation that
/// shows it, because a choice that does nothing is what the spec forbids
/// (section 3C). Phase 2 offered hinged alone; Phase 3 added tilt and sliding
/// along with their motion, so they appear now.
Future<PanelEdit?> showPanelSheet(
  BuildContext context, {
  required Panel panel,
  required ViewingSide viewedFrom,
}) =>
    showModalBottomSheet<PanelEdit>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) => _PanelSheet(panel: panel, viewedFrom: viewedFrom),
    );

class _PanelSheet extends StatelessWidget {
  final Panel panel;
  final ViewingSide viewedFrom;

  const _PanelSheet({required this.panel, required this.viewedFrom});

  void _close(BuildContext context, PanelEdit edit) =>
      Navigator.of(context).pop(edit);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.s;
    final opening = panel.opening;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${s.number(panel.widthMm)} × ${s.number(panel.heightMm)} '
              '${s(T.unitMillimetre)}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),

            Text(s(T.panelType), style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: _BigChoice(
                    // Both the factory code and the plain word, because a new
                    // salesperson does not yet know what CH means.
                    code: PanelBehaviour.fixed.code,
                    label: s.behaviour(PanelBehaviour.fixed),
                    selected: panel.behaviour.isFixed,
                    onPressed: () => _close(context, const MakeFixed()),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _BigChoice(
                    code: PanelBehaviour.opening.code,
                    label: s.behaviour(PanelBehaviour.opening),
                    selected: panel.behaviour.isOpening,
                    onPressed: () => _close(
                      context,
                      SetOpening(
                        opening?.copyWith(isConfirmed: true) ??
                            const OpeningSpec(
                              hingeSide: HingeSide.left,
                              direction: OpeningDirection.inward,
                              isConfirmed: true,
                            ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (opening != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(s(T.howItOpens), style: theme.textTheme.titleMedium),
              // Handing is meaningless without saying which side you are
              // looking from, so it is stated here every time.
              Text(
                s.viewingSide(viewedFrom),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.mutedText),
              ),
              const SizedBox(height: AppSpacing.xs),
              _OptionRow<OpeningMechanism>(
                options: OpeningMechanism.values,
                labelOf: s.mechanism,
                selected: opening.mechanism,
                onSelected: (mechanism) => _close(
                  context,
                  SetOpening(
                    opening.copyWith(mechanism: mechanism, isConfirmed: true),
                  ),
                ),
              ),
              // A hinge side is only asked for when the mechanism has one: a
              // tilt is always bottom-hung and a slide has a direction
              // instead, so the question would have no answer.
              if (opening.mechanism.needsHingeSide) ...[
                const SizedBox(height: AppSpacing.xs),
                _OptionRow<HingeSide>(
                  options: HingeSide.values,
                  labelOf: s.hingeSide,
                  selected: opening.hingeSide,
                  onSelected: (side) => _close(
                    context,
                    SetOpening(
                      opening.copyWith(hingeSide: side, isConfirmed: true),
                    ),
                  ),
                ),
              ],
              if (opening.mechanism.needsSwingDirection) ...[
                const SizedBox(height: AppSpacing.xs),
                _OptionRow<OpeningDirection>(
                  options: OpeningDirection.values,
                  labelOf: s.openingDirection,
                  selected: opening.direction,
                  onSelected: (direction) => _close(
                    context,
                    SetOpening(
                      opening.copyWith(direction: direction, isConfirmed: true),
                    ),
                  ),
                ),
              ],
              if (!opening.isConfirmed) ...[
                const SizedBox(height: AppSpacing.xs),
                Notice(
                  tone: NoticeTone.caution,
                  message: s(T.confirmHowItOpens),
                ),
              ],
            ],

            const SizedBox(height: AppSpacing.md),
            Text(s(T.glass), style: theme.textTheme.titleMedium),
            SwitchListTile(
              value: panel.hasMesh,
              onChanged: (value) => _close(context, SetMesh(value)),
              title: Text(s(T.mesh)),
              subtitle: Text(s(T.meshHelp)),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value: panel.isEmpty,
              onChanged: (value) => _close(context, SetEmpty(value)),
              title: Text(s(T.emptyOpening)),
              subtitle: Text(s(T.emptyOpeningHelp)),
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: AppSpacing.sm),
            Text(s(T.note), style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            for (final note in panel.notes)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Notice(
                        message: note.text,
                        tone: note.isVisible
                            ? NoticeTone.information
                            : NoticeTone.caution,
                      ),
                    ),
                    IconButton(
                      // Hiding is not deleting (spec section 8B).
                      icon: Icon(
                        note.isVisible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      tooltip: note.isVisible ? s(T.hideNote) : s(T.showNote),
                      onPressed: () => _close(
                        context,
                        ToggleNoteVisible(note.id, !note.isVisible),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: s(T.editNote),
                      onPressed: () => _close(context, EditNote(note.id)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: s(T.deleteNote),
                      onPressed: () => _close(context, DeleteNote(note.id)),
                    ),
                  ],
                ),
              ),
            OutlinedButton.icon(
              icon: const Icon(Icons.add_comment_outlined),
              label: Text(s(T.addNote)),
              onPressed: () => _close(context, const EditNote(null)),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

/// A CH / Z button: big, labelled, and marked selected by more than colour.
class _BigChoice extends StatelessWidget {
  final String code;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const _BigChoice({
    required this.code,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.cream : AppColors.deepGreen;
    return Semantics(
      button: true,
      selected: selected,
      label: selected
          ? '$code, $label, ${context.s(T.selected)}'
          : '$code, $label',
      child: ExcludeSemantics(
        child: Material(
          color: selected ? AppColors.deepGreen : AppColors.canvasSurface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              constraints: const BoxConstraints(
                minHeight: AppSizing.primaryChoiceMinHeight,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: selected ? AppColors.deepGreen : AppColors.outline,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    code,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
                  ),
                  Text(label, style: TextStyle(color: foreground)),
                  if (selected)
                    Icon(Icons.check, size: 18, color: foreground),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A wrapped row of choices, each at least the minimum touch size.
class _OptionRow<T> extends StatelessWidget {
  final List<T> options;
  final String Function(T) labelOf;
  final T selected;
  final ValueChanged<T> onSelected;

  const _OptionRow({
    required this.options,
    required this.labelOf,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final option in options)
            ChoiceChip(
              label: Text(labelOf(option)),
              selected: option == selected,
              onSelected: (_) => onSelected(option),
              // Chips default well under 48dp tall.
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
            ),
        ],
      );
}
