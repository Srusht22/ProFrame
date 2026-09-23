import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../canvas/cad_view.dart';
import '../canvas/drawing_surface.dart';
import '../inspector/component_tree.dart';
import '../inspector/inspector_panel.dart';
import '../inspector/opening_kind_alert.dart';
import '../inspector/questions_panel.dart';
import '../state/tools.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';
import '../viewer/model_view.dart';
import 'tool_rail.dart';

/// Where the work happens: tools on the left, the drawing in the middle,
/// what is selected on the right.
///
/// The canvas gets the room. Everything else is as narrow as it can be and
/// still be usable with a finger.
class WorkspaceScreen extends ConsumerStatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> {
  Set<String> _highlighted = const {};
  bool _showTree = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workspaceProvider);
    final controller = ref.read(workspaceProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(state.design.name),
        actions: [
          IconButton(
            tooltip: 'Undo',
            onPressed: controller.canUndo ? controller.undo : null,
            icon: const Icon(Icons.undo),
            color: AppTheme.accent,
            disabledColor: AppTheme.accent.withValues(alpha: 0.3),
          ),
          IconButton(
            tooltip: 'Redo',
            onPressed: controller.canRedo ? controller.redo : null,
            icon: const Icon(Icons.redo),
            color: AppTheme.accent,
            disabledColor: AppTheme.accent.withValues(alpha: 0.3),
          ),
          IconButton(
            tooltip: 'Save',
            onPressed: () async {
              await controller.save();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Design saved.')));
            },
            icon: const Icon(Icons.save_outlined),
            color: AppTheme.accent,
          ),
          IconButton(
            tooltip: state.showSketch ? 'Hide my drawing' : 'Show my drawing',
            onPressed: controller.toggleSketch,
            icon: Icon(
              state.showSketch ? Icons.gesture : Icons.gesture_outlined,
            ),
            color: state.showSketch
                ? AppTheme.accent
                : AppTheme.accent.withValues(alpha: 0.45),
          ),
          const SizedBox(width: 8),
        ],
      ),
      // The workspace, and over it the one question that is raised as an
      // alert: what a new leaf is. It is a layer of this screen rather than
      // a pushed route, so the design underneath goes on being the design —
      // it is blurred, not replaced, and nothing about it is waiting.
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              return Column(
                children: [
                  _ViewBar(
                    state: state,
                    controller: controller,
                    onTree: () => setState(() => _showTree = !_showTree),
                    treeOpen: _showTree,
                    compact: !wide,
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Row(
                      children: [
                        ToolRail(compact: !wide),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(child: _mainView(state)),
                              if (state.needsReading &&
                                  state.view == WorkspaceView.draw)
                                _ReadBar(onRead: controller.readDrawing),
                              QuestionsPanel(
                                onHighlight: (ids) =>
                                    setState(() => _highlighted = ids),
                              ),
                            ],
                          ),
                        ),
                        if (wide) ...[
                          const VerticalDivider(width: 1),
                          SizedBox(
                            width: _showTree ? 560 : 320,
                            child: Row(
                              children: [
                                if (_showTree) ...[
                                  const SizedBox(
                                    width: 239,
                                    child: ComponentTree(),
                                  ),
                                  const VerticalDivider(width: 1),
                                ],
                                const Expanded(child: InspectorPanel()),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const OpeningKindAlert(),
        ],
      ),
      endDrawer: MediaQuery.of(context).size.width >= 900
          ? null
          : Drawer(
              width: 340,
              child: SafeArea(
                child: _showTree
                    ? const ComponentTree()
                    : const InspectorPanel(),
              ),
            ),
      floatingActionButton: MediaQuery.of(context).size.width >= 900
          ? null
          : Builder(
              builder: (context) => FloatingActionButton(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.accent,
                onPressed: Scaffold.of(context).openEndDrawer,
                child: const Icon(Icons.tune),
              ),
            ),
    );
  }

  Widget _mainView(WorkspaceState state) => switch (state.view) {
    WorkspaceView.draw => DrawingSurface(highlighted: _highlighted),
    WorkspaceView.plan => CadView(highlighted: _highlighted),
    WorkspaceView.model => const ModelView(),
  };
}

class _ViewBar extends StatelessWidget {
  final WorkspaceState state;
  final WorkspaceController controller;
  final VoidCallback onTree;
  final bool treeOpen;
  final bool compact;

  const _ViewBar({
    required this.state,
    required this.controller,
    required this.onTree,
    required this.treeOpen,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) => Container(
    color: AppTheme.surface,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(
      children: [
        SegmentedButton<WorkspaceView>(
          segments: [
            for (final view in WorkspaceView.values)
              ButtonSegment(
                value: view,
                label: Text(view.label),
                enabled:
                    view == WorkspaceView.draw || state.design.frame != null,
              ),
          ],
          selected: {state.view},
          showSelectedIcon: false,
          onSelectionChanged: (values) => controller.showView(values.first),
        ),
        const Spacer(),
        if (state.design.frame != null)
          TextButton.icon(
            onPressed: controller.readDrawing,
            icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
            label: const Text('Read again'),
          ),
        if (!compact)
          TextButton.icon(
            onPressed: onTree,
            icon: Icon(
              treeOpen ? Icons.list_alt : Icons.list_alt_outlined,
              size: 18,
            ),
            label: const Text('Parts'),
          ),
      ],
    ),
  );
}

/// The one call to action: turn what has been drawn into geometry.
class _ReadBar extends StatelessWidget {
  final VoidCallback onRead;
  const _ReadBar({required this.onRead});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: AppTheme.accent,
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            'Your drawing has changes that have not been read yet.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppTheme.primary),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(onPressed: onRead, child: const Text('Read my drawing')),
      ],
    ),
  );
}
