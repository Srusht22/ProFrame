import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/question.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';

/// What the application could not tell from the drawing.
///
/// Everything here is a real decision that changes the design. The
/// application puts it to the user rather than choosing quietly and hoping
/// nobody notices.
class QuestionsPanel extends ConsumerWidget {
  final ValueChanged<Set<String>>? onHighlight;

  const QuestionsPanel({super.key, this.onHighlight});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questions = ref.watch(
      workspaceProvider.select((s) => s.sheetQuestions),
    );
    final controller = ref.read(workspaceProvider.notifier);

    // It opens up from the foot of the drawing and closes back down into
    // it, rather than appearing whole and shoving the drawing up in one
    // frame. Once open, it grows and shrinks with what it holds.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 340),
      reverseDuration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        alignment: Alignment.topCenter,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: questions.isEmpty
          ? const SizedBox.shrink(key: ValueKey('none'))
          : AnimatedSize(
              key: const ValueKey('asking'),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _panel(context, questions, controller),
            ),
    );
  }

  Widget _panel(
    BuildContext context,
    List<DesignQuestion> questions,
    WorkspaceController controller,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: context.palette.notice,
        border: Border(top: BorderSide(color: context.palette.hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, size: 19, color: context.palette.onNotice),
              const SizedBox(width: 8),
              Text(
                questions.length == 1
                    ? 'One thing to check'
                    : '${questions.length} things to check',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: context.palette.onNotice),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Nothing has been decided for you. Your drawing is unchanged '
            'until you answer.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: context.palette.onNotice.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 12),
          for (final question in questions)
            _QuestionCard(
              question: question,
              onAnswer: (key) {
                onHighlight?.call(const {});
                controller.answer(question.id, key);
              },
              onDismiss: () {
                onHighlight?.call(const {});
                controller.dismissQuestion(question.id);
              },
              onShow: () => onHighlight?.call(question.aboutIds.toSet()),
            ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final DesignQuestion question;
  final ValueChanged<String> onAnswer;
  final VoidCallback onDismiss;
  final VoidCallback onShow;

  const _QuestionCard({
    required this.question,
    required this.onAnswer,
    required this.onDismiss,
    required this.onShow,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.palette.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question.prompt,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (question.detail != null) ...[
              const SizedBox(height: 4),
              Text(
                question.detail!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in question.options)
                  Tooltip(
                    message: option.detail ?? '',
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        textStyle:
                            AppTheme.buttonLabel.copyWith(fontSize: 13.5),
                      ),
                      onPressed: () => onAnswer(option.key),
                      child: Text(option.label),
                    ),
                  ),
                if (question.aboutIds.isNotEmpty)
                  TextButton.icon(
                    onPressed: onShow,
                    icon: const Icon(Icons.visibility_outlined, size: 17),
                    label: const Text('Show me'),
                  ),
                TextButton(
                  onPressed: onDismiss,
                  child: const Text('Not now'),
                ),
              ],
            ),
          ],
        ),
      );
}
