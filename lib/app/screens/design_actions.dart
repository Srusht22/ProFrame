import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/design_store.dart';
import '../state/pricing.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';
import 'design_information_screen.dart';
import 'workspace_screen.dart';

// What can be done with one kept design from its card — open it, edit its
// information, delete it — done one way wherever the card is: the designs
// list and a customer's page both call these, so the two cannot come to
// behave differently.

/// Whether a design is being opened, so a second tap while it opens does
/// nothing.
bool _opening = false;

/// Opens the design [summary] names exactly as it was kept — its drawing,
/// geometry, openings, internal lines, materials and sizes — straight into
/// the workspace, by its id. Nothing is asked on the way: what the design
/// is was said when it was begun and is kept in it, so no name, no
/// category and no New Design, and nothing new is made. A design removed
/// since the list was read says it could not be opened, begins nothing,
/// and the lists read again.
Future<void> openKeptDesign(
  BuildContext context,
  WidgetRef ref,
  DesignSummary summary,
) async {
  if (_opening) return;
  _opening = true;
  final Future<void> shown;
  try {
    final design = await ref.read(designStoreProvider).load(summary.id);
    if (!context.mounted) return;
    if (design == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${summary.shownName} could not be opened.')),
      );
      ref.read(designsRevisionProvider.notifier).changed();
      return;
    }
    ref.read(workspaceProvider.notifier).openDesign(design);
    shown = Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const WorkspaceScreen()));
  } finally {
    // Only the reading and the start of the opening are guarded, never the
    // time the design is open: the guard is shared by every list, so one
    // held while a design is on the screen would stop the next open.
    _opening = false;
  }
  await shown;
}

/// **Edit information**: what the design [summary] names is called. The
/// same design is renamed where it is kept, by its id — `DesignStore.retitle`
/// — and nothing else about it changes; the lists read it again.
Future<void> editDesignInformation(
  BuildContext context,
  WidgetRef ref,
  DesignSummary summary,
) async {
  final named = await Navigator.of(context).push<String>(
    MaterialPageRoute<String>(
      builder: (_) => DesignInformationScreen(
        name: summary.name,
        kind: summary.kind,
        customer: summary.customer,
      ),
    ),
  );
  if (named == null || named == summary.name) return;
  await ref.read(designStoreProvider).retitle(summary.id, named);
  ref.read(designsRevisionProvider.notifier).changed();
}

/// Deleting one design, from wherever it is offered: asked about first, by
/// the design's own name, and then removed — that design and nothing else.
///
/// **A design is not its customer.** Removing it takes its record and its
/// line in the index and leaves the customer — their name, phone, address
/// and notes — and every other design of theirs exactly as kept. There is
/// no way from here to delete a customer.
///
/// Nothing is removed until the user presses **Delete design**; Cancel, a
/// tap outside or back keeps it. Once removed it can be put back, whole,
/// for as long as the notice saying so stands. Answers whether it was
/// removed.
Future<bool> deleteDesign(
  BuildContext context,
  WidgetRef ref,
  DesignSummary summary,
) async {
  final sure = await showDialog<bool>(
    context: context,
    builder: (context) => DeleteDesignDialog(summary: summary),
  );
  if (sure != true || !context.mounted) return false;
  final store = ref.read(designStoreProvider);
  final design = await store.load(summary.id);
  // Its price goes with it (`DesignStore.remove`), and comes back with it.
  final price = await ref.read(priceRecordStoreProvider).load(summary.id);
  await store.remove(summary.id);
  ref.read(designsRevisionProvider.notifier).changed();
  if (!context.mounted) return true;
  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text('${summary.shownName} deleted'),
      action: design == null
          ? null
          : SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                await store.save(design);
                if (price != null) {
                  await ref
                      .read(priceRecordStoreProvider)
                      .save(design.id, price);
                }
                ref.read(designsRevisionProvider.notifier).changed();
                ref.read(priceRecordsRevisionProvider.notifier).changed();
              },
            ),
    ),
  );
  return true;
}

/// *Delete Basement Door?* — the design named, with its category and who
/// it is for, so there is no doubt which one is going, and a plain word on
/// what is not.
class DeleteDesignDialog extends StatelessWidget {
  final DesignSummary summary;

  const DeleteDesignDialog({super.key, required this.summary});

  static const confirmKey = ValueKey('confirm-delete');
  static const cancelKey = ValueKey('cancel-delete');

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final danger = Theme.of(context).colorScheme.error;
    final who = summary.customer?.trim() ?? '';
    return AlertDialog(
      // A small phone, or large lettering, scrolls the words rather than
      // pushing the buttons off the screen.
      scrollable: true,
      icon: Icon(Icons.delete_outline, color: danger),
      title: Text('Delete ${summary.shownName}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: p.shell,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.shownName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    summary.kind.label,
                    if (who.isNotEmpty) who,
                    '#${summary.number}',
                  ].join(' · '),
                  style: TextStyle(fontSize: 13, color: p.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            who.isEmpty
                ? 'This design will be removed from this device. No other '
                      'design is touched.'
                : 'This design will be removed from this device. $who, '
                      'their phone, address and notes, and their other '
                      'designs stay exactly as they are.',
          ),
          const SizedBox(height: 8),
          Text(
            'You can undo it straight afterwards.',
            style: TextStyle(fontSize: 13, color: p.muted),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: cancelKey,
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: confirmKey,
          style: FilledButton.styleFrom(
            backgroundColor: danger,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete design'),
        ),
      ],
    );
  }
}
