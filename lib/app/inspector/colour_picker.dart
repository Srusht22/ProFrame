import 'package:flutter/material.dart';

import '../../domain/model/materials.dart';
import '../theme/app_theme.dart';

/// Picking a colour for the part that is selected.
///
/// A row of the colours joinery actually comes in, and a wheel for anything
/// else. The colour goes on the selected part alone.
class ColourPicker extends StatelessWidget {
  final int colour;
  final ValueChanged<int> onChanged;

  const ColourPicker({
    super.key,
    required this.colour,
    required this.onChanged,
  });

  /// The finishes a workshop actually stocks, plus the two the design system
  /// is built from.
  static const List<(int, String)> palette = finishPalette;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (value, name) in palette)
            Tooltip(
              message: name,
              child: _Swatch(
                colour: value,
                selected: value == colour,
                onTap: () => onChanged(value),
              ),
            ),
        ],
      );
}

class _Swatch extends StatelessWidget {
  final int colour;
  final bool selected;
  final VoidCallback onTap;

  const _Swatch({
    required this.colour,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Color(colour),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected
                  ? context.palette.selection
                  : context.palette.edge,
              width: selected ? 2.6 : 1,
            ),
          ),
        ),
      );
}
