import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import 'view_mode.dart';

/// The way the model is shown, chosen in the top left corner of the view.
///
/// **Modern and unobtrusive, and never over the model.** It sits in the
/// band along the top of the view that the model is always framed clear of
/// (`ModelView.controlsTop`), across from the projection switch, and takes
/// only the room that is left beside it. Where that is enough, every mode
/// is named side by side, one tap each; where it is not — a phone — it is
/// one button naming the mode shown, which opens the list; and where even
/// that is too wide, the button is the mode's mark alone. The room each
/// needs is measured from the labels as they will be written, never
/// guessed, so the switch cannot run under the projection beside it.
class ViewModeSwitch extends StatelessWidget {
  final ViewMode mode;
  final List<ViewMode> modes;
  final ValueChanged<ViewMode> onChanged;

  const ViewModeSwitch({
    super.key,
    required this.mode,
    required this.onChanged,
    this.modes = ViewMode.shown,
  });

  static Key keyOf(ViewMode m) => ValueKey('view-mode-${m.name}');
  static const menuKey = ValueKey('view-mode-menu');

  static IconData iconOf(ViewMode m) => switch (m) {
    ViewMode.technical => Icons.architecture_outlined,
    ViewMode.shaded => Icons.contrast,
    ViewMode.material => Icons.texture,
    ViewMode.realistic => Icons.wb_sunny_outlined,
    ViewMode.wireframe => Icons.grid_on,
  };

  /// Round an option: its padding, its mark and the gap after the mark;
  /// then the list's chevron, and the rim round the whole switch.
  static const double _optionPadding = 18, _mark = 15, _gap = 5;
  static const double _chevron = 18, _rim = 6;

  static TextStyle _labelStyle(bool on) => TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontFamilyFallback: AppTheme.fontFallback,
    fontSize: 12,
    fontWeight: on ? FontWeight.w700 : FontWeight.w500,
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scaler = MediaQuery.textScalerOf(context);
      // As wide as the label is written chosen, which is the wider.
      double label(ViewMode m) =>
          (TextPainter(
            text: TextSpan(
              text: m.labelIn(context.l10n),
              style: _labelStyle(true),
            ),
            textDirection: Directionality.of(context),
            textScaler: scaler,
          )..layout()).width.ceilToDouble() +
          1;
      final room = constraints.maxWidth;
      final spread =
          _rim +
          modes.fold<double>(
            0,
            (sum, m) => sum + _optionPadding + _mark + _gap + label(m),
          );
      final named =
          _rim + _optionPadding + _mark + _gap + label(mode) + _chevron;
      final Widget child;
      if (spread <= room) {
        child = _spread(context);
      } else if (named <= room) {
        child = _menu(named: true);
      } else {
        // Even the mark alone is made smaller rather than run under the
        // switch beside it.
        child = FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: _menu(named: false),
        );
      }
      return Material(
        color: context.palette.surface,
        elevation: 1,
        borderRadius: BorderRadius.circular(10),
        child: Padding(padding: const EdgeInsets.all(3), child: child),
      );
    },
  );

  Widget _spread(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final m in modes)
        Tooltip(
          message: m.hintIn(context.l10n),
          child: InkWell(
            key: keyOf(m),
            borderRadius: BorderRadius.circular(8),
            // The chosen one still takes its tap, so a tap on it is never
            // a tap on the model underneath, which would pick nothing and
            // put down whatever was picked.
            onTap: () {
              if (m != mode) onChanged(m);
            },
            child: _Option(mode: m, on: m == mode),
          ),
        ),
    ],
  );

  Widget _menu({required bool named}) => PopupMenuButton<ViewMode>(
    key: menuKey,
    tooltip: 'How the model is shown',
    initialValue: mode,
    onSelected: onChanged,
    position: PopupMenuPosition.under,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    itemBuilder: (context) => [
      for (final m in modes)
        PopupMenuItem(
          key: keyOf(m),
          value: m,
          height: 44,
          child: Row(
            children: [
              Icon(
                iconOf(m),
                size: 18,
                color: m == mode
                    ? context.palette.primary
                    : context.palette.muted,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      m.labelIn(context.l10n),
                      style: _labelStyle(m == mode).copyWith(
                        fontSize: 13,
                        color: m == mode
                            ? context.palette.primary
                            : context.palette.ink,
                      ),
                    ),
                    Text(
                      m.hintIn(context.l10n),
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontFamilyFallback: AppTheme.fontFallback,
                        fontSize: 11,
                        color: context.palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ],
    child: _Option(mode: mode, on: true, opens: true, named: named),
  );
}

/// One mode, named beside its mark; the one shown is tinted.
class _Option extends StatelessWidget {
  final ViewMode mode;
  final bool on;

  /// Whether this is the button that opens the list, so it says so.
  final bool opens;

  /// Whether the mode is named beside its mark.
  final bool named;

  const _Option({
    required this.mode,
    required this.on,
    this.opens = false,
    this.named = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final colour = on ? palette.primary : palette.muted;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: on && !opens
            ? palette.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ViewModeSwitch.iconOf(mode), size: 15, color: colour),
          if (named) ...[
            const SizedBox(width: 5),
            Text(
              mode.labelIn(context.l10n),
              style: ViewModeSwitch._labelStyle(on).copyWith(color: colour),
            ),
          ],
          if (opens) ...[
            const SizedBox(width: 2),
            Icon(Icons.expand_more, size: 16, color: colour),
          ],
        ],
      ),
    );
  }
}
