import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/sketch.dart';

class ToolDefinition {
  final SketchTool tool;
  final IconData icon;
  final String tooltip;

  const ToolDefinition(this.tool, this.icon, this.tooltip);
}

/// The drawing tools, in the order they are actually used: draw the outline,
/// divide it, mark how it opens, measure it, annotate it.
const List<ToolDefinition> drawingTools = [
  ToolDefinition(SketchTool.pen, Icons.gesture, 'Freehand — draw anything'),
  ToolDefinition(SketchTool.rectangle, Icons.crop_square, 'Outline rectangle'),
  ToolDefinition(SketchTool.line, Icons.show_chart, 'Straight line'),
  ToolDefinition(SketchTool.division, Icons.view_column_outlined, 'Division (mullion / transom)'),
  ToolDefinition(SketchTool.diagonal, Icons.change_history, 'Opening direction'),
  ToolDefinition(SketchTool.arc, Icons.rotate_right, 'Swing arc'),
  ToolDefinition(SketchTool.arrow, Icons.arrow_right_alt, 'Sliding arrow'),
  ToolDefinition(SketchTool.dimension, Icons.straighten, 'Dimension line'),
  ToolDefinition(SketchTool.note, Icons.sticky_note_2_outlined, 'Note'),
  ToolDefinition(SketchTool.eraser, Icons.cleaning_services_outlined, 'Eraser'),
  ToolDefinition(SketchTool.select, Icons.highlight_alt, 'Select'),
  ToolDefinition(SketchTool.pan, Icons.pan_tool_alt_outlined, 'Pan the sheet'),
];

class ToolPalette extends StatelessWidget {
  final SketchTool selected;
  final ValueChanged<SketchTool> onSelected;
  final Axis direction;

  const ToolPalette({
    super.key,
    required this.selected,
    required this.onSelected,
    this.direction = Axis.vertical,
  });

  @override
  Widget build(BuildContext context) {
    final buttons = drawingTools
        .map((definition) => _ToolButton(
              definition: definition,
              selected: definition.tool == selected,
              onTap: () => onSelected(definition.tool),
            ))
        .toList();

    if (direction == Axis.vertical) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(children: buttons),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(children: buttons),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final ToolDefinition definition;
  final bool selected;
  final VoidCallback onTap;

  const _ToolButton({
    required this.definition,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Tooltip(
        message: definition.tooltip,
        child: Semantics(
          selected: selected,
          button: true,
          label: definition.tooltip,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected ? AppColors.brandDarkGreen : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(
                  color: selected ? AppColors.brandDarkGreen : AppColors.neutralBorder,
                ),
              ),
              child: Icon(
                definition.icon,
                size: 20,
                color: selected ? AppColors.brandCream : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
