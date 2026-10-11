import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';

/// What the user is told when the design open is of a category this version
/// does not know.
///
/// Said under the drawing, in every view, in the style of the other notes
/// there, and in words — never *enum* or *parse*: the design was made by a
/// newer ProFrame, or names a category this one does not recognise; it is
/// shown exactly as it was saved; it cannot be changed here, so nothing in
/// it is lost; and its own category is kept. It asks nothing and nothing
/// waits on it — it is the reason nothing the user does to the design
/// takes, said before they find out by trying.
class UnsupportedCategoryNote extends ConsumerWidget {
  const UnsupportedCategoryNote({super.key});

  static const noteKey = ValueKey('unsupported-category');

  static const title = 'Unsupported design category';

  static const message =
      'This design was made with a newer version of ProFrame, or has a '
      'category this version does not recognise. It is shown exactly as it '
      'was saved and cannot be changed here, so nothing in it is lost. Its '
      'original category is kept.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unsupported = ref.watch(
      workspaceProvider.select((s) => s.design.isUnsupported),
    );
    if (!unsupported) return const SizedBox.shrink();
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.help_outline, size: 20, color: palette.onNotice),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.unsupportedTitle,
                  style: text.titleSmall?.copyWith(color: palette.onNotice),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.unsupportedMessage,
                  style: text.bodySmall?.copyWith(
                    color: palette.onNotice.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
