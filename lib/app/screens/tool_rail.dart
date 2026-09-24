import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../inspector/colour_picker.dart';
import '../state/tools.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';
import 'workspace_bars.dart';

/// The tools, down the left.
///
/// Each one makes real geometry rather than a picture of something, and each
/// says plainly what it does, because a tool that is guessed at is a drawing
/// that comes out wrong.
class ToolRail extends ConsumerWidget {
  final bool compact;

  const ToolRail({super.key, this.compact = false});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspaceProvider);
    final controller = ref.read(workspaceProvider.notifier);
    final width = compact ? 62.0 : 76.0;

    // The pen belongs to the sheet. On the technical drawing and on the
    // model there is nothing to draw on, so the tools say so rather than
    // quietly doing nothing when tapped.
    final drawing = state.view == WorkspaceView.draw;

    // Every tool takes the same room, so the highlight can glide from one
    // to the next rather than jumping: it is one pill that moves, not nine
    // that switch on and off.
    final extent = compact ? 50.0 : 62.0;
    final chosen = Tool.values.indexOf(state.tool);
    final change = BarMotion.of(context, BarMotion.change);

    return Container(
      width: width,
      color: AppTheme.surface,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 10),
        children: [
          SizedBox(
            height: extent * Tool.values.length,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: change,
                  curve: Curves.easeOutBack,
                  top: extent * chosen + 3,
                  left: 8,
                  right: 8,
                  height: extent - 6,
                  child: AnimatedOpacity(
                    // On the drawing and the model there is no pen in hand,
                    // so there is nothing to highlight.
                    opacity: drawing ? 1 : 0,
                    duration: change,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Column(
                  children: [
                    for (final (i, tool) in Tool.values.indexed)
                      BarArrival(
                        // Down the rail one after another, from the side
                        // they sit on.
                        order: i,
                        from: const Offset(-16, 0),
                        child: SizedBox(
                          height: extent,
                          child: _ToolButton(
                            tool: tool,
                            icon: _icons[tool]!,
                            selected: drawing && state.tool == tool,
                            dimmed: !drawing && tool != Tool.select,
                            compact: compact,
                            onTap: () {
                              if (!drawing && tool != Tool.select) {
                                controller.showView(WorkspaceView.draw);
                              }
                              controller.useTool(tool);
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 22, indent: 14, endIndent: 14),
          BarArrival(
            order: Tool.values.length,
            from: const Offset(-16, 0),
            child: _PenColour(
              colour: state.penColour,
              onTap: () => _pickColour(context, ref, state.penColour),
            ),
          ),
        ],
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
          child: ColourPicker(
            colour: current,
            onChanged: (colour) {
              ref.read(workspaceProvider.notifier).setPenColour(colour);
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );
  }
}

/// One tool: it lights up when the pointer is over it, and when chosen its
/// highlight fills in and its icon gives a small bounce, so the eye follows
/// the choice rather than hunting for which one changed. Every movement is a
/// fraction of a second and finishes.
class _ToolButton extends StatefulWidget {
  final Tool tool;
  final IconData icon;
  final bool selected;
  final bool dimmed;
  final bool compact;
  final VoidCallback onTap;

  const _ToolButton({
    required this.tool,
    required this.icon,
    required this.selected,
    required this.compact,
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
    final selected = widget.selected;
    final dimmed = widget.dimmed;
    final quick = BarMotion.of(context, BarMotion.hover);
    final change = BarMotion.of(context, BarMotion.change);
    final iconColour = selected
        ? AppTheme.accent
        : dimmed
            ? AppTheme.muted.withValues(alpha: 0.45)
            : (_hover ? AppTheme.primary : AppTheme.ink);
    final labelColour = selected
        ? AppTheme.accent
        : AppTheme.muted.withValues(alpha: dimmed ? 0.45 : 1);
    // The chosen tool's highlight is the rail's one gliding pill; a hover
    // only tints, so the two are never mistaken for each other.
    final tint = !selected && _hover && !dimmed ? 0.07 : 0.0;

    return Tooltip(
      message: dimmed
          ? '${widget.tool.label}\nTap to go back to the drawing and use it.'
          : '${widget.tool.label}\n${widget.tool.hint}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: AnimatedScale(
            // It gives a little under the finger.
            scale: _down ? 0.92 : 1,
            duration: quick,
            curve: Curves.easeOutBack,
            child: AnimatedContainer(
              duration: quick,
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: tint),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: widget.onTap,
                  onHighlightChanged: (down) => setState(() => _down = down),
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Lifted a little under the pointer, and a bounce, once,
                      // as it is chosen.
                      AnimatedSlide(
                        offset: Offset(0, _hover && !selected ? -0.08 : 0),
                        duration: quick,
                        curve: Curves.easeOutCubic,
                        child: ChosenBounce(
                          chosen: selected,
                          child: TweenAnimationBuilder<Color?>(
                            tween: ColorTween(end: iconColour),
                            duration: change,
                            builder: (context, colour, _) =>
                                Icon(widget.icon, size: 21, color: colour),
                          ),
                        ),
                      ),
                      if (!widget.compact) ...[
                        const SizedBox(height: 3),
                        AnimatedDefaultTextStyle(
                          duration: change,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 9.5,
                            height: 1.15,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w600,
                            color: labelColour,
                          ),
                          child: Text(
                            widget.tool.label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
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
                color: Color(colour),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.hairline, width: 1.4),
              ),
            ),
          ),
        ),
      );
}
