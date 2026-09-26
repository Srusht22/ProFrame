import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/design.dart';
import '../../domain/model/infill.dart';
import '../../domain/model/materials.dart';
import '../../domain/model/question.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';
import 'alert_layer.dart';
import 'infill_choices.dart';

/// What a new door or door & window design is built of, asked as it starts,
/// over the work.
///
/// The user's words: *when starting a new door, ask how it should be
/// constructed — entire design panel, entire design glass, or both.* Panel
/// and glass go on to the colour or the glass they want, and then to the
/// drawing: every part they draw starts as that. Both goes straight to the
/// drawing, and which parts are which is asked once there are parts — see
/// [PartsAlert]. Nothing is drawn, divided or moved for them either way.
///
/// It is an alert and not a gate: **Not now** puts it away for good, and the
/// **Material** tool says the same, part by part, whenever they like.
class ConstructionAlert extends ConsumerWidget {
  const ConstructionAlert({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final question = ref.watch(
      workspaceProvider.select((s) => s.constructionQuestion),
    );
    final controller = ref.read(workspaceProvider.notifier);
    return AlertLayer(
      question: question,
      cardFor: (question) => _ConstructionCard(
        question: question,
        onSay: (construction, finish) =>
            controller.sayConstruction(construction, finish: finish),
        onNotNow: controller.putConstructionAway,
      ),
    );
  }
}

class _ConstructionCard extends StatefulWidget {
  final DesignQuestion question;
  final void Function(Construction construction, Finish? finish) onSay;
  final VoidCallback onNotNow;

  const _ConstructionCard({
    required this.question,
    required this.onSay,
    required this.onNotNow,
  });

  @override
  State<_ConstructionCard> createState() => _ConstructionCardState();
}

class _ConstructionCardState extends State<_ConstructionCard> {
  /// Panel or glass, chosen and now being given its look.
  Fill? _fill;

  /// The look tapped, waiting on **Continue**.
  Finish? _finish;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fill = _fill;
    return _Card(
      icon: Icons.door_front_door_outlined,
      title: 'Glass or panel',
      children: [
        AlertStep(
          order: 0,
          child: Text(
            fill == null
                ? widget.question.prompt
                : fill == Fill.panel
                ? 'What colour is the panel?'
                : 'What glass is it?',
            style: theme.textTheme.titleLarge?.copyWith(fontSize: 21),
          ),
        ),
        const SizedBox(height: 8),
        AlertStep(
          order: 1,
          child: Text(
            fill == null
                ? widget.question.detail!
                : 'Every part you draw starts as this. Any part can be '
                      'changed later with Material.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.palette.muted,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (fill == null) ...[
          for (final (i, choice) in const [
            (
              Construction.panel,
              'Entire design = Panel',
              'Every part is a solid panel.',
              Icons.rectangle,
            ),
            (
              Construction.glass,
              'Entire design = Glass',
              'Every part is glazed.',
              Icons.window_outlined,
            ),
            (
              Construction.both,
              'Both Panel + Glass',
              'You choose which parts are glass and which are panel.',
              Icons.view_agenda_outlined,
            ),
          ].indexed) ...[
            if (i > 0) const SizedBox(height: 10),
            AlertStep(
              order: 2 + i,
              child: _Choice(
                key: ValueKey('construction-${choice.$1.name}'),
                icon: choice.$4,
                label: choice.$2,
                detail: choice.$3,
                onTap: () => switch (choice.$1) {
                  Construction.panel => setState(() => _fill = Fill.panel),
                  Construction.glass => setState(() => _fill = Fill.glass),
                  _ => widget.onSay(Construction.both, null),
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: widget.onNotNow,
              child: const Text('Not now'),
            ),
          ),
        ] else ...[
          LookChoices(
            fill: fill,
            finish: _finish,
            onChanged: (finish) => setState(() => _finish = finish),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(() {
                  _fill = null;
                  _finish = null;
                }),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back'),
              ),
              const Spacer(),
              FilledButton(
                key: const ValueKey('construction-continue'),
                onPressed: _finish == null
                    ? null
                    : () => widget.onSay(
                        fill == Fill.panel
                            ? Construction.panel
                            : Construction.glass,
                        _finish,
                      ),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                child: const Text('Continue'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Which parts are glass and which are panel, in a design said to be both,
/// asked once the drawing has been read.
///
/// Every part is one the user's own lines made, and none starts chosen: the
/// user's words, *do not choose the top or the bottom, do not assume half
/// and half*. **Done** waits until every part is said. Where the drawing
/// has only one part, nothing is divided for them: it says so, and **Draw
/// divider** puts them back on the drawing with a straight line in hand.
class PartsAlert extends ConsumerWidget {
  const PartsAlert({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final question = ref.watch(
      workspaceProvider.select((s) => s.partsQuestion),
    );
    final controller = ref.read(workspaceProvider.notifier);
    return AlertLayer(
      question: question,
      cardFor: (question) => question.id == WorkspaceState.onePartQuestionId
          ? _Card(
              icon: Icons.horizontal_rule,
              title: 'Glass or panel',
              children: [
                AlertStep(
                  order: 0,
                  child: Text(
                    question.prompt,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontSize: 21),
                  ),
                ),
                const SizedBox(height: 8),
                AlertStep(
                  order: 1,
                  child: Text(
                    question.detail!,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: context.palette.muted, height: 1.45),
                  ),
                ),
                const SizedBox(height: 18),
                AlertStep(
                  order: 2,
                  child: _Choice(
                    key: const ValueKey('draw-divider'),
                    icon: Icons.show_chart,
                    label: 'Draw divider',
                    detail: 'Back to the drawing with a straight line.',
                    primary: true,
                    onTap: controller.drawDivider,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: controller.partsLater,
                    child: const Text('Later'),
                  ),
                ),
              ],
            )
          : _PartsCard(
              question: question,
              onDone: controller.assignParts,
              onLater: controller.partsLater,
            ),
    );
  }
}

class _PartsCard extends ConsumerStatefulWidget {
  final DesignQuestion question;
  final ValueChanged<Map<String, Finish>> onDone;
  final VoidCallback onLater;

  const _PartsCard({
    required this.question,
    required this.onDone,
    required this.onLater,
  });

  @override
  ConsumerState<_PartsCard> createState() => _PartsCardState();
}

class _PartsCardState extends ConsumerState<_PartsCard> {
  /// What the user has said, part by part. Nothing is in here until they
  /// say it.
  final _said = <String, Finish>{};

  @override
  Widget build(BuildContext context) {
    final design = ref.watch(workspaceProvider.select((s) => s.design));
    final parts = Infill.partsOf(design);
    final left = parts.where((p) => !_said.containsKey(p.id)).length;
    final theme = Theme.of(context);
    return _Card(
      icon: Icons.view_agenda_outlined,
      title: 'Glass or panel',
      children: [
        AlertStep(
          order: 0,
          child: Text(
            widget.question.prompt,
            style: theme.textTheme.titleLarge?.copyWith(fontSize: 21),
          ),
        ),
        const SizedBox(height: 8),
        AlertStep(
          order: 1,
          child: Text(
            widget.question.detail!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.palette.muted,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 14),
        for (final (i, part) in parts.indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          AlertStep(
            order: 2 + i,
            child: PartChoice(
              design: design,
              part: part,
              finish: _said[part.id],
              onChanged: (finish) => setState(() => _said[part.id] = finish),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                left == 0
                    ? 'Every part is chosen.'
                    : left == 1
                    ? '1 part still to choose.'
                    : '$left parts still to choose.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            TextButton(onPressed: widget.onLater, child: const Text('Later')),
            const SizedBox(width: 8),
            FilledButton(
              key: const ValueKey('parts-done'),
              onPressed: left == 0 ? () => widget.onDone({..._said}) : null,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
              child: const Text('Done'),
            ),
          ],
        ),
      ],
    );
  }
}

/// The card both alerts sit on.
class _Card extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _Card({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 480),
    child: Material(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(18),
      elevation: 14,
      shadowColor: context.palette.shadow.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                AlertBadge(icon: icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    ),
  );
}

class _Choice extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;
  final bool primary;

  const _Choice({
    super.key,
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fore = primary ? p.onBand : p.primary;
    return AlertPressable(
      color: primary ? p.band : p.surface,
      side: primary ? BorderSide.none : BorderSide(color: p.hairline),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            Icon(icon, color: fore, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTheme.buttonLabel.copyWith(color: fore),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12.5,
                      height: 1.35,
                      color: fore.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: fore, size: 20),
          ],
        ),
      ),
    );
  }
}
