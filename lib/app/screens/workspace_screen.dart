import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dimensions/measurements.dart';
import '../../domain/model/elements.dart';
import '../canvas/cad_view.dart';
import '../canvas/drawing_surface.dart';
import '../inspector/component_tree.dart';
import '../inspector/inspector_panel.dart';
import '../inspector/measure_form.dart';
import '../inspector/opening_kind_alert.dart';
import '../inspector/outline_gap_alert.dart';
import '../inspector/questions_panel.dart';
import '../state/tools.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';
import '../viewer/model_view.dart';
import 'tool_bar.dart';
import 'workspace_bars.dart';

/// How much room the workspace has, and so how it is laid out.
///
/// The drawing always gets the room. What moves is everything around it:
///
/// The tools are the navigation bar along the bottom and the views the one
/// across the top, on every screen. What changes with the room is where
/// what is picked goes:
///
/// | | What is picked, and the parts |
/// | --- | --- |
/// | [phone] | a drawer, from icons beside the views |
/// | [tablet] | a drawer, from the same buttons |
/// | [desktop] | panels beside the drawing |
enum WorkspaceLayout {
  phone,
  tablet,
  desktop;

  /// The layout for a workspace [width] wide.
  static WorkspaceLayout of(double width) => width < 600
      ? phone
      : width < 900
          ? tablet
          : desktop;
}

/// Where the work happens: the views across the top, the tools along the
/// bottom, the drawing between them, and what is selected on the right —
/// or, where the screen is narrower, in a drawer.
///
/// The canvas gets the room. Everything else is as narrow as it can be and
/// still be usable with a finger.
class WorkspaceScreen extends ConsumerStatefulWidget {
  const WorkspaceScreen({super.key});

  /// How long the design has to stand still before it is kept without
  /// being asked: long enough that a drag is kept once, not a hundred times.
  /// Leaving the design keeps it at once, whatever is still waiting.
  static const keepAfter = Duration(milliseconds: 1200);

  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> {
  final _scaffold = GlobalKey<ScaffoldState>();
  Set<String> _highlighted = const {};
  bool _showTree = false;

  late final WorkspaceController _controller;
  Timer? _keeping;
  bool _unkept = false;

  /// Every size the form has already been opened for, so it comes back
  /// only for a size that is new — a line drawn and read — and never
  /// because one of the old ones was just given somewhere else, such as a
  /// figure typed on the drawing. And whether it is open now.
  final _askedAbout = <String>{};
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(workspaceProvider.notifier);
    // A design opened with sizes still to give is asked for them, as one
    // just read is.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _sizesOutstanding(ref.read(workspaceProvider).sizesToAsk),
    );
  }

  /// Asks for the sizes once a reading has made something to measure and
  /// nothing else is waiting on the user.
  void _sizesOutstanding(String keys) {
    if (keys.isEmpty || _asking || !mounted) return;
    final outstanding = keys.split(',');
    if (outstanding.every(_askedAbout.contains)) return;
    _askedAbout.addAll(outstanding);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _asking) return;
      _asking = true;
      await MeasureForm.show(context);
      _asking = false;
    });
  }

  /// The design has changed: keep it once it has stood still for
  /// [WorkspaceScreen.keepAfter], so the list of designs has it as last edited, at the top.
  void _changed() {
    _unkept = true;
    _keeping?.cancel();
    _keeping = Timer(WorkspaceScreen.keepAfter, _keep);
  }

  void _keep() {
    _keeping?.cancel();
    _keeping = null;
    if (!_unkept) return;
    _unkept = false;
    unawaited(_controller.keep());
  }

  @override
  void dispose() {
    // Leaving the design keeps whatever has not been kept yet, so going back
    // to the list of designs finds it as it was left.
    _keep();
    super.dispose();
  }

  /// Opens the drawer on what is picked, or on the list of parts.
  void _openDrawer({required bool parts}) {
    setState(() => _showTree = parts);
    _scaffold.currentState?.openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    // Only an edit to the design counts: picking a part, changing the view
    // or opening a leaf in the model changes nothing that is kept.
    ref.listen(workspaceProvider.select((s) => s.design), (before, after) {
      if (!identical(before, after)) _changed();
    });
    ref.listen(
      workspaceProvider.select((s) => s.sizesToAsk),
      (_, keys) => _sizesOutstanding(keys),
    );
    final state = ref.watch(workspaceProvider);
    final controller = ref.read(workspaceProvider.notifier);
    // Decided by the room the screen is actually given, not by the device:
    // a phone-sized browser window on a laptop is laid out as a phone.
    return LayoutBuilder(
      builder: (context, room) => _build(context, state, controller, room),
    );
  }

  Widget _build(
    BuildContext context,
    WorkspaceState state,
    WorkspaceController controller,
    BoxConstraints room,
  ) {
    final width = room.maxWidth;
    final layout = WorkspaceLayout.of(width);
    final phone = layout == WorkspaceLayout.phone;

    return Scaffold(
      key: _scaffold,
      // The bar across the top arrives with the workspace — the name, then
      // each icon in turn — and every icon answers to the pointer. How it
      // all moves is `BarMotion`'s, in one place.
      appBar: AppBar(
        titleSpacing: phone ? 0 : null,
        title: BarArrival(
          order: 0,
          from: const Offset(-14, 0),
          child: AnimatedSwitcher(
            duration: BarMotion.of(context, BarMotion.change),
            child: Text(
              state.design.name,
              key: ValueKey(state.design.name),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        actions: [
          if (state.design.frame != null)
            BarArrival(
              order: 1,
              child: Badge(
                // A dot while sizes are still to give.
                isLabelVisible: !Measurements.complete(state.design),
                smallSize: 8,
                backgroundColor: AppTheme.accent,
                offset: const Offset(-6, 6),
                child: BarIcon(
                  tooltip: 'Sizes',
                  icon: Icons.straighten,
                  onPressed: () => MeasureForm.show(context),
                ),
              ),
            ),
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
          SizedBox(width: phone ? 2 : 8),
        ],
      ),
      // The workspace, and over it the one question that is raised as an
      // alert: what a new leaf is. It is a layer of this screen rather than
      // a pushed route, so the design underneath goes on being the design —
      // it is blurred, not replaced, and nothing about it is waiting.
      body: Stack(
        children: [
          SafeArea(
            top: false,
            child: Column(
              children: [
                _ViewBar(
                  state: state,
                  controller: controller,
                  layout: layout,
                  treeOpen: _showTree,
                  onTree: () => layout == WorkspaceLayout.desktop
                      ? setState(() => _showTree = !_showTree)
                      : _openDrawer(parts: true),
                  onDetails: () => _openDrawer(parts: false),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(child: _mainView(state)),
                            if (state.needsReading &&
                                state.view == WorkspaceView.draw)
                              _ReadBar(
                                onRead: controller.readDrawing,
                                narrow: phone,
                              ),
                            QuestionsPanel(
                              onHighlight: (ids) =>
                                  setState(() => _highlighted = ids),
                            ),
                            // Where the panel beside the drawing is not
                            // shown, what is picked still says so, and one
                            // tap opens it.
                            if (layout != WorkspaceLayout.desktop &&
                                state.selected != null)
                              _PickedBar(
                                state: state,
                                onEdit: () => _openDrawer(parts: false),
                                onClear: () => controller.select(null),
                              ),
                          ],
                        ),
                      ),
                      if (layout == WorkspaceLayout.desktop) ...[
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
                // The tools, as the navigation bar along the bottom, on
                // every screen: where a thumb reaches them on a phone, and
                // leaving the drawing the whole width everywhere.
                const ToolBar(),
              ],
            ),
          ),
          const OpeningKindAlert(),
          const OutlineGapAlert(),
        ],
      ),
      endDrawer: layout == WorkspaceLayout.desktop
          ? null
          : Drawer(
              // Never wider than most of the screen, so the drawing it is
              // about still shows beside it.
              width: (width * 0.88).clamp(0.0, 360.0),
              child: SafeArea(
                child: _showTree
                    ? const ComponentTree()
                    : const InspectorPanel(),
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
  final WorkspaceLayout layout;
  final VoidCallback onTree;
  final VoidCallback onDetails;
  final bool treeOpen;

  const _ViewBar({
    required this.state,
    required this.controller,
    required this.layout,
    required this.onTree,
    required this.onDetails,
    required this.treeOpen,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = ViewTabs(
      selected: state.view,
      compact: layout != WorkspaceLayout.desktop,
      fill: layout == WorkspaceLayout.phone,
      enabled: (view) =>
          view == WorkspaceView.draw || state.design.frame != null,
      onSelected: controller.showView,
    );
    final canRead = state.design.frame != null;

    // On a phone the three views share the width and everything else is an
    // icon, named by its tooltip: there is no room for a word beside them.
    if (layout == WorkspaceLayout.phone) {
      return Container(
        color: context.palette.surface,
        // Nothing under the tabs, so the active view's bar sits on the
        // edge of the bar of views.
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
        child: Row(
          children: [
            Expanded(child: BarArrival(order: 1, child: tabs)),
            if (canRead)
              IconButton(
                tooltip: 'Read again',
                visualDensity: VisualDensity.compact,
                onPressed: controller.readDrawing,
                icon: const Icon(Icons.auto_fix_high_outlined, size: 20),
              ),
            IconButton(
              tooltip: 'Parts',
              visualDensity: VisualDensity.compact,
              onPressed: onTree,
              icon: const Icon(Icons.list_alt_outlined, size: 20),
            ),
            IconButton(
              tooltip: 'Details',
              visualDensity: VisualDensity.compact,
              onPressed: onDetails,
              icon: const Icon(Icons.tune, size: 20),
            ),
          ],
        ),
      );
    }

    return Container(
      color: context.palette.surface,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Row(
        children: [
          BarArrival(order: 1, child: tabs),
          const Spacer(),
          if (canRead)
            TextButton.icon(
              onPressed: controller.readDrawing,
              icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
              label: const Text('Read again'),
            ),
          if (layout == WorkspaceLayout.desktop)
            TextButton.icon(
              onPressed: onTree,
              icon: Icon(
                treeOpen ? Icons.list_alt : Icons.list_alt_outlined,
                size: 18,
              ),
              label: const Text('Parts'),
            )
          else ...[
            IconButton(
              tooltip: 'Parts',
              onPressed: onTree,
              icon: const Icon(Icons.list_alt_outlined, size: 20),
            ),
            IconButton(
              tooltip: 'Details',
              onPressed: onDetails,
              icon: const Icon(Icons.tune, size: 20),
            ),
          ],
        ],
      ),
    );
  }
}

/// What is picked, where the panel beside the drawing is not shown: its
/// name, and one tap to open it or to let it go.
class _PickedBar extends StatelessWidget {
  final WorkspaceState state;
  final VoidCallback onEdit;
  final VoidCallback onClear;

  const _PickedBar({
    required this.state,
    required this.onEdit,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final selected = state.selected!;
    final name = switch (selected) {
      final OpeningElement opening => state.design.nameOf(opening),
      _ => selected.label,
    };
    return Container(
      width: double.infinity,
      color: context.palette.shell,
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      child: Row(
        children: [
          Icon(Icons.touch_app_outlined, size: 18, color: context.palette.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.tune, size: 18),
            label: const Text('Edit'),
          ),
          IconButton(
            tooltip: 'Let it go',
            visualDensity: VisualDensity.compact,
            onPressed: onClear,
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}

/// The one call to action: turn what has been drawn into geometry.
class _ReadBar extends StatelessWidget {
  final VoidCallback onRead;
  final bool narrow;
  const _ReadBar({required this.onRead, this.narrow = false});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: context.palette.notice,
    padding: EdgeInsets.fromLTRB(narrow ? 14 : 18, 10, narrow ? 10 : 18, 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            narrow
                ? 'Your drawing has changed.'
                : 'Your drawing has changes that have not been read yet.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.palette.onNotice),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: onRead,
          child: Text(narrow ? 'Read it' : 'Read my drawing'),
        ),
      ],
    ),
  );
}
