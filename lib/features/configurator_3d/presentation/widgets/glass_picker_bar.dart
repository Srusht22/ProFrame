import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../../../domain/configuration/configuration_options.dart';

class GlassPickerBar extends StatelessWidget {
  final GlassType selectedGlass;
  final Function(GlassType) onGlassSelected;

  const GlassPickerBar({
    super.key,
    required this.selectedGlass,
    required this.onGlassSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: GlassType.values.map((glassType) {
        final isSelected = selectedGlass == glassType;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onGlassSelected(glassType),
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
                      color: glassType.previewColor.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white24, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 12,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    glassType.label,
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
    );
  }
}
