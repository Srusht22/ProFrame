import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/design.dart';
import '../../infrastructure/design_store.dart';
import '../canvas/design_preview.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';

/// The months as a date on a card writes them.
const monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// The mark of a design's category, wherever one is shown: on a card, on a
/// filter chip, beside a design's information.
IconData kindIcon(DesignKind kind) => switch (kind) {
  DesignKind.door => Icons.door_front_door_outlined,
  DesignKind.window => Icons.window_outlined,
  DesignKind.both => Icons.splitscreen_outlined,
  DesignKind.sliding => Icons.door_sliding_outlined,
  // A shape whose sides are not square: the outline of a triangle.
  DesignKind.angled => Icons.change_history_outlined,
  // A category this version does not know: said to be one, not drawn as a
  // door or a window.
  DesignKind.unsupported => Icons.help_outline,
};

/// The picture of a kept design: the design itself, read from the store
/// by its id when the picture is built — so only the designs on the screen
/// are ever read — and drawn by `DesignPreview` from its own saved geometry,
/// read again only when it has been edited since. A customer's page shows
/// each of their designs by this.
///
/// While it is being read the card shows the empty sheet; a design with
/// nothing drawn says *Nothing drawn yet*; one that cannot be read says
/// *Preview unavailable* rather than looking empty. None of them is ever
/// anything standing in for the design. The picture is only a picture:
/// opening the card reads the design afresh from the store.
class DesignPicture extends ConsumerStatefulWidget {
  final DesignSummary summary;

  const DesignPicture({super.key, required this.summary});

  @override
  ConsumerState<DesignPicture> createState() => _DesignPictureState();
}

class _DesignPictureState extends ConsumerState<DesignPicture> {
  late Future<Design?> _design = _read();

  Future<Design?> _read() async {
    try {
      return await ref.read(designStoreProvider).load(widget.summary.id);
    } on Object {
      return null;
    }
  }

  @override
  void didUpdateWidget(DesignPicture old) {
    super.didUpdateWidget(old);
    if (old.summary.id != widget.summary.id ||
        old.summary.updatedAt != widget.summary.updatedAt) {
      _design = _read();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Design?>(
    future: _design,
    builder: (context, read) => switch ((read.connectionState, read.data)) {
      (_, final design?) => DesignPreview(design: design),
      // Read, and nothing there to draw from.
      (ConnectionState.done, null) => const PreviewPlaceholder.unavailable(),
      // Still being read: the sheet, and nothing on it pretending to be
      // the design.
      _ => ColoredBox(color: context.palette.cad.sheet),
    },
  );
}

/// What can be done with a design from its card.
enum DesignAction { open, information, duplicate, delete }

/// The sheet of what can be done with one design: each thing on a row of
/// its own, in words, with the one that cannot be seen being undone —
/// delete — last and in red.
class DesignActionsSheet extends StatelessWidget {
  final DesignSummary summary;

  /// Which of the things are offered — all of them unless said.
  final Set<DesignAction> actions;

  const DesignActionsSheet({
    super.key,
    required this.summary,
    this.actions = const {...DesignAction.values},
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final danger = Theme.of(context).colorScheme.error;
    Widget row(
      DesignAction action,
      IconData icon,
      String label,
      String detail, {
      Color? colour,
    }) => !actions.contains(action)
        ? const SizedBox.shrink()
        : ListTile(
            key: ValueKey('design-action-${action.name}'),
            leading: Icon(icon, color: colour ?? p.primary),
            title: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colour ?? p.ink,
              ),
            ),
            subtitle: Text(
              detail,
              style: TextStyle(color: p.muted, fontSize: 12.5),
            ),
            onTap: () => Navigator.of(context).pop(action),
          );

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.shownName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (summary.customer?.trim() case final who?
                            when who.isNotEmpty)
                          Text(
                            who,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: p.muted),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '#${summary.number}',
                    style: TextStyle(fontSize: 12, color: p.muted),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            row(
              DesignAction.open,
              Icons.arrow_forward,
              'Open',
              'Carry on with this design.',
            ),
            // A design of a category this version does not know is kept
            // exactly as it was saved: renaming or copying it here would
            // write it again in this version's words. Opening and deleting
            // it are as for any design.
            if (summary.kind != DesignKind.unsupported) ...[
              row(
                DesignAction.information,
                Icons.drive_file_rename_outline,
                'Edit information',
                'Change the name of this design.',
              ),
              row(
                DesignAction.duplicate,
                Icons.copy_all_outlined,
                'Duplicate',
                'A copy to change without touching this one.',
              ),
            ],
            row(
              DesignAction.delete,
              Icons.delete_outline,
              'Delete',
              'Remove it from this device.',
              colour: danger,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
