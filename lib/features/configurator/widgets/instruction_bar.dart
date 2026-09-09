import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/opening_model.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../geometry/instruction_parser.dart';
import '../state/design_session.dart';

/// Describe a change in plain words and the design follows.
///
/// What it understands is a fixed, documented list — shown right here, so the
/// user is never guessing at the vocabulary. Anything outside that list is
/// reported as not understood and nothing is changed, because a wrong guess
/// silently alters something somebody is going to build.
class InstructionBar extends ConsumerStatefulWidget {
  final OpeningModel model;

  const InstructionBar({super.key, required this.model});

  @override
  ConsumerState<InstructionBar> createState() => _InstructionBarState();
}

class _InstructionBarState extends ConsumerState<InstructionBar> {
  final TextEditingController _controller = TextEditingController();
  final InstructionRunner _runner = const InstructionRunner();
  List<String> _applied = const [];
  List<String> _problems = const [];
  bool _showExamples = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _run() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final session = ref.read(designSessionProvider);
    final notifier = ref.read(designSessionProvider.notifier);

    final result = _runner.run(
      widget.model,
      text,
      selectedId: session.selectedRegionId,
    );

    if (result.changedAnything) {
      notifier.updateModel(result.model!);
      if (result.selectedId != null) notifier.selectRegion(result.selectedId);
      _controller.clear();
    }

    setState(() {
      _applied = result.applied;
      _problems = result.problems;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Describe a change',
          subtitle: 'Plain words — the design does exactly what you say',
          trailing: IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'What can I say?',
            icon: const Icon(Icons.help_outline, size: 18),
            onPressed: () => setState(() => _showExamples = !_showExamples),
          ),
        ),
        TextField(
          controller: _controller,
          textInputAction: TextInputAction.send,
          minLines: 1,
          maxLines: 3,
          onSubmitted: (_) => _run(),
          decoration: InputDecoration(
            hintText: 'e.g. make the glass 70%',
            isDense: true,
            suffixIcon: IconButton(
              icon: const Icon(Icons.send, size: 18),
              tooltip: 'Apply',
              onPressed: _run,
            ),
          ),
        ),
        if (_showExamples) ...[
          const SizedBox(height: AppSpacing.xs),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.sm),
            color: AppColors.neutralSurface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Everything it understands:',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                for (final example in InstructionParser.examples)
                  InkWell(
                    onTap: () {
                      _controller.text = example;
                      setState(() => _showExamples = false);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        '• $example',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (_applied.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          for (final line in _applied)
            _Note(icon: Icons.check_circle_outline, color: AppColors.success, text: line),
        ],
        if (_problems.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          for (final line in _problems)
            _Note(icon: Icons.help_outline, color: AppColors.warning, text: line),
        ],
      ],
    );
  }
}

class _Note extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _Note({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      );
}
