import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../core/i18n/strings.dart';

/// How seriously to take a [Notice].
enum NoticeTone { information, caution, problem }

/// A short, plain-language message.
///
/// Used for the things the specification insists the user is told rather than
/// shielded from: that a profile is a generic preview, that measurements are
/// incomplete, that a dimension conflicts. Every tone carries an icon and a
/// word, so none of them depend on colour (spec section 7).
class Notice extends StatelessWidget {
  final String message;
  final NoticeTone tone;
  final String? title;

  const Notice({
    required this.message,
    this.tone = NoticeTone.information,
    this.title,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, foreground, icon, spokenTone) = switch (tone) {
      NoticeTone.information => (
          AppColors.surface,
          AppColors.deepGreen,
          Icons.info_outline,
          context.s(T.noticeInformation),
        ),
      NoticeTone.caution => (
          AppColors.cautionSurface,
          AppColors.caution,
          Icons.warning_amber_outlined,
          context.s(T.noticeCaution),
        ),
      NoticeTone.problem => (
          AppColors.dangerSurface,
          AppColors.danger,
          Icons.error_outline,
          context.s(T.noticeProblem),
        ),
    };

    return Semantics(
      container: true,
      label: '$spokenTone. ${title == null ? '' : '$title. '}$message',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: foreground.withValues(alpha: 0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null)
                      Text(
                        title!,
                        style: theme.textTheme.labelLarge?.copyWith(color: foreground),
                      ),
                    Text(
                      message,
                      style: theme.textTheme.bodySmall?.copyWith(color: foreground),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
