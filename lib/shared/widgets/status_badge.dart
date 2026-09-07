import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Renders any status enum's `.name` consistently colored via
/// [AppColors.statusPalette], so quotations/orders/manufacturing all read
/// as one visual language.
class StatusBadge extends StatelessWidget {
  final String statusKey;
  final String label;

  const StatusBadge({super.key, required this.statusKey, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.statusPalette[statusKey] ?? AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
