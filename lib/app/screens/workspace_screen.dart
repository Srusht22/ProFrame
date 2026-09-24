import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../canvas/cad_view.dart';
import '../canvas/drawing_surface.dart';
import '../inspector/component_tree.dart';
import '../inspector/inspector_panel.dart';
import '../inspector/opening_kind_alert.dart';
import '../inspector/outline_gap_alert.dart';
import '../inspector/questions_panel.dart';
import '../state/tools.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';
import '../viewer/model_view.dart';
import 'tool_rail.dart';
import 'workspace_bars.dart';

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
      // The bar across the top arrives with the workspace — the name, then
      // each icon in turn — and every icon answers to the pointer. How it
      // all moves is `BarMotion`'s, in one place.
      appBar: AppBar(
        title: BarArrival(
          order: 0,
          from: const Offset(-14, 0),
          child: AnimatedSwitcher(
            duration: BarMotion.of(context, BarMotion.change),
            child: Text(
              state.design.name,
              key: ValueKey(state.design.name),
            ),
          ),
        ),
        actions: [
          BarArrival(
            order: 1,
            child: BarIcon(
              tooltip: 'Undo',
              icon: Icons.undo,
              onPressed: controller.canUndo ? controller.undo : null,
            ),
          ),
          BarArrival(
            order: 2,
            child: BarIcon(
              tooltip: 'Redo',
              icon: Icons.redo,
              onPressed: controller.canRedo ? controller.redo : null,
            ),
          ),
          BarArrival(
            order: 3,
            child: SaveIcon(
              onSave: () async {
                await controller.save();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Design saved.')),
                );
              },
            ),
          ),
          BarArrival(
            order: 4,
            child: BarIcon(
              tooltip: state.showSketch ? 'Hide my drawing' : 'Show my drawing',
              icon: state.showSketch ? Icons.gesture : Icons.gesture_outlined,
              dim: !state.showSketch,
              onPressed: controller.toggleSketch,
            ),
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
          const OutlineGapAlert(),
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
        BarArrival(
          order: 1,
          child: ViewTabs(
            selected: state.view,
            compact: compact,
            enabled: (view) =>
                view == WorkspaceView.draw || state.design.frame != null,
            onSelected: controller.showView,
          ),
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
