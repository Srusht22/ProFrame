import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// A plain surface card used across the app.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Border? border;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: border ?? Border.all(color: theme.dividerColor),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: content,
    );
  }
}

/// Section heading that never overflows on a narrow phone.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) Flexible(child: trailing!),
        ],
      ),
    );
  }
}

/// A labelled millimetre field. Commits on submit or focus loss so typing
/// never fights the live 3D update.
class MillimetreField extends StatefulWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final String? helper;
  final bool enabled;

  const MillimetreField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
    this.enabled = true,
  });

  @override
  State<MillimetreField> createState() => _MillimetreFieldState();
}

class _MillimetreFieldState extends State<MillimetreField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value.round().toString());
  late final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant MillimetreField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && widget.value != oldWidget.value) {
      _controller.text = widget.value.round().toString();
    }
  }

  void _commit() {
    final parsed = double.tryParse(_controller.text.trim());
    if (parsed == null || parsed <= 0) {
      _controller.text = widget.value.round().toString();
      return;
    }
    if (parsed != widget.value) widget.onChanged(parsed);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      enabled: widget.enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _commit(),
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helper,
        helperMaxLines: 2,
        suffixText: 'mm',
        isDense: true,
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: AppSpacing.md), action!],
          ],
        ),
      ),
    );
  }
}

/// A short status chip: recognised, uncertain, missing.
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const StatusChip({super.key, required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
