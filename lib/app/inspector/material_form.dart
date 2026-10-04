import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/design.dart';
import '../../domain/model/infill.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';
import 'infill_choices.dart';

/// The **Material** tool: glass or panel, and its look, for each part of the
/// design, whenever the user wants to say it.
///
/// It is on the workspace in every kind of design — the user's words, *for
/// a window and a sliding set, a clear tool in the workspace to choose the
/// material of a selected part*. Opened with a part picked, that part comes
/// first and is drawn out; the rest follow in the order the drawing reads
/// them. What is tapped is put on the part at once, so the drawing behind
/// changes with it — and nothing but what fills the part changes: not a
/// line, not a size, not another part.
class MaterialForm extends ConsumerWidget {
  /// The part the user had picked, if any.
  final String? focusId;

  const MaterialForm({super.key, this.focusId});

  /// The width below which it fills the screen.
  static const fullScreenBelow = 600.0;

  /// The part [selectedId] names or fills — a part picked, or an opening
  /// that is one part — or null when what is picked is not one.
  static String? partFor(Design design, String? selectedId) {
    if (selectedId == null) return null;
    final parts = Infill.partsOf(design);
    if (parts.any((p) => p.id == selectedId)) return selectedId;
    final opening = design.openings
        .where((o) => o.id == selectedId)
        .firstOrNull;
    if (opening != null && parts.any((p) => p.id == opening.sectionId)) {
      return opening.sectionId;
    }
    return null;
  }

  static Future<void> show(BuildContext context, {String? focusId}) =>
      showDialog<void>(
        context: context,
        builder: (context) => MaterialForm(focusId: focusId),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final design = ref.watch(workspaceProvider.select((s) => s.design));
    final controller = ref.read(workspaceProvider.notifier);
    final parts = Infill.partsOf(design);
    final ordered = [
      ...parts.where((p) => p.id == focusId),
      ...parts.where((p) => p.id != focusId),
    ];
    final theme = Theme.of(context);
    final p = context.palette;

    return LayoutBuilder(
      builder: (context, room) {
        final full = room.maxWidth < fullScreenBelow;
        final content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: p.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.format_paint_outlined,
                      color: p.primary,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Material',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: !full,
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                children: [
                  Text(
                    parts.isEmpty
                        ? 'Read your drawing first: its parts are what '
                              'glass or panel goes into.'
                        : 'Choose glass or panel for any part. Only what '
                              'fills the part changes — every line stays '
                              'where you drew it.',
                    style: theme.textTheme.bodySmall,
                  ),
                  for (final part in ordered) ...[
                    const SizedBox(height: 10),
                    PartChoice(
                      key: ValueKey('material-${part.id}'),
                      design: design,
                      part: part,
                      finish: part.finish,
                      highlighted: part.id == focusId,
                      onChanged: (finish) =>
                          controller.setFinish(part.id, finish),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                  child: const Text('Done'),
                ),
              ),
            ),
          ],
        );

        if (full) {
          return Dialog.fullscreen(
            backgroundColor: p.surface,
            child: SafeArea(child: content),
          );
        }
        return Dialog(
          backgroundColor: p.surface,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: room.maxHeight * 0.86,
            ),
            child: content,
          ),
        );
      },
    );
  }
}
