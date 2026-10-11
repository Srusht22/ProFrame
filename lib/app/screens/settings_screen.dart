import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../state/appearance.dart';
import '../state/language.dart';
import '../theme/app_theme.dart';
import 'appearance_button.dart';

/// How the application is shown: its language and its appearance.
///
/// Both are kept on the device and neither is anything anybody made, so
/// changing either changes no customer, design, price or record.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const languageKey = ValueKey('settings-language');
  static ValueKey<String> languageOption(AppLanguage language) =>
      ValueKey('settings-language-${language.code}');
  static ValueKey<String> appearanceOption(ThemeMode mode) =>
      ValueKey('settings-appearance-${mode.name}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final language = ref.watch(languageProvider);
    final mode = ref.watch(appearanceProvider);

    // A Material rather than a coloured box, so the choices' own ink shows.
    Widget section(String title, Widget child, {String? note}) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.hairline),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                ),
              ),
              if (note != null) ...[
                const SizedBox(height: 4),
                Text(note, style: TextStyle(fontSize: 13, color: p.muted)),
              ],
              const SizedBox(height: 6),
              child,
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                section(
                  l.settingsLanguage,
                  note: l.settingsLanguageNote,
                  RadioGroup<AppLanguage>(
                    key: languageKey,
                    groupValue: language,
                    onChanged: (chosen) {
                      if (chosen != null) {
                        ref.read(languageProvider.notifier).choose(chosen);
                      }
                    },
                    child: Column(
                      children: [
                        for (final option in AppLanguage.values)
                          RadioListTile<AppLanguage>(
                            key: languageOption(option),
                            contentPadding: EdgeInsets.zero,
                            value: option,
                            // Each name in its own direction, so the
                            // English name reads left to right on a
                            // Kurdish screen and the Kurdish right to left
                            // on an English one — and each at the start of
                            // its row, as the screen reads, not pushed to
                            // the far side by its own direction.
                            title: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                option.endonym,
                                textDirection: option == AppLanguage.english
                                    ? TextDirection.ltr
                                    : TextDirection.rtl,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                section(
                  l.settingsAppearance,
                  RadioGroup<ThemeMode>(
                    groupValue: mode,
                    onChanged: (chosen) {
                      if (chosen != null) {
                        ref.read(appearanceProvider.notifier).choose(chosen);
                      }
                    },
                    child: Column(
                      children: [
                        for (final option in Appearance.icons.keys)
                          RadioListTile<ThemeMode>(
                            key: appearanceOption(option),
                            contentPadding: EdgeInsets.zero,
                            value: option,
                            secondary: Icon(Appearance.icons[option]),
                            title: Text(appearanceLabel(l, option)),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The button on the customers' header that opens [SettingsScreen].
class SettingsButton extends StatelessWidget {
  /// The colour of the icon, for the ground it stands on.
  final Color colour;

  const SettingsButton({super.key, required this.colour});

  static const buttonKey = ValueKey('settings-button');

  @override
  Widget build(BuildContext context) => IconButton(
    key: buttonKey,
    tooltip: context.l10n.settingsTitle,
    style: IconButton.styleFrom(visualDensity: VisualDensity.compact),
    icon: Icon(Icons.settings_outlined, color: colour, size: 22),
    onPressed: () => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
  );
}
