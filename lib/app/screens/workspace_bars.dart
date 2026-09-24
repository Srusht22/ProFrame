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

/// Draw | CAD drawing | 3D model, with the highlight gliding to the view
/// chosen rather than jumping, so the eye follows the change.
class ViewTabs extends StatelessWidget {
  final WorkspaceView selected;
  final bool Function(WorkspaceView view) enabled;
  final ValueChanged<WorkspaceView> onSelected;
  final bool compact;

  const ViewTabs({
    super.key,
    required this.selected,
    required this.enabled,
    required this.onSelected,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final views = WorkspaceView.values;
    final width = compact ? 98.0 : 114.0;
    const height = 36.0;
    final index = views.indexOf(selected);
    final change = BarMotion.of(context, BarMotion.change);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.shell,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.hairline),
      ),
      child: SizedBox(
        width: width * views.length,
        height: height,
        child: Stack(
          children: [
            // The highlight, behind whichever view is chosen.
            AnimatedPositioned(
              duration: change,
              curve: Curves.easeOutBack,
              left: width * index,
              top: 0,
              width: width,
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                for (final view in views)
                  _Tab(
                    label: view.label,
                    width: width,
                    chosen: view == selected,
                    enabled: enabled(view),
                    onTap: () => onSelected(view),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatefulWidget {
  final String label;
  final double width;
  final bool chosen;
  final bool enabled;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
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
        ? AppTheme.accent
        : widget.enabled
            ? (_hover ? AppTheme.primary : AppTheme.ink)
            : AppTheme.muted.withValues(alpha: 0.5);
    return MouseRegion(
      cursor: widget.enabled && !widget.chosen
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: BarMotion.of(context, BarMotion.hover),
          width: widget.width,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: AppTheme.primary.withValues(
              alpha: _hover && widget.enabled && !widget.chosen ? 0.07 : 0,
            ),
          ),
          child: AnimatedDefaultTextStyle(
            duration: BarMotion.of(context, BarMotion.change),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              fontWeight: widget.chosen ? FontWeight.w700 : FontWeight.w600,
              letterSpacing: 0.3,
              color: colour,
            ),
            child: Text(widget.label, maxLines: 1),
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
