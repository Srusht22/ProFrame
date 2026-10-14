import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../state/language.dart';

/// The language, on its own button: a translate mark, never a flag and
/// never the gear that opens Settings.
///
/// It opens the two languages, each named in itself — *English*,
/// *کوردی (سۆرانی)* — with the one in use ticked. Choosing one changes the
/// whole application at once, its direction too, keeps the choice on the
/// device, and leaves the screen, the customer and the design where they
/// were. It is a different button from the appearance, and neither
/// touches what the other chose.
class LanguageButton extends ConsumerWidget {
  /// The colour of the icon, for the ground it stands on.
  final Color colour;

  const LanguageButton({super.key, required this.colour});

  static const buttonKey = ValueKey('language-button');
  static ValueKey<String> optionKey(AppLanguage language) =>
      ValueKey('language-option-${language.code}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final l = context.l10n;
    return Semantics(
      button: true,
      label: l.lbCurrent(language.endonym),
      excludeSemantics: true,
      child: PopupMenuButton<AppLanguage>(
        key: buttonKey,
        tooltip: l.lbTooltip,
        initialValue: language,
        position: PopupMenuPosition.under,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: ref.read(languageProvider.notifier).choose,
        itemBuilder: (context) => [
          PopupMenuItem<AppLanguage>(
            enabled: false,
            height: 36,
            child: Text(
              context.l10n.settingsLanguage,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          for (final option in AppLanguage.values)
            PopupMenuItem(
              key: optionKey(option),
              value: option,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      option.endonym,
                      // Each in its own direction, at the start of the row.
                      textDirection: option == AppLanguage.english
                          ? TextDirection.ltr
                          : TextDirection.rtl,
                      textAlign: Directionality.of(context) == TextDirection.rtl
                          ? TextAlign.right
                          : TextAlign.left,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (option == language) ...[
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
        icon: Icon(Icons.translate, color: colour, size: 22),
      ),
    );
  }
}
