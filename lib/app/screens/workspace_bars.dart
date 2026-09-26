import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/tools.dart';
import '../theme/app_theme.dart';

/// How the bars across the top of the workspace move: in one place, so the
/// title, the icons and the view tabs keep the same pace.
///
/// Everything here is a fraction of a second and finishes — nothing loops —
/// and a device that has asked for less motion gets every part already in
/// place.
abstract final class BarMotion {
  /// A part changing state: a highlight moving, a colour turning.
  static const change = Duration(milliseconds: 360);

  /// A hover coming and going: quicker, because the pointer is quick.
  static const hover = Duration(milliseconds: 180);

  /// How long one part takes to arrive when the workspace opens.
  static const arrive = Duration(milliseconds: 420);

  /// How far behind the one before it each part arrives.
  static const stagger = Duration(milliseconds: 55);

  /// [d], or nothing when less motion has been asked for.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.of(context).disableAnimations ? Duration.zero : d;
}

/// A part of a bar arriving when the workspace opens: [order]-th, fading in
/// and settling from a little way off along [from].
class BarArrival extends StatelessWidget {
  final int order;
  final Offset from;
  final Widget child;

  const BarArrival({
    super.key,
    required this.order,
    required this.child,
    this.from = const Offset(0, -10),
  });

  @override
  Widget build(BuildContext context) {
    final delay = BarMotion.stagger * order;
    final total = BarMotion.of(context, BarMotion.arrive + delay);
    if (total == Duration.zero) return child;
    final start = delay.inMicroseconds / total.inMicroseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: from * (1 - t), child: child),
      ),
      child: child,
    );
  }
}

/// An icon on the top bar: a soft halo under the pointer, a squeeze when
/// pressed, a fade when it has nothing to do, and a small turn when its
/// icon changes.
class BarIcon extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Dimmed without being disabled — a switch that is off.
  final bool dim;

  const BarIcon({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.dim = false,
  });

  @override
  State<BarIcon> createState() => _BarIconState();
}

class _BarIconState extends State<BarIcon> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final quick = BarMotion.of(context, BarMotion.hover);
    final change = BarMotion.of(context, BarMotion.change);
    final opacity = !enabled ? 0.3 : (widget.dim ? 0.5 : 1.0);

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _down = true) : null,
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: AnimatedScale(
              scale: _down ? 0.86 : (_hover && enabled ? 1.08 : 1),
              duration: quick,
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: quick,
                curve: Curves.easeOutCubic,
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accent.withValues(
                    alpha: _hover && enabled ? 0.14 : 0,
                  ),
                ),
                child: AnimatedOpacity(
                  opacity: opacity,
                  duration: change,
                  child: AnimatedSwitcher(
                    duration: change,
                    switchInCurve: Curves.easeOutBack,
                    transitionBuilder: (child, animation) => RotationTransition(
                      turns: Tween(begin: -0.12, end: 0.0).animate(animation),
                      child: ScaleTransition(scale: animation, child: child),
                    ),
                    child: Icon(
                      widget.icon,
                      key: ValueKey(widget.icon),
                      color: AppTheme.accent,
                      size: 23,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The save icon: it turns into a tick for a moment once the design is
/// saved, then back — one animation, played through and finished.
class SaveIcon extends StatefulWidget {
  final Future<void> Function() onSave;

  const SaveIcon({super.key, required this.onSave});

  @override
  State<SaveIcon> createState() => _SaveIconState();
}

class _SaveIconState extends State<SaveIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _saved = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..addListener(() => setState(() {}));

  @override
  void dispose() {
    _saved.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.onSave();
    if (!mounted) return;
    if (MediaQuery.of(context).disableAnimations) return;
    _saved.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final showingTick = _saved.isAnimating && _saved.value < 0.8;
    return BarIcon(
      tooltip: 'Save',
      icon: showingTick ? Icons.check_rounded : Icons.save_outlined,
      onPressed: _save,
    );
  }
}

/// Draw | CAD drawing | 3D model: the navigation across the top of the
/// workspace.
///
/// **The active view is marked by one indicator that moves** — a soft pill
/// behind it and a bar along its foot — gliding to the view chosen and
/// settling with a slight overshoot, rather than one tab switching off and
/// another on. The same arrangement as the tools along the bottom, so the
/// two navigation bars read as one design.
class ViewTabs extends StatelessWidget {
  final WorkspaceView selected;
  final bool Function(WorkspaceView view) enabled;
  final ValueChanged<WorkspaceView> onSelected;
  final bool compact;

  /// On a phone: the tabs share whatever width they are given between them,
  /// and each is called by its one-word name.
  final bool fill;

  const ViewTabs({
    super.key,
    required this.selected,
    required this.enabled,
    required this.onSelected,
    this.compact = false,
    this.fill = false,
  });

  /// How tall the bar of views is.
  static const height = 44.0;

  static const _icons = {
    WorkspaceView.draw: Icons.gesture,
    WorkspaceView.plan: Icons.architecture,
    WorkspaceView.model: Icons.view_in_ar_outlined,
  };

  /// The icon a [view] is shown by.
  static IconData iconOf(WorkspaceView view) => _icons[view]!;

  @override
  Widget build(BuildContext context) {
    if (fill) {
      return LayoutBuilder(
        builder: (context, box) =>
            _tabs(context, box.maxWidth / WorkspaceView.values.length),
      );
    }
    return _tabs(context, compact ? 128.0 : 144.0);
  }

  Widget _tabs(BuildContext context, double width) {
    final views = WorkspaceView.values;
    final index = views.indexOf(selected);
    final change = BarMotion.of(context, BarMotion.change);
    final underline = math.min(width * 0.6, 64.0);

    return SizedBox(
      width: width * views.length,
      height: height,
      child: Stack(
        children: [
          // The pill, behind whichever view is chosen.
          AnimatedPositioned(
            duration: change,
            curve: Curves.easeOutBack,
            left: width * index + 3,
            top: 3,
            width: width - 6,
            height: height - 9,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.palette.primary.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // And the bar along its foot.
          AnimatedPositioned(
            duration: change,
            curve: Curves.easeOutBack,
            left: width * index + (width - underline) / 2,
            bottom: 0,
            width: underline,
            height: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.palette.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
              ),
            ),
          ),
          Row(
            children: [
              for (final view in views)
                _Tab(
                  label: fill ? view.shortLabel : view.label,
                  icon: iconOf(view),
                  width: width,
                  chosen: view == selected,
                  enabled: enabled(view),
                  onTap: () => onSelected(view),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatefulWidget {
  final String label;
  final IconData icon;
  final double width;
  final bool chosen;
  final bool enabled;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.icon,
    required this.width,
    required this.chosen,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colour = widget.chosen
        ? context.palette.primary
        : widget.enabled
        ? (_hover ? context.palette.primary : context.palette.muted)
        : context.palette.muted.withValues(alpha: 0.45);
    final change = BarMotion.of(context, BarMotion.change);
    return MouseRegion(
      cursor: widget.enabled && !widget.chosen
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.onTap : null,
        // The width is the room there is, set outright: animated, a tab
        // would pass through its old width as the screen changed and push
        // the others off the end of the bar for a moment.
        child: SizedBox(
          width: widget.width,
          height: ViewTabs.height - 3,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChosenBounce(
                chosen: widget.chosen,
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: colour),
                  duration: change,
                  builder: (context, c, _) =>
                      Icon(widget.icon, size: 18, color: c),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: AnimatedDefaultTextStyle(
                  duration: change,
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: widget.chosen
                        ? FontWeight.w700
                        : FontWeight.w600,
                    letterSpacing: 0.2,
                    color: colour,
                  ),
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small bounce, once, for an icon that has just been chosen: keyed on
/// being chosen, so it plays when that changes and not on every rebuild.
class ChosenBounce extends StatelessWidget {
  final bool chosen;
  final Widget child;

  const ChosenBounce({super.key, required this.chosen, required this.child});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(chosen),
    tween: Tween(begin: chosen ? 0 : 1, end: 1),
    duration: BarMotion.of(context, const Duration(milliseconds: 460)),
    curve: Curves.easeOut,
    builder: (context, t, child) => Transform.scale(
      scale: 1 + 0.22 * math.sin(math.pi * t),
      child: Transform.rotate(
        angle: 0.18 * math.sin(math.pi * t),
        child: child,
      ),
    ),
    child: child,
  );
}

/// **More** — the one button that shows every control, and **Less**, which
/// puts them away again. See `EverythingShown`.
///
/// Always a word as well as an icon, even on a phone: it is the button a
/// person who does not know the application has to find, and an icon on
/// its own would be one more thing to guess at.
class MoreButton extends StatelessWidget {
  /// Whether everything is shown now.
  final bool shown;

  /// Tighter, for a phone's bar.
  final bool compact;
  final VoidCallback onPressed;

  const MoreButton({
    super.key,
    required this.shown,
    required this.onPressed,
    this.compact = false,
  });

  static const buttonKey = ValueKey('more-tools');

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tooltip(
      message: shown ? 'Show fewer tools' : 'Show every tool',
      child: TextButton.icon(
        key: buttonKey,
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          backgroundColor: shown
              ? p.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          visualDensity: compact ? VisualDensity.compact : null,
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: p.hairline),
          ),
        ),
        icon: Icon(shown ? Icons.expand_less : Icons.more_horiz, size: 18),
        label: Text(shown ? 'Less' : 'More'),
      ),
    );
  }
}
