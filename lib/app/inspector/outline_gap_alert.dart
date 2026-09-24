import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/question.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';

/// An outline drawn with one side missing, put over the workspace with the
/// work behind it blurred back.
///
/// The drawing cannot say whether that side was left off on purpose — a door
/// frame of a head and two jambs, with no sill — or not drawn yet, so the
/// user is asked, in their own words: *the design is not closed; do you want
/// it this way, or are you going to change it?* Keeping it builds it exactly
/// as drawn, with no member across the gap. Closing it puts one there.
/// Changing it goes back to the drawing, which is theirs to finish.
///
/// It is raised over the work rather than in the panel under it because
/// until it is answered there is no frame, and so nothing to draw, open or
/// build — the one thing the user needs to know after reading the sheet.
class OutlineGapAlert extends ConsumerWidget {
  const OutlineGapAlert({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final question = ref.watch(
      workspaceProvider.select((s) => s.outlineGapQuestion),
    );
    if (question == null) return const SizedBox.shrink();
    final controller = ref.read(workspaceProvider.notifier);

    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
              child: const ModalBarrier(
                dismissible: false,
                color: Color(0x4D0C1613),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _Card(
                question: question,
                onAnswer: (key) => controller.answer(question.id, key),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final DesignQuestion question;
  final ValueChanged<String> onAnswer;

  const _Card({required this.question, required this.onAnswer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        elevation: 14,
        shadowColor: AppTheme.ink.withValues(alpha: 0.4),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.crop_free,
                      size: 20,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Design not closed',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                question.prompt,
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 21),
              ),
              if (question.detail != null) ...[
                const SizedBox(height: 8),
                Text(
                  question.detail!,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppTheme.muted, height: 1.45),
                ),
              ],
              const SizedBox(height: 18),
              for (final (i, option) in question.options.indexed) ...[
                if (i > 0) const SizedBox(height: 10),
                _Choice(
                  option: option,
                  // The first is the drawing as it stands; the others are
                  // the two ways of changing it.
                  primary: i == 0,
                  onTap: () => onAnswer(option.key),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  final QuestionOption option;
  final bool primary;
  final VoidCallback onTap;

  const _Choice({
    required this.option,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fore = primary ? AppTheme.accent : AppTheme.primary;
    return Material(
      color: primary ? AppTheme.primary : AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: primary
            ? BorderSide.none
            : const BorderSide(color: AppTheme.hairline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: AppTheme.buttonLabel.copyWith(color: fore),
                    ),
                    if (option.detail != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        option.detail!,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12.5,
                          height: 1.35,
                          color: fore.withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: fore, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
