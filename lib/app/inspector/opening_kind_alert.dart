import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/question.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';

/// What a new opening is, put over the workspace with the work behind it
/// blurred back.
///
/// **This is the one question worth interrupting for, and it is still not a
/// questionnaire.** The opening is built first, exactly as the mark said, and
/// it stands whether this is answered or waved away — nothing waits on it. It
/// is raised over the drawing rather than under it because it is about a leaf
/// the user has just made and it decides what gets built on that leaf, which
/// is easy to miss in a panel below the fold.
///
/// One leaf at a time, in the order the drawing reads. Three marks put three
/// questions, each naming the opening it is about, so answering is never a
/// guess at which leaf is meant.
///
/// The blur is what makes it an alert rather than a panel: the design is
/// still there, still the user's, and still unchanged — it is simply not
/// what they are being asked about for the moment. Nothing behind it is
/// hidden, because a drawing that vanishes while a question is asked reads
/// as the application having taken it away.
class OpeningKindAlert extends ConsumerWidget {
  const OpeningKindAlert({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(
      workspaceProvider.select((s) => s.openingKindQuestions),
    );
    if (pending.isEmpty) return const SizedBox.shrink();

    final controller = ref.read(workspaceProvider.notifier);
    final question = pending.first;

    return Positioned.fill(
      child: Stack(
        children: [
          // Everything behind, blurred back and dimmed. The barrier swallows
          // taps so a stray one on the drawing underneath cannot edit a
          // design the user cannot presently see clearly.
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
                remaining: pending.length,
                onAnswer: (key) => controller.answer(question.id, key),
                onDismiss: () => controller.dismissQuestion(question.id),
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
  final int remaining;
  final ValueChanged<String> onAnswer;
  final VoidCallback onDismiss;

  const _Card({
    required this.question,
    required this.remaining,
    required this.onAnswer,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 460),
    child: Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(18),
      elevation: 14,
      shadowColor: AppTheme.ink.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    Icons.help_outline,
                    size: 20,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Opening type',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                // How many leaves are still to be said, so answering
                // three in a row does not feel like the same question
                // coming back.
                if (remaining > 1)
                  Text(
                    '1 of $remaining',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppTheme.muted),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              question.prompt,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontSize: 21),
            ),
            if (question.detail != null) ...[
              const SizedBox(height: 8),
              Text(
                question.detail!,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppTheme.muted, height: 1.45),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                for (final option in question.options) ...[
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        textStyle: AppTheme.buttonLabel,
                      ),
                      onPressed: () => onAnswer(option.key),
                      child: Text(option.label),
                    ),
                  ),
                  if (option != question.options.last)
                    const SizedBox(width: 10),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              // Waving it away is not an answer: the leaf keeps no kind
              // of its own and the opening is untouched. The same
              // control on the opening's own panel says it later.
              child: TextButton(
                onPressed: onDismiss,
                child: const Text('Not now'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
