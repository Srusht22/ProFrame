import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/design.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';
import 'workspace_screen.dart';

/// Where a new design begins: say what you are drawing — a door, a window,
/// a frame holding both, or a sliding set — and draw.
///
/// It is reached from **New Design** on the designs screen, which has
/// already asked who the design is for and what it is called; [customer]
/// and [name] are those answers, and the design is begun with them.
///
/// **Each card shows the application doing what it does**, not a picture of
/// a door: a pen draws the outline, then the bars, then the mark that says a
/// leaf opens. It is painted from lines like everything else on the screen,
/// because nothing here is ever a picture (`no_stock_content_test.dart`).
///
/// Every movement on this screen finishes. The cards arrive once, in turn,
/// and a card draws itself again only when the pointer comes onto it; nothing
/// loops, so the screen is still while the user is reading it — and a test,
/// or anybody who has asked their device for less motion, sees it settled.
class StartScreen extends ConsumerStatefulWidget {
  /// Who the new design is for, where the user said.
  final String? customer;

  /// What the new design is called, where the user said.
  final String? name;

  const StartScreen({super.key, this.customer, this.name});

  @override
  ConsumerState<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends ConsumerState<StartScreen>
    with SingleTickerProviderStateMixin {
  /// The arrival of the whole screen: the heading, then each card in turn.
  late final AnimationController _arrival = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_arrival.isAnimating || _arrival.isCompleted) return;
    if (MediaQuery.of(context).disableAnimations) {
      _arrival.value = 1;
    } else {
      _arrival.forward();
    }
  }

  @override
  void dispose() {
    _arrival.dispose();
    super.dispose();
  }

  /// A piece of the screen arriving over its own share of [_arrival]: it
  /// fades in and rises a little, starting at [from] of the way through.
  Widget _arriving(double from, Widget child) {
    final curve = CurvedAnimation(
      parent: _arrival,
      curve: Interval(
        from,
        math.min(1, from + 0.45),
        curve: Curves.easeOutCubic,
      ),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }

  void _begin(DesignKind kind) {
    final controller = ref.read(workspaceProvider.notifier)
      ..startDesign(kind, name: widget.name, customer: widget.customer);
    // Kept straight away, so it is among the recent designs from the moment
    // it exists, not only once something has been drawn.
    unawaited(controller.keep());
    // Into the design with the designs screen underneath it, so the way back
    // is to the list the design is now in — not through the steps that
    // began it.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const WorkspaceScreen()),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const kinds = [
      (
        DesignKind.door,
        'Any shape, any number of panels, hinged wherever you draw it.',
      ),
      (
        DesignKind.window,
        'Any outline, any arrangement of bars, opening wherever you mark it.',
      ),
      (
        DesignKind.both,
        'One frame holding leaves of each kind. You say which every '
            'opening is.',
      ),
      (
        DesignKind.sliding,
        'Panels that slide past each other. Mark each one that slides with '
            'the way it goes.',
      ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Stack(
        children: [
          // Drafting paper, faintly, behind everything: this is a place
          // where things are drawn.
          const Positioned.fill(child: CustomPaint(painter: _Paper())),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 40,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _arriving(0, _Heading(theme: theme)),
                      const SizedBox(height: 36),
                      _arriving(
                        0.1,
                        Text(
                          'CREATE DESIGN',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppTheme.accent.withValues(alpha: 0.7),
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final narrow = constraints.maxWidth < 720;
                          // Four across where there is room for four, and
                          // two by two where there is not.
                          final twoByTwo = constraints.maxWidth < 900;
                          final cards = [
                            for (var i = 0; i < kinds.length; i++)
                              _arriving(
                                0.18 + i * 0.12,
                                _KindCard(
                                  kind: kinds[i].$1,
                                  blurb: kinds[i].$2,
                                  // Each pen starts as its card arrives.
                                  delay: Duration(milliseconds: 250 + i * 140),
                                  onTap: () => _begin(kinds[i].$1),
                                ),
                              ),
                          ];
                          if (narrow) {
                            return Column(
                              children: [
                                for (final card in cards) ...[
                                  card,
                                  if (card != cards.last)
                                    const SizedBox(height: 14),
                                ],
                              ],
                            );
                          }
                          Widget row(List<Widget> cards) => IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final card in cards) ...[
                                  Expanded(child: card),
                                  if (card != cards.last)
                                    const SizedBox(width: 16),
                                ],
                              ],
                            ),
                          );
                          if (twoByTwo) {
                            return Column(
                              children: [
                                row(cards.sublist(0, 2)),
                                const SizedBox(height: 16),
                                row(cards.sublist(2)),
                              ],
                            );
                          }
                          return row(cards);
                        },
                      ),
                      const SizedBox(height: 32),
                      _arriving(
                        0.55,
                        Text(
                          'Nothing is designed for you. No templates, no '
                          'stock pictures, no assumptions about what a door '
                          'usually looks like. Where your drawing is unclear '
                          'you will be asked.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.accent.withValues(alpha: 0.62),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // The way back to the form that brought the user here.
          if (Navigator.of(context).canPop())
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back, color: AppTheme.accent),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The name, the promise, and the three steps it keeps.
class _Heading extends StatelessWidget {
  final ThemeData theme;
  const _Heading({required this.theme});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'ProFrame',
        style: theme.textTheme.displaySmall?.copyWith(
          color: AppTheme.accent,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      const SizedBox(height: 12),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Text(
          'Draw your door or window by hand. What you draw becomes the '
          'design — the exact shape, the exact divisions, the exact '
          'proportions — and the design becomes the model.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppTheme.accent.withValues(alpha: 0.86),
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final (i, step) in const [
            (Icons.gesture, 'Draw it'),
            (Icons.chevron_right, 'Mark what opens'),
            (Icons.view_in_ar_outlined, 'See it built'),
          ].indexed) ...[
            if (i > 0)
              Icon(
                Icons.arrow_forward,
                size: 14,
                color: AppTheme.accent.withValues(alpha: 0.45),
              ),
            _Step(icon: step.$1, label: step.$2),
          ],
        ],
      ),
    ],
  );
}

class _Step extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Step({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: AppTheme.accent.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.18)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppTheme.accent),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.accent,
          ),
        ),
      ],
    ),
  );
}

/// One thing to start from, drawn by a pen as it arrives.
class _KindCard extends StatefulWidget {
  final DesignKind kind;
  final String blurb;
  final Duration delay;
  final VoidCallback onTap;

  const _KindCard({
    required this.kind,
    required this.blurb,
    required this.delay,
    required this.onTap,
  });

  @override
  State<_KindCard> createState() => _KindCardState();
}

class _KindCardState extends State<_KindCard>
    with SingleTickerProviderStateMixin {
  static const _drawing = Duration(milliseconds: 1300);

  /// The wait and the drawing, as one run, so that nothing here is left
  /// waiting on a timer: the pen's progress is the part after the wait.
  late final AnimationController _pen = AnimationController(
    vsync: this,
    duration: widget.delay + _drawing,
  );

  late final Animation<double> _progress = CurvedAnimation(
    parent: _pen,
    curve: Interval(_waitFraction, 1, curve: Curves.easeInOutCubic),
  );

  double get _waitFraction =>
      widget.delay.inMicroseconds / (widget.delay + _drawing).inMicroseconds;

  bool _hovering = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pen.isAnimating || _pen.isCompleted) return;
    if (MediaQuery.of(context).disableAnimations) {
      _pen.value = 1;
    } else {
      _pen.forward();
    }
  }

  @override
  void dispose() {
    _pen.dispose();
    super.dispose();
  }

  void _hover(bool on) {
    setState(() => _hovering = on);
    // Coming onto a card draws it again, straight away.
    if (on && !MediaQuery.of(context).disableAnimations) {
      _pen.forward(from: _waitFraction);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => _hover(true),
      onExit: (_) => _hover(false),
      child: AnimatedSlide(
        offset: Offset(0, _hovering ? -0.015 : 0),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: AppTheme.accent,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _hovering ? AppTheme.selection : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hovering ? 0.32 : 0.18),
                blurRadius: _hovering ? 30 : 16,
                offset: Offset(0, _hovering ? 14 : 8),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                // Spaced rather than given a Spacer: side by side the cards
                // are one height and the call to action sits at the foot of
                // each; stacked, the height is unbounded and each card is
                // just as tall as it needs.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // The drawing, on its own bit of drafting paper.
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            height: 150,
                            width: double.infinity,
                            color: AppTheme.canvas,
                            child: AnimatedBuilder(
                              animation: _progress,
                              builder: (context, _) => CustomPaint(
                                painter: _PenDrawing(
                                  kind: widget.kind,
                                  progress: _progress.value,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.kind.label.toUpperCase(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.blurb,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.primary.withValues(alpha: 0.78),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Row(
                        children: [
                          // Four cards share the width, so the words give
                          // way to the arrow rather than run past the card.
                          Flexible(
                            child: Text(
                              'Start drawing',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          AnimatedPadding(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            padding: EdgeInsets.only(left: _hovering ? 10 : 6),
                            child: const Icon(
                              Icons.arrow_forward,
                              size: 17,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A door, a window, a frame holding both, or a sliding set, drawn by a pen
/// up to [progress] of the way: the outline, then the bars, then the mark in
/// gold.
class _PenDrawing extends CustomPainter {
  final DesignKind kind;
  final double progress;

  const _PenDrawing({required this.kind, required this.progress});

  /// Each drawing as the lines a hand would draw it in, in order, in a unit
  /// square. The last one or two are opening marks.
  static List<List<Offset>> _lines(DesignKind kind) => switch (kind) {
    DesignKind.door => const [
      [
        Offset(0.33, 0.9),
        Offset(0.33, 0.1),
        Offset(0.67, 0.1),
        Offset(0.67, 0.9),
      ],
      [Offset(0.33, 0.42), Offset(0.67, 0.42)],
      [Offset(0.38, 0.52), Offset(0.6, 0.66), Offset(0.38, 0.8)],
    ],
    DesignKind.window => const [
      [
        Offset(0.2, 0.14),
        Offset(0.8, 0.14),
        Offset(0.8, 0.86),
        Offset(0.2, 0.86),
        Offset(0.2, 0.14),
      ],
      [Offset(0.5, 0.14), Offset(0.5, 0.86)],
      [Offset(0.2, 0.42), Offset(0.8, 0.42)],
      [Offset(0.44, 0.52), Offset(0.28, 0.64), Offset(0.44, 0.76)],
    ],
    DesignKind.both => const [
      [
        Offset(0.12, 0.1),
        Offset(0.88, 0.1),
        Offset(0.88, 0.9),
        Offset(0.12, 0.9),
        Offset(0.12, 0.1),
      ],
      [Offset(0.44, 0.1), Offset(0.44, 0.9)],
      [Offset(0.44, 0.46), Offset(0.88, 0.46)],
      [Offset(0.18, 0.4), Offset(0.36, 0.52), Offset(0.18, 0.64)],
      [Offset(0.74, 0.18), Offset(0.56, 0.28), Offset(0.74, 0.38)],
    ],
    // A sliding door as the user's own reference shows one: the frame, the
    // fixed panel on the right, the left panel overlapping it with its long
    // pull on its left stile, and the way it slides — to the right,
    // uncovering the passage on the left — in gold.
    DesignKind.sliding => const [
      [
        Offset(0.08, 0.2),
        Offset(0.92, 0.2),
        Offset(0.92, 0.8),
        Offset(0.08, 0.8),
        Offset(0.08, 0.2),
      ],
      [
        Offset(0.47, 0.25),
        Offset(0.87, 0.25),
        Offset(0.87, 0.75),
        Offset(0.47, 0.75),
        Offset(0.47, 0.25),
      ],
      [
        Offset(0.13, 0.25),
        Offset(0.55, 0.25),
        Offset(0.55, 0.75),
        Offset(0.13, 0.75),
        Offset(0.13, 0.25),
      ],
      [Offset(0.18, 0.4), Offset(0.18, 0.6)],
      [Offset(0.25, 0.5), Offset(0.46, 0.5)],
      [Offset(0.39, 0.43), Offset(0.46, 0.5), Offset(0.39, 0.57)],
    ],
  };

  /// How many of the lines are marks rather than structure.
  static int _marks(DesignKind kind) => switch (kind) {
    // Two marks in one frame, or an arrow — a shaft and its head.
    DesignKind.both || DesignKind.sliding => 2,
    _ => 1,
  };

  @override
  void paint(Canvas canvas, Size size) {
    // Square, centred, so the drawing keeps its proportions whatever the
    // card's width.
    final side = math.min(size.width, size.height);
    final origin = Offset((size.width - side) / 2, (size.height - side) / 2);
    Offset at(Offset unit) => origin + unit * side;

    final lines = _lines(kind);
    final marks = _marks(kind);
    final paths = [
      for (final line in lines)
        Path()
          ..moveTo(at(line.first).dx, at(line.first).dy)
          ..addPolygon([for (final p in line) at(p)], false),
    ];
    final lengths = [
      for (final path in paths)
        path.computeMetrics().fold<double>(0, (sum, m) => sum + m.length),
    ];
    final total = lengths.fold<double>(0, (a, b) => a + b);

    final structure = Paint()
      ..color = AppTheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final mark = Paint()
      ..color = AppTheme.selection
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // The pen's reach along the whole drawing, line after line.
    var left = total * progress;
    Offset? nib;
    for (var i = 0; i < paths.length && left > 0; i++) {
      final paint = i >= paths.length - marks ? mark : structure;
      final take = math.min(left, lengths[i]);
      var along = take;
      for (final metric in paths[i].computeMetrics()) {
        if (along <= 0) break;
        final piece = math.min(along, metric.length);
        canvas.drawPath(metric.extractPath(0, piece), paint);
        nib = metric.getTangentForOffset(piece)?.position ?? nib;
        along -= piece;
      }
      left -= take;
    }

    // The nib, while it is still drawing.
    if (nib != null && progress < 1) {
      canvas.drawCircle(nib, 4.2, Paint()..color = AppTheme.selection);
      canvas.drawCircle(nib, 1.8, Paint()..color = AppTheme.accent);
    }
  }

  @override
  bool shouldRepaint(_PenDrawing old) =>
      old.progress != progress || old.kind != kind;
}

/// Faint drafting paper behind the start screen.
class _Paper extends CustomPainter {
  const _Paper();

  @override
  void paint(Canvas canvas, Size size) {
    const step = 28.0;
    final fine = Paint()
      ..color = AppTheme.accent.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    final bold = Paint()
      ..color = AppTheme.accent.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    var i = 0;
    for (var x = 0.0; x <= size.width; x += step, i++) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        i % 5 == 0 ? bold : fine,
      );
    }
    i = 0;
    for (var y = 0.0; y <= size.height; y += step, i++) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        i % 5 == 0 ? bold : fine,
      );
    }
  }

  @override
  bool shouldRepaint(_Paper old) => false;
}
