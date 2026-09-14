import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../inspector/colour_picker.dart';
import '../state/tools.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';

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

    return Container(
      width: width,
      color: AppTheme.surface,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 10),
        children: [
          for (final tool in Tool.values)
            _ToolButton(
              tool: tool,
              icon: _icons[tool]!,
              selected: state.tool == tool,
              compact: compact,
              onTap: () => controller.useTool(tool),
            ),
          const Divider(height: 22, indent: 14, endIndent: 14),
          _PenColour(
            colour: state.penColour,
            onTap: () => _pickColour(context, ref, state.penColour),
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

class _ToolButton extends StatelessWidget {
  final Tool tool;
  final IconData icon;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _ToolButton({
    required this.tool,
    required this.icon,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: '${tool.label}\n${tool.hint}',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Material(
            color: selected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: compact ? 9 : 8),
                child: Column(
                  children: [
                    Icon(
                      icon,
                      size: 21,
                      color: selected ? AppTheme.accent : AppTheme.ink,
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 3),
                      Text(
                        tool.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: 9.5,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? AppTheme.accent
                              : AppTheme.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
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
