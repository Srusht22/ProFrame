import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/pricing/pricing_access.dart';
import '../state/access.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';

/// What the user is told when they may look at the design open but not
/// change it — signed in without `designs.edit`, or nobody signed in once
/// the workshop has staff accounts.
///
/// Said under the drawing, before they find out by trying: nothing they do
/// to the design takes (`WorkspaceController`, and `DesignStore.save` as
/// well), and looking goes on as ever.
class ViewOnlyNote extends ConsumerWidget {
  const ViewOnlyNote({super.key});

  static const noteKey = ValueKey('view-only');

  static const message =
      'View only. You do not have permission to edit designs, so nothing '
      'you change here is kept. Sign in as somebody who may.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unsupported = ref.watch(
      workspaceProvider.select((s) => s.design.isUnsupported),
    );
    final mayEdit = ref.watch(actorProvider).can(Capability.designsEdit);
    // The staff are still being read: nothing is said until it is known.
    final known = ref.watch(staffMembersProvider).hasValue;
    if (unsupported || mayEdit || !known) return const SizedBox.shrink();
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    return Container(
      key: noteKey,
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.notice,
        border: Border(top: BorderSide(color: palette.hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 20, color: palette.onNotice),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: text.bodySmall?.copyWith(color: palette.onNotice),
            ),
          ),
        ],
      ),
    );
  }
}
