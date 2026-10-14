import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../domain/model/question.dart';
import '../theme/app_theme.dart';

/// How an alert over the work comes and goes, in one place, so every alert
/// in the application moves the same way.
///
/// **Arriving** the work behind is blurred back and dimmed over a moment
/// rather than all at once, and the card rises into place and settles, with
/// its icon popping in and its contents following one after another — so the
/// eye goes to the question, then the choices. **Leaving** is quicker than
/// arriving, because once the user has answered they want their drawing
/// back. **The next question** of several plays its arrival again, so three
/// questions in a row read as three questions and not one that changed its
/// words.
///
/// Every movement finishes: nothing here loops, so the screen is still while
/// the user reads it, and a device that has asked for less motion gets the
/// alert already in place and gone the moment it is answered.
class AlertLayer extends StatefulWidget {
  /// What is being asked, or null when nothing is.
  final DesignQuestion? question;

  /// The card for [question]. Its parts use [AlertStep] to arrive in turn.
  final Widget Function(DesignQuestion question) cardFor;

  const AlertLayer({super.key, required this.question, required this.cardFor});

  /// How long the alert takes to arrive: long enough to be seen to come,
  /// short enough that nobody waits on it.
  static const arriving = Duration(milliseconds: 520);

  /// How long it takes to go.
  static const leaving = Duration(milliseconds: 240);

  @override
  State<AlertLayer> createState() => _AlertLayerState();
}

class _AlertLayerState extends State<AlertLayer> with TickerProviderStateMixin {
  /// The blur and the dimming behind: up while any question is being asked.
  late final AnimationController _backdrop = AnimationController(
    vsync: this,
    duration: AlertLayer.arriving,
    reverseDuration: AlertLayer.leaving,
  );

  /// The card: played again for each new question.
  late final AnimationController _card = AnimationController(
    vsync: this,
    duration: AlertLayer.arriving,
    reverseDuration: AlertLayer.leaving,
  );

  /// What is on the card, kept while it leaves so it does not go blank on
  /// its way out.
  DesignQuestion? _shown;

  bool get _still => MediaQuery.of(context).disableAnimations;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_shown == null && widget.question != null) _arrive(widget.question!);
  }

  @override
  void didUpdateWidget(AlertLayer old) {
    super.didUpdateWidget(old);
    final next = widget.question;
    if (next == null) {
      if (_shown != null) _leave();
    } else if (_shown == null || _shown!.id != next.id) {
      _arrive(next);
    } else {
      _shown = next;
    }
  }

  void _arrive(DesignQuestion question) {
    final first = _shown == null || _backdrop.status == AnimationStatus.reverse;
    _shown = question;
    if (_still) {
      _backdrop.value = 1;
      _card.value = 1;
      return;
    }
    if (first) _backdrop.forward();
    _card.forward(from: 0);
  }

  Future<void> _leave() async {
    if (_still) {
      setState(() => _shown = null);
      _backdrop.value = 0;
      _card.value = 0;
      return;
    }
    await Future.wait([_card.reverse(), _backdrop.reverse()]);
    // A new question may have arrived while this one was going.
    if (mounted && widget.question == null) setState(() => _shown = null);
  }

  @override
  void dispose() {
    _backdrop.dispose();
    _card.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final question = _shown;
    if (question == null) return const SizedBox.shrink();
    final leaving = widget.question == null;

    final backdrop = CurvedAnimation(
      parent: _backdrop,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    // The card overshoots its place a little and settles, the way something
    // set down does; on the way out it simply goes.
    final settle = CurvedAnimation(
      parent: _card,
      curve: const Interval(0, 0.85, curve: Curves.easeOutBack),
      reverseCurve: Curves.easeInCubic,
    );
    final appear = CurvedAnimation(
      parent: _card,
      curve: const Interval(0, 0.5, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    );

    return Positioned.fill(
      child: Stack(
        children: [
          // Everything behind, blurred back and dimmed. The barrier swallows
          // taps so a stray one on the drawing underneath cannot edit a
          // design the user cannot presently see clearly.
          Positioned.fill(
            child: AnimatedBuilder(
              animation: backdrop,
              builder: (context, _) {
                final t = backdrop.value.clamp(0.0, 1.0);
                return BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 7 * t, sigmaY: 7 * t),
                  child: ModalBarrier(
                    dismissible: false,
                    color: context.palette.shadow.withValues(alpha: 0.3 * t),
                  ),
                );
              },
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: IgnorePointer(
                // Once answered, the card on its way out is not answerable
                // again.
                ignoring: leaving,
                child: FadeTransition(
                  opacity: appear,
                  child: AnimatedBuilder(
                    animation: settle,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(0, 28 * (1 - settle.value)),
                      child: Transform.scale(
                        scale: 0.9 + 0.1 * settle.value,
                        child: child,
                      ),
                    ),
                    child: _Entrance(
                      animation: _card,
                      child: KeyedSubtree(
                        key: ValueKey(question.id),
                        child: widget.cardFor(question),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The card's own clock, for its parts to arrive by.
class _Entrance extends InheritedWidget {
  final Animation<double> animation;

  const _Entrance({required this.animation, required super.child});

  @override
  bool updateShouldNotify(_Entrance old) => old.animation != animation;
}

/// One part of an alert card, arriving [order]-th: a little after the card
/// itself, and a little after the part before it.
///
/// Outside an [AlertLayer] it is simply its child.
class AlertStep extends StatelessWidget {
  final int order;
  final Widget child;

  const AlertStep({super.key, required this.order, required this.child});

  @override
  Widget build(BuildContext context) {
    final clock = context
        .dependOnInheritedWidgetOfExactType<_Entrance>()
        ?.animation;
    if (clock == null) return child;
    final start = (0.18 + order * 0.09).clamp(0.0, 0.7);
    final arrive = CurvedAnimation(
      parent: clock,
      curve: Interval(
        start,
        (start + 0.4).clamp(0.0, 1.0),
        curve: Curves.easeOutCubic,
      ),
      // Leaving, the card goes as one piece.
      reverseCurve: const Threshold(0),
    );
    return FadeTransition(
      opacity: arrive,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.35),
          end: Offset.zero,
        ).animate(arrive),
        child: child,
      ),
    );
  }
}

/// The icon at the head of an alert card, popping into its badge with a
/// small turn as the card arrives.
class AlertBadge extends StatelessWidget {
  final IconData icon;

  const AlertBadge({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    final clock = context
        .dependOnInheritedWidgetOfExactType<_Entrance>()
        ?.animation;
    final badge = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF4C9), AppTheme.accent],
        ),
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: context.palette.selection.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, size: 20, color: AppTheme.primary),
    );
    if (clock == null) return badge;
    final pop = CurvedAnimation(
      parent: clock,
      curve: const Interval(0.12, 0.8, curve: Curves.elasticOut),
      reverseCurve: const Threshold(0),
    );
    return AnimatedBuilder(
      animation: pop,
      builder: (context, child) => Transform.rotate(
        angle: (1 - pop.value) * -0.5,
        child: Transform.scale(scale: pop.value, child: child),
      ),
      child: badge,
    );
  }
}

/// A button on an alert that answers to the pointer: it lifts a little under
/// it and gives a little when pressed, so it is plain which one is about to
/// be chosen.
class AlertPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final BorderRadius borderRadius;
  final Color color;
  final BorderSide side;

  const AlertPressable({
    super.key,
    required this.child,
    required this.onTap,
    required this.color,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.side = BorderSide.none,
  });

  @override
  State<AlertPressable> createState() => _AlertPressableState();
}

class _AlertPressableState extends State<AlertPressable> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final scale = _down ? 0.97 : (_hover ? 1.015 : 1.0);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            boxShadow: [
              BoxShadow(
                color: context.palette.shadow.withValues(
                  alpha: _hover ? 0.16 : 0.0,
                ),
                blurRadius: _hover ? 14 : 0,
                offset: Offset(0, _hover ? 5 : 0),
              ),
            ],
          ),
          child: Material(
            color: widget.color,
            shape: RoundedRectangleBorder(
              borderRadius: widget.borderRadius,
              side: widget.side,
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              onHighlightChanged: (down) => setState(() => _down = down),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
