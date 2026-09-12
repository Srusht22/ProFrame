import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../core/layout/responsive.dart';
import '../../core/layout/window_size.dart';

/// The three-arrangement workspace shell every working screen sits in
/// (spec section 8).
///
/// It owns the arrangement and nothing else: what goes in the tool rail, the
/// canvas and the properties panel is the screen's business. Compact shows one
/// workspace at a time, medium adds a collapsible panel, expanded puts tools
/// left and properties right.
class WorkspaceScaffold extends StatefulWidget {
  final String title;

  /// Tools. A horizontal bar when compact, a vertical rail when expanded.
  final List<Widget> tools;

  /// The main workspace — the drawing canvas or the 3D view.
  final Widget canvas;

  /// Panel properties and measurements. A bottom sheet when compact.
  final Widget properties;

  /// Shown across the bottom on every size: the primary actions the spec
  /// requires to stay obvious (spec section 7).
  final Widget? primaryAction;

  const WorkspaceScaffold({
    required this.title,
    required this.tools,
    required this.canvas,
    required this.properties,
    this.primaryAction,
    super.key,
  });

  @override
  State<WorkspaceScaffold> createState() => _WorkspaceScaffoldState();
}

class _WorkspaceScaffoldState extends State<WorkspaceScaffold> {
  /// Medium layouts can fold the panel away to give the canvas the width.
  bool _panelOpen = true;

  @override
  Widget build(BuildContext context) => ResponsiveBuilder(
        builder: (context, size) => Scaffold(
          // A landscape phone loses the app bar: 56dp of a 360dp-tall window
          // is too much to spend on a title (spec section 8).
          appBar: size.isLandscapePhone
              ? null
              : AppBar(title: Text(widget.title)),
          body: SafeArea(
            child: switch (size.widthClass) {
              WindowWidthClass.expanded => _expanded(context),
              WindowWidthClass.medium => _medium(context, size),
              WindowWidthClass.compact => _compact(context, size),
            },
          ),
        ),
      );

  // Tools on the left, canvas in the middle, properties on the right.
  Widget _expanded(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: AppSizing.toolRailWidth,
            child: _ToolRail(tools: widget.tools),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _canvasWithAction(context)),
          const VerticalDivider(width: 1),
          SizedBox(
            width: AppSizing.propertiesPanelWidth,
            child: _PanelBody(child: widget.properties),
          ),
        ],
      );

  // Canvas with a panel that folds away.
  Widget _medium(BuildContext context, WindowSize size) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              children: [
                _ToolBar(tools: widget.tools),
                const Divider(height: 1),
                Expanded(child: _canvasWithAction(context)),
              ],
            ),
          ),
          if (_panelOpen) ...[
            const VerticalDivider(width: 1),
            SizedBox(
              width: AppSizing.propertiesPanelWidth,
              child: _PanelBody(child: widget.properties),
            ),
          ],
          _PanelToggle(
            open: _panelOpen,
            onChanged: (open) => setState(() => _panelOpen = open),
          ),
        ],
      );

  // One workspace at a time; properties arrive in a bottom sheet.
  Widget _compact(BuildContext context, WindowSize size) => Column(
        children: [
          _ToolBar(tools: widget.tools),
          const Divider(height: 1),
          Expanded(child: widget.canvas),
          if (widget.primaryAction != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: SizedBox(
                width: double.infinity,
                child: widget.primaryAction,
              ),
            ),
          _PropertiesSheetButton(properties: widget.properties),
        ],
      );

  Widget _canvasWithAction(BuildContext context) {
    if (widget.primaryAction == null) return widget.canvas;
    return Column(
      children: [
        Expanded(child: widget.canvas),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Align(
            alignment: Alignment.centerRight,
            child: widget.primaryAction,
          ),
        ),
      ],
    );
  }
}

class _ToolRail extends StatelessWidget {
  final List<Widget> tools;

  const _ToolRail({required this.tools});

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: AppColors.surface,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            children: [
              for (final tool in tools)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.xxs,
                    horizontal: AppSpacing.xs,
                  ),
                  child: tool,
                ),
            ],
          ),
        ),
      );
}

class _ToolBar extends StatelessWidget {
  final List<Widget> tools;

  const _ToolBar({required this.tools});

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: AppColors.surface,
        child: SizedBox(
          // The rail's own height floor, so a tool never gets squeezed under
          // the 48dp minimum by its container.
          height: AppSizing.minTouchTarget + AppSpacing.xs * 2,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            children: [
              for (final tool in tools)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxs,
                    vertical: AppSpacing.xs,
                  ),
                  child: tool,
                ),
            ],
          ),
        ),
      );
}

class _PanelBody extends StatelessWidget {
  final Widget child;

  const _PanelBody({required this.child});

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: AppColors.surface,
        // Scrollable so a long property list and the on-screen keyboard cannot
        // overflow it (spec section 8).
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: child,
        ),
      );
}

class _PanelToggle extends StatelessWidget {
  final bool open;
  final ValueChanged<bool> onChanged;

  const _PanelToggle({required this.open, required this.onChanged});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: open ? 'Hide the properties panel' : 'Show the properties panel',
        child: IconButton(
          tooltip: open ? 'Hide properties' : 'Show properties',
          icon: Icon(open ? Icons.chevron_right : Icons.chevron_left),
          onPressed: () => onChanged(!open),
        ),
      );
}

class _PropertiesSheetButton extends StatelessWidget {
  final Widget properties;

  const _PropertiesSheetButton({required this.properties});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          0,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.tune),
            label: const Text('Properties'),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              isScrollControlled: true,
              backgroundColor: AppColors.surface,
              builder: (context) => SafeArea(
                child: Padding(
                  // Lifts the sheet above the on-screen keyboard.
                  padding: EdgeInsets.only(
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
                  ),
                  child: SingleChildScrollView(child: properties),
                ),
              ),
            ),
          ),
        ),
      );
}
