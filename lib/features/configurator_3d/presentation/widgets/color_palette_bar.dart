import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../../../domain/configuration/configuration_options.dart';

class ColorPaletteBar extends StatefulWidget {
  final FrameColorType selectedColor;
  final String? customHexColor;
  final Function(FrameColorType, [String? hex]) onColorSelected;

  const ColorPaletteBar({
    super.key,
    required this.selectedColor,
    this.customHexColor,
    required this.onColorSelected,
  });

  @override
  State<ColorPaletteBar> createState() => _ColorPaletteBarState();
}

class _ColorPaletteBarState extends State<ColorPaletteBar> {
  late TextEditingController _hexController;
  bool _showHexInput = false;

  final List<String> _popularRalColors = [
    '#3B82F6', // Cobalt Blue
    '#10B981', // Forest Green
    '#EF4444', // Signal Red
    '#F59E0B', // Golden Yellow
    '#8B5CF6', // Royal Purple
    '#78350F', // Chestnut Brown
    '#1E293B', // Slate Dark
    '#0F766E', // Deep Teal
  ];

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController(text: widget.customHexColor ?? '#3B82F6');
    _showHexInput = widget.selectedColor == FrameColorType.custom;
  }

  @override
  void didUpdateWidget(covariant ColorPaletteBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedColor == FrameColorType.custom && !_showHexInput) {
      _showHexInput = true;
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _applyHex(String hex) {
    String formatted = hex.trim();
    if (!formatted.startsWith('#')) formatted = '#$formatted';
    if (RegExp(r'^#([A-Fa-f0-9]{6})$').hasMatch(formatted)) {
      widget.onColorSelected(FrameColorType.custom, formatted);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: FrameColorType.values.map((colorType) {
            final isSelected = widget.selectedColor == colorType;
            final isCustom = colorType == FrameColorType.custom;
            Color previewColor = colorType.color;

            if (isCustom && widget.customHexColor != null) {
              final parsed = int.tryParse(widget.customHexColor!.replaceAll('#', ''), radix: 16);
              if (parsed != null) {
                previewColor = Color(0xFF000000 | parsed);
              }
            }

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (isCustom) {
                    setState(() => _showHexInput = true);
                    _applyHex(_hexController.text);
                  } else {
                    setState(() => _showHexInput = false);
                    widget.onColorSelected(colorType);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.surfaceElevated : AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : AppTheme.surfaceBorder,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: previewColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: previewColor.computeLuminance() > 0.6 ? Colors.black26 : Colors.white24,
                            width: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        colorType.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        if (_showHexInput || widget.selectedColor == FrameColorType.custom) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.surfaceBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Custom RAL / Factory Color Code',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _hexController,
                        decoration: InputDecoration(
                          hintText: '#2A52BE or #FF5733',
                          filled: true,
                          fillColor: AppTheme.background,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppTheme.surfaceBorder),
                          ),
                        ),
                        onSubmitted: _applyHex,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _applyHex(_hexController.text),
                      child: const Text('Apply'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: _popularRalColors.map((hex) {
                    final intColor = int.parse(hex.replaceFirst('#', ''), radix: 16);
                    return InkWell(
                      onTap: () {
                        _hexController.text = hex;
                        _applyHex(hex);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Color(0xFF000000 | intColor),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
