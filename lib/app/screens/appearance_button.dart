import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../state/appearance.dart';

/// Light, dark or the device's own: one button, the icon showing which.
class AppearanceButton extends ConsumerWidget {
  /// The colour of the icon, for the ground it stands on.
  final Color colour;

  const AppearanceButton({super.key, required this.colour});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appearanceProvider);
    return PopupMenuButton<ThemeMode>(
      tooltip: context.l10n.settingsAppearance,
      initialValue: mode,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: ref.read(appearanceProvider.notifier).choose,
      itemBuilder: (context) => [
        for (final option in Appearance.icons.keys)
          PopupMenuItem(
            value: option,
            child: Row(
              children: [
                Icon(Appearance.icons[option], size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(appearanceLabel(context.l10n, option))),
                if (option == mode) ...[
                  const SizedBox(width: 12),
                  Icon(
                    Icons.check,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ],
            ),
          ),
      ],
      style: IconButton.styleFrom(visualDensity: VisualDensity.compact),
      icon: Icon(Appearance.icons[mode], color: colour, size: 22),
    );
  }
}

/// What [mode] is called, in the language [l] is in.
String appearanceLabel(AppLocalizations l, ThemeMode mode) => switch (mode) {
  ThemeMode.system => l.appearanceSystem,
  ThemeMode.light => l.appearanceLight,
  ThemeMode.dark => l.appearanceDark,
};
