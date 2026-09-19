import 'package:flutter/material.dart';

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
  static const List<(int, String)> palette = [
    (0xFFFFFFFF, 'White'),
    (0xFFF3F4F2, 'Off white'),
    (0xFFD8D5CC, 'Cream'),
    (0xFF9C9C9C, 'Silver'),
    (0xFF6E7472, 'Grey'),
    (0xFF3A3A38, 'Graphite'),
    (0xFF1C1C1C, 'Black'),
    (0xFF013E37, 'Deep green'),
    (0xFF2C4A63, 'Steel blue'),
    (0xFF7B4A2B, 'Oak'),
    (0xFF4A2F1E, 'Walnut'),
    (0xFF8C1E20, 'Oxblood'),
    (0xFFD8E6EA, 'Clear glass'),
    (0xFFE7ECEA, 'Frosted'),
    (0xFFFFEFB3, 'Warm cream'),
  ];

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
              color: selected ? AppTheme.selection : AppTheme.hairline,
              width: selected ? 2.6 : 1,
            ),
          ),
        ),
      );
}
