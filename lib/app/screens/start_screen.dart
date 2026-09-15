import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dimensions/units.dart';
import '../../domain/model/design.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';
import 'workspace_screen.dart';

/// Where it begins: create a design, say whether it is a door or a window,
/// and draw.
class StartScreen extends ConsumerWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        backgroundColor: AppTheme.primary,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ProFrame',
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(color: AppTheme.accent),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Draw your door or window by hand. What you draw '
                      'becomes the design — the exact shape, the exact '
                      'divisions, the exact proportions — and the design '
                      'becomes the model.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.accent.withValues(alpha: 0.86),
                            fontSize: 16,
                            height: 1.5,
                          ),
                    ),
                    const SizedBox(height: 34),
                    Text(
                      'CREATE DESIGN',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: AppTheme.accent.withValues(alpha: 0.7)),
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 460;
                        final cards = [
                          _KindCard(
                            kind: DesignKind.door,
                            icon: Icons.door_front_door_outlined,
                            blurb: 'Any shape, any number of panels, '
                                'hinged wherever you draw it.',
                            onTap: () => _begin(context, ref, DesignKind.door),
                          ),
                          _KindCard(
                            kind: DesignKind.window,
                            icon: Icons.window_outlined,
                            blurb: 'Any outline, any arrangement of bars, '
                                'opening wherever you mark it.',
                            onTap: () =>
                                _begin(context, ref, DesignKind.window),
                          ),
                        ];
                        return narrow
                            ? Column(
                                children: [
                                  cards[0],
                                  const SizedBox(height: 12),
                                  cards[1],
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(child: cards[0]),
                                  const SizedBox(width: 12),
                                  Expanded(child: cards[1]),
                                ],
                              );
                      },
                    ),
                    const SizedBox(height: 24),
                    const _SavedDesigns(),
                    const SizedBox(height: 24),
                    Text(
                      'Nothing is designed for you. No templates, no stock '
                      'pictures, no assumptions about what a door usually '
                      'looks like. Where your drawing is unclear you will be '
                      'asked.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.accent.withValues(alpha: 0.62),
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  void _begin(BuildContext context, WidgetRef ref, DesignKind kind) {
    ref.read(workspaceProvider.notifier).startDesign(kind);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const WorkspaceScreen()),
    );
  }
}

/// Designs the user has kept, most recent first.
class _SavedDesigns extends ConsumerWidget {
  const _SavedDesigns();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedDesignsProvider);
    return saved.maybeWhen(
      data: (designs) {
        if (designs.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'YOUR DESIGNS',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.accent.withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 10),
            for (final design in designs.take(6))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: AppTheme.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      ref.read(workspaceProvider.notifier).openDesign(design);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const WorkspaceScreen(),
                        ),
                      );
                    },
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      child: Row(
                        children: [
                          Icon(
                            design.kind == DesignKind.door
                                ? Icons.door_front_door_outlined
                                : Icons.window_outlined,
                            size: 19,
                            color: AppTheme.accent.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              design.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            design.frame == null
                                ? 'drawing'
                                : '${Units.format(design.widthMm)} × '
                                    '${Units.label(design.heightMm)}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.accent.withValues(alpha: 0.62),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _KindCard extends StatelessWidget {
  final DesignKind kind;
  final IconData icon;
  final String blurb;
  final VoidCallback onTap;

  const _KindCard({
    required this.kind,
    required this.icon,
    required this.blurb,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: AppTheme.accent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 32, color: AppTheme.primary),
                const SizedBox(height: 14),
                Text(
                  kind.label.toUpperCase(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.primary,
                        letterSpacing: 1,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  blurb,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.primary.withValues(alpha: 0.78),
                      ),
                ),
              ],
            ),
          ),
        ),
      );
}
