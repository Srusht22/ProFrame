import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      tooltip: 'Appearance',
      initialValue: mode,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: ref.read(appearanceProvider.notifier).choose,
      itemBuilder: (context) => [
        for (final option in Appearance.labels.keys)
          PopupMenuItem(
            value: option,
            child: Row(
              children: [
                Icon(Appearance.icons[option], size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(Appearance.labels[option]!)),
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
