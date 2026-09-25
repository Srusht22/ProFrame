import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../inspector/colour_picker.dart';
import '../state/tools.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';
import 'workspace_bars.dart';

/// The tools, as the navigation bar along the bottom of the workspace.
///
/// Each one makes real geometry rather than a picture of something, and each
/// says plainly what it does, because a tool that is guessed at is a drawing
/// that comes out wrong.
///
/// **The active tool is marked twice, by one indicator that moves.** A pill
/// behind its icon and a short bar on the top edge of the navigation bar
/// above it, both gliding to the tool chosen and settling with a slight
/// overshoot, so the eye follows the change rather than hunting for it.
/// Every tool takes the same room, so it is one indicator moving rather
/// than nine switching on and off.
///
/// On the technical drawing and the model there is nothing to draw on, so
/// the indicator stands on **Select** — picking parts is what a tap does
/// there — and the drawing tools are dimmed; choosing one goes back to the
/// drawing with it in hand.
///
/// Where there is room the tools spread out to fill the bar; where there is
/// not — a narrow phone — they keep a thumb's width each and the bar
/// scrolls.
class ToolBar extends ConsumerWidget {
  const ToolBar({super.key});

  /// How tall the bar is.
  static const height = 68.0;

  /// The narrowest a tool is allowed to be: a thumb's width, with room for
  /// its name as one word.
  static const narrowest = 64.0;

  /// The widest a tool is allowed to be, so on a wide screen the bar does
  /// not spread nine tools across two metres of glass.
  static const widest = 96.0;

  /// The pill behind the active tool's icon.
  static const pill = Size(52, 30);

  static const _icons = {
    Tool.select: Icons.near_me_outlined,
    Tool.pen: Icons.draw_outlined,
    Tool.line: Icons.show_chart,
    Tool.rectangle: Icons.crop_square,
    Tool.polyline: Icons.polyline_outlined,
    Tool.dimension: Icons.straighten,
    Tool.arrow: Icons.arrow_outward,
    Tool.text: Icons.text_fields,
    Tool.eraser: Icons.cleaning_services_outlined,
  };

  /// The icon a [tool] is shown by.
  static IconData iconOf(Tool tool) => _icons[tool]!;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspaceProvider);
    final controller = ref.read(workspaceProvider.notifier);
    final drawing = state.view == WorkspaceView.draw;
    final active = drawing ? state.tool : Tool.select;
    final chosen = Tool.values.indexOf(active);
    final change = BarMotion.of(context, BarMotion.change);

    void use(Tool tool) {
      if (!drawing && tool != Tool.select) {
        controller.showView(WorkspaceView.draw);
      }
      controller.useTool(tool);
    }

    const colourRoom = 60.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border(top: BorderSide(color: context.palette.hairline)),
        boxShadow: [
          BoxShadow(
            color: context.palette.shadow.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final room = box.maxWidth - colourRoom - 12;
          final across = math.max(
            narrowest,
            math.min(widest, room / Tool.values.length),
          );
          return SizedBox(
            height: height,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: box.maxWidth - 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: across * Tool.values.length,
                      height: height,
                      child: Stack(
                        children: [
                          // The pill behind the active tool's icon.
                          AnimatedPositioned(
                            duration: change,
                            curve: Curves.easeOutBack,
                            left: across * chosen + (across - pill.width) / 2,
                            top: 8,
                            width: pill.width,
                            height: pill.height,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: context.palette.band,
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [
                                  BoxShadow(
                                    color: context.palette.band.withValues(
                                      alpha: 0.28,
                                    ),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // And the bar on the top edge above it.
                          AnimatedPositioned(
                            duration: change,
                            curve: Curves.easeOutBack,
                            left: across * chosen + (across - 28) / 2,
                            top: 0,
                            width: 28,
                            height: 3,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: context.palette.primary,
                                borderRadius: BorderRadius.vertical(
                                  bottom: Radius.circular(3),
                                ),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              for (final (i, tool) in Tool.values.indexed)
                                BarArrival(
                                  // Along the bar one after another, rising
                                  // from the edge they sit on.
                                  order: i,
                                  from: const Offset(0, 14),
                                  child: SizedBox(
                                    width: across,
                                    height: height,
                                    child: _ToolButton(
                                      tool: tool,
                                      icon: iconOf(tool),
                                      active: tool == active,
                                      dimmed: !drawing && tool != Tool.select,
                                      onTap: () => use(tool),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 32,
                      child: VerticalDivider(width: 12),
                    ),
                    BarArrival(
                      order: Tool.values.length,
                      from: const Offset(0, 14),
                      child: SizedBox(
                        width: colourRoom - 12,
                        height: height,
                        child: _PenColour(
                          colour: state.penColour,
                          onTap: () =>
                              _pickColour(context, ref, state.penColour),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickColour(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pen colour'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ColourPicker(
                colour: current,
                onChanged: (colour) {
                  ref.read(workspaceProvider.notifier).setPenColour(colour);
                  Navigator.of(context).pop();
                },
              ),
              if (context.palette.isDark) ...[
                const SizedBox(height: 14),
                Text(
                  'On the dark sheet a dark ink is shown light, so it can be '
                  'seen. The drawing keeps the colour you choose.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One tool: its icon, where the pill comes to stand behind it, and its
/// name under that. It lights up when the pointer is over it, gives a
/// little under the finger, and gives a small bounce once as it is chosen.
/// Every movement is a fraction of a second and finishes.
class _ToolButton extends StatefulWidget {
  final Tool tool;
  final IconData icon;
  final bool active;
  final bool dimmed;
  final VoidCallback onTap;

  const _ToolButton({
    required this.tool,
    required this.icon,
    required this.active,
    required this.onTap,
    this.dimmed = false,
  });

  @override
  State<_ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends State<_ToolButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final dimmed = widget.dimmed;
    final quick = BarMotion.of(context, BarMotion.hover);
    final change = BarMotion.of(context, BarMotion.change);
    final iconColour = active
        ? context.palette.onBand
        : dimmed
        ? context.palette.muted.withValues(alpha: 0.45)
        : (_hover ? context.palette.primary : context.palette.ink);
    final labelColour = active
        ? context.palette.primary
        : context.palette.muted.withValues(alpha: dimmed ? 0.45 : 1);
    // The active tool's pill is the bar's one moving indicator; a hover
    // only tints, so the two are never mistaken for each other.
    final tint = !active && _hover && !dimmed ? 0.08 : 0.0;

    return Tooltip(
      message: dimmed
          ? '${widget.tool.label}\nTap to go back to the drawing and use it.'
          : '${widget.tool.label}\n${widget.tool.hint}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _down ? 0.92 : 1,
            duration: quick,
            curve: Curves.easeOutBack,
            child: Column(
              children: [
                const SizedBox(height: 8),
                AnimatedContainer(
                  duration: quick,
                  curve: Curves.easeOutCubic,
                  width: ToolBar.pill.width,
                  height: ToolBar.pill.height,
                  decoration: BoxDecoration(
                    color: context.palette.primary.withValues(alpha: tint),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  // Lifted a little under the pointer, and a bounce, once,
                  // as it is chosen.
                  child: AnimatedSlide(
                    offset: Offset(0, _hover && !active ? -0.08 : 0),
                    duration: quick,
                    curve: Curves.easeOutCubic,
                    child: ChosenBounce(
                      chosen: active,
                      child: TweenAnimationBuilder<Color?>(
                        tween: ColorTween(end: iconColour),
                        duration: change,
                        builder: (context, colour, _) =>
                            Icon(widget.icon, size: 21, color: colour),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: change,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10,
                    height: 1.15,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    color: labelColour,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      widget.tool.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.fade,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PenColour extends StatelessWidget {
  final int colour;
  final VoidCallback onTap;

  const _PenColour({required this.colour, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Pen colour',
    child: Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            // The ink as it is drawn on this sheet — on a dark one, a dark
            // ink is shown light, as it is on the drawing.
            color: context.palette.legible(Color(colour)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.palette.edge, width: 1.4),
          ),
        ),
      ),
    ),
  );
}
