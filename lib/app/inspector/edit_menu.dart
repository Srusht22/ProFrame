import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// The one **Edit** button of the workspace's bar, where the panel beside
/// the drawing is not shown: what can be changed, said in words, rather
/// than two icons side by side that a person has to guess between.
///
/// The user's words, over a phone screenshot with the paint roller and the
/// sliders ringed: *they are crowded, normal people cannot understand what
/// is going on, so those two icons should open in one icon.* It opens a
/// short sheet naming what is picked — or saying that it is the whole
/// design — and each choice under it with a line saying what it does.
/// Choosing one opens exactly what its icon used to open; nothing else
/// changed.
class EditMenu extends StatelessWidget {
  /// What is picked, by name — or null for the whole design.
  final String? picked;

  /// Glass or panel, for each part — null where there are no parts yet.
  final VoidCallback? onMaterial;

  /// The panel of the part picked, or of the design.
  final VoidCallback onDetails;

  const EditMenu({
    super.key,
    required this.picked,
    required this.onMaterial,
    required this.onDetails,
  });

  static const buttonKey = ValueKey('edit-menu');
  static const materialKey = ValueKey('edit-menu-material');
  static const detailsKey = ValueKey('edit-menu-details');

  /// Opens the sheet. Each choice closes it before doing what it says.
  static Future<void> show(
    BuildContext context, {
    required String? picked,
    required VoidCallback? onMaterial,
    required VoidCallback onDetails,
  }) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    // As tall as what it says, and scrolling where a short phone has not
    // the room.
    isScrollControlled: true,
    builder: (sheet) => EditMenu(
      picked: picked,
      onMaterial: onMaterial == null
          ? null
          : () {
              Navigator.of(sheet).pop();
              onMaterial();
            },
      onDetails: () {
        Navigator.of(sheet).pop();
        onDetails();
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 6, 4),
              child: Text(l10n.wsEdit, style: theme.textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 6, 12),
              child: Text(
                picked == null ? l10n.wsEditWhole : l10n.wsEditPicked(picked!),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: context.palette.muted,
                ),
              ),
            ),
            if (onMaterial != null) ...[
              _Choice(
                key: materialKey,
                icon: Icons.format_paint_outlined,
                title: l10n.wsGlassOrPanel,
                says: l10n.wsGlassOrPanelHint,
                onTap: onMaterial!,
              ),
              const SizedBox(height: 10),
            ],
            _Choice(
              key: detailsKey,
              icon: Icons.tune,
              title: l10n.wsDetails,
              says: l10n.wsDetailsHint,
              onTap: onDetails,
            ),
          ],
        ),
      ),
    );
  }
}

/// One thing the menu offers: its mark, its name and what it does, the
/// whole row a target.
class _Choice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String says;
  final VoidCallback onTap;

  const _Choice({
    super.key,
    required this.icon,
    required this.title,
    required this.says,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = context.palette;
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: p.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: p.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: p.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      says,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: p.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Points on, in the direction the screen reads.
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left
                    : Icons.chevron_right,
                color: p.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
