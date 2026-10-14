import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../state/appearance.dart';

/// Light, dark or the device's own: one button.
///
/// **Its icon is the appearance on the screen now** — a sun when it is
/// light, a moon when it is dark — turning from one to the other as it
/// changes, whether the user chose it or the device did. Which of the three
/// is chosen is said in its tooltip and ticked in its list.
class AppearanceButton extends ConsumerWidget {
  /// The colour of the icon, for the ground it stands on.
  final Color colour;

  const AppearanceButton({super.key, required this.colour});

  static const buttonKey = ValueKey('appearance-button');
  static ValueKey<String> optionKey(ThemeMode mode) =>
      ValueKey('appearance-option-${mode.name}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appearanceProvider);
    final said = context.l10n.abTooltip(appearanceLabel(context.l10n, mode));
    return Semantics(
      button: true,
      label: said,
      excludeSemantics: true,
      child: PopupMenuButton<ThemeMode>(
        key: buttonKey,
        tooltip: said,
        initialValue: mode,
        position: PopupMenuPosition.under,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: ref.read(appearanceProvider.notifier).choose,
        itemBuilder: (context) => [
          PopupMenuItem<ThemeMode>(
            enabled: false,
            height: 36,
            child: Text(
              context.l10n.settingsAppearance,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          for (final option in Appearance.icons.keys)
            PopupMenuItem(
              key: optionKey(option),
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
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (child, turn) => RotationTransition(
            turns: Tween(begin: 0.6, end: 1.0).animate(turn),
            child: FadeTransition(opacity: turn, child: child),
          ),
          child: Icon(
            Theme.of(context).brightness == Brightness.dark
                ? Icons.dark_mode_outlined
                : Icons.light_mode_outlined,
            key: ValueKey(Theme.of(context).brightness),
            color: colour,
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// What [mode] is called, in the language [l] is in.
String appearanceLabel(AppLocalizations l, ThemeMode mode) => switch (mode) {
  ThemeMode.system => l.appearanceSystem,
  ThemeMode.light => l.appearanceLight,
  ThemeMode.dark => l.appearanceDark,
};
