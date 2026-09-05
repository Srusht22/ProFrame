import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../../../three_d/models/scene_messages.dart';

class CameraHUD extends StatelessWidget {
  final Function(CameraPreset) onPresetSelected;
  final VoidCallback onResetView;
  final VoidCallback onToggleAutoRotate;
  final VoidCallback onToggleDimensions;
  final bool isAutoRotateActive;
  final bool areDimensionsActive;

  const CameraHUD({
    super.key,
    required this.onPresetSelected,
    required this.onResetView,
    required this.onToggleAutoRotate,
    required this.onToggleDimensions,
    required this.isAutoRotateActive,
    required this.areDimensionsActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIconButton(
            icon: Icons.threed_rotation_rounded,
            tooltip: '3D Isometric View',
            onTap: () => onPresetSelected(CameraPreset.perspective),
          ),
          _buildIconButton(
            icon: Icons.crop_portrait_rounded,
            tooltip: 'Front View',
            onTap: () => onPresetSelected(CameraPreset.front),
          ),
          _buildIconButton(
            icon: Icons.border_top_rounded,
            tooltip: 'Top View',
            onTap: () => onPresetSelected(CameraPreset.top),
          ),
          _buildIconButton(
            icon: Icons.border_left_rounded,
            tooltip: 'Side View',
            onTap: () => onPresetSelected(CameraPreset.left),
          ),
          const SizedBox(width: 6),
          Container(width: 1, height: 26, color: AppTheme.surfaceBorder),
          const SizedBox(width: 6),
          _buildIconButton(
            icon: Icons.straighten_rounded,
            tooltip: areDimensionsActive ? 'Hide Dimension Lines' : 'Show Dimension Lines',
            isActive: areDimensionsActive,
            activeColor: const Color(0xFF38BDF8),
            onTap: onToggleDimensions,
          ),
          _buildIconButton(
            icon: Icons.autorenew_rounded,
            tooltip: isAutoRotateActive ? 'Stop Auto-Rotate' : 'Start Auto-Rotate',
            isActive: isAutoRotateActive,
            activeColor: AppTheme.accentSuccess,
            onTap: onToggleAutoRotate,
          ),
          _buildIconButton(
            icon: Icons.center_focus_strong_rounded,
            tooltip: 'Reset Camera View',
            onTap: onResetView,
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool isActive = false,
    Color? activeColor,
  }) {
    final effectiveColor = isActive ? (activeColor ?? const Color(0xFF38BDF8)) : AppTheme.textSecondary;
    final bgColor = isActive ? (activeColor ?? const Color(0xFF38BDF8)).withOpacity(0.2) : Colors.transparent;

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: isActive
                  ? Border.all(color: (activeColor ?? const Color(0xFF38BDF8)).withOpacity(0.6), width: 1)
                  : null,
            ),
            child: Icon(
              icon,
              size: 20,
              color: effectiveColor,
            ),
          ),
        ),
      ),
    );
  }
}
