import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/design.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';
import 'workspace_screen.dart';

/// **Choose your design**: the one step between naming a new design and
/// drawing it — what kind of product it is.
///
/// Four choices, all alike — a door, a window, a frame holding both and a
/// sliding set — two by two where there is room and one above the other
/// on a phone. The user asked for all four and for them to be the same:
/// none is a lesser kind of design. A card is chosen by tapping it and
/// stays visibly chosen; **Start drawing** then begins the design and goes
/// into the drawing, exactly as it always has.
///
/// **The choice is where the design starts, not a fence round it.** It is
/// `Design.kind`, kept with the design, and every opening in it can still be
/// said to be a door or a window of its own — a door design can hold a
/// window leaf, and a window design a door.
///
/// It is reached from the new design's form, which has already asked who
/// the design is for; [customer] is that answer, and the design is called
/// by it. Opening a saved design never comes here: it goes straight into
/// the design as it was kept.
///
/// **Each card shows the application doing what it does**, not a picture of
/// a door: a pen draws the outline, then the bars, then the mark that says a
/// leaf opens, from lines like everything else on the screen
/// (`no_stock_content_test.dart`). Every movement finishes; nothing loops.
class StartScreen extends ConsumerStatefulWidget {
  /// Who the new design is for.
  final String? customer;

  const StartScreen({super.key, this.customer});

  /// The four choices, in the order they are shown, and what each card says.
  static const choices = [
    (DesignKind.door, 'Create a custom door design'),
    (DesignKind.window, 'Create a custom window design'),
    (DesignKind.both, 'Doors and windows in one frame'),
    (DesignKind.sliding, 'Panels that slide past each other'),
  ];

  /// What the button that begins the design says.
  static const startLabel = 'Start drawing';

  @override
  ConsumerState<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends ConsumerState<StartScreen>
    with SingleTickerProviderStateMixin {
  /// The kind chosen so far, or null while nothing is.
  DesignKind? _chosen;

  /// The arrival of the whole screen: the heading, then each card in turn.
  late final AnimationController _arrival = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
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
        math.min(1, from + 0.5),
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

  void _begin() {
    final kind = _chosen;
    if (kind == null) return;
    final controller = ref.read(workspaceProvider.notifier)
      ..startDesign(kind, name: widget.customer, customer: widget.customer);
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

  /// The four cards, every one the same size: one above another on a phone
  /// ([columns] 1), two by two on a tablet, and all four in a row on a
  /// screen wide enough to hold them, so the choice is one look.
  Widget _cards({required int columns}) {
    final cards = [
      for (final (i, (kind, blurb)) in StartScreen.choices.indexed)
        _arriving(
          0.1 + i * 0.07,
          _ChoiceCard(
            kind: kind,
            blurb: blurb,
            chosen: _chosen == kind,
            // Each pen starts as its card arrives.
            delay: Duration(milliseconds: 200 + i * 140),
            onTap: () => setState(() => _chosen = kind),
          ),
        ),
    ];
    if (columns == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final card in cards) ...[
            card,
            if (card != cards.last) const SizedBox(height: 14),
          ],
        ],
      );
    }
    Widget row(List<Widget> these) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final card in these) ...[
            Expanded(child: card),
            if (card != these.last) const SizedBox(width: 18),
          ],
        ],
      ),
    );
    return Column(
      children: [
        for (var i = 0; i < cards.length; i += columns) ...[
          if (i > 0) const SizedBox(height: 18),
          row(cards.sublist(i, i + columns)),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final forWhom = widget.customer ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('New Design')),
      body: LayoutBuilder(
        builder: (context, room) {
          final phone = room.maxWidth < 600;
          final gutter = phone ? 16.0 : 32.0;
          final columns = phone ? 1 : (room.maxWidth < 1000 ? 2 : 4);
          final across = columns == 4 ? 1180.0 : 880.0;
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(gutter, 28, gutter, 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: across),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _arriving(
                            0,
                            _Heading(forWhom: forWhom, phone: phone),
                          ),
                          SizedBox(height: phone ? 20 : 28),
                          _cards(columns: columns),
                          const SizedBox(height: 22),
                          _arriving(0.45, const _StillMixed()),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _StartBar(
                chosen: _chosen,
                phone: phone,
                gutter: gutter,
                across: across,
                onStart: _begin,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The title, what it asks, and who the design is for.
class _Heading extends StatelessWidget {
  final String forWhom;
  final bool phone;

  const _Heading({required this.forWhom, required this.phone});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (forWhom.isNotEmpty) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.person_outline,
                size: 15,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  forWhom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
      Text(
        'Choose your design',
        style: TextStyle(
          fontSize: phone ? 26 : 32,
          fontWeight: FontWeight.w700,
          height: 1.15,
          color: AppTheme.ink,
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'Select the type of product you want to create.',
        style: TextStyle(fontSize: 15, color: AppTheme.muted),
      ),
    ],
  );
}

/// That the choice is where the design starts, not all it can be.
class _StillMixed extends StatelessWidget {
  const _StillMixed();

  @override
  Widget build(BuildContext context) => const Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(Icons.info_outline, size: 17, color: AppTheme.muted),
      SizedBox(width: 8),
      Expanded(
        child: Text(
          'This is where the design starts, not a limit on it: any opening '
          'you mark can still be made a door or a window, and fixed areas '
          'sit beside them in the same frame.',
          style: TextStyle(fontSize: 13, height: 1.45, color: AppTheme.muted),
        ),
      ),
    ],
  );
}

/// The foot of the screen: what is chosen, and the way into the drawing.
/// It stays put while the cards scroll, so the button is always in reach.
class _StartBar extends StatelessWidget {
  final DesignKind? chosen;
  final bool phone;
  final double gutter;

  /// How wide the screen's content is, so the bar lines up with the cards.
  final double across;
  final VoidCallback onStart;

  const _StartBar({
    required this.chosen,
    required this.phone,
    required this.gutter,
    required this.across,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.icon(
      onPressed: chosen == null ? null : onStart,
      icon: const Icon(Icons.arrow_forward, size: 20),
      iconAlignment: IconAlignment.end,
      label: const Text(StartScreen.startLabel),
    );
    final said = Text(
      chosen == null
          ? 'Choose a type to continue'
          : '${chosen!.label} selected',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 14,
        fontWeight: chosen == null ? FontWeight.w500 : FontWeight.w700,
        color: chosen == null ? AppTheme.muted : AppTheme.primary,
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: const Border(top: BorderSide(color: AppTheme.hairline)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.ink.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 12),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: across),
              child: phone
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(child: said),
                        const SizedBox(height: 10),
                        button,
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: said),
                        const SizedBox(width: 16),
                        button,
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One thing to start from: its drawing, drawn by a pen as it arrives, its
/// name and what it is for. Every card is the same size and made the same
/// way. Chosen, it takes the brand's green edge, a tint and
/// a tick, so which one is chosen is plain from across the room.
class _ChoiceCard extends StatefulWidget {
  final DesignKind kind;
  final String blurb;
  final bool chosen;
  final Duration delay;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.kind,
    required this.blurb,
    required this.chosen,
    required this.delay,
    required this.onTap,
  });

  @override
  State<_ChoiceCard> createState() => _ChoiceCardState();
}

class _ChoiceCardState extends State<_ChoiceCard>
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

  bool get _still => MediaQuery.of(context).disableAnimations;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pen.isAnimating || _pen.isCompleted) return;
    if (_still) {
      _pen.value = 1;
    } else {
      _pen.forward();
    }
  }

  @override
  void didUpdateWidget(_ChoiceCard old) {
    super.didUpdateWidget(old);
    // Chosen, it draws itself once more: the choice answered in the card's
    // own terms.
    if (widget.chosen && !old.chosen && !_still) {
      _pen.forward(from: _waitFraction);
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
    if (on && !widget.chosen && !_still) _pen.forward(from: _waitFraction);
  }

  @override
  Widget build(BuildContext context) {
    final chosen = widget.chosen;
    final quick = _still ? Duration.zero : const Duration(milliseconds: 220);
    final drawing = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ColoredBox(
        color: AppTheme.canvas,
        child: AnimatedBuilder(
          animation: _progress,
          builder: (context, _) => CustomPaint(
            painter: _PenDrawing(kind: widget.kind, progress: _progress.value),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    final title = Text(
      widget.kind.label.toUpperCase(),
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: AppTheme.primary,
      ),
    );
    final blurb = Text(
      widget.blurb,
      style: TextStyle(fontSize: 14, height: 1.4, color: AppTheme.muted),
    );
    final tick = _Tick(chosen: chosen, duration: quick);

    final body = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SizedBox(height: 140, child: drawing),
              Positioned(top: 10, right: 10, child: tick),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: title,
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: blurb,
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      selected: chosen,
      label: widget.kind.label,
      child: MouseRegion(
        onEnter: (_) => _hover(true),
        onExit: (_) => _hover(false),
        child: AnimatedContainer(
          duration: quick,
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(
            0,
            _hovering && !chosen ? -3 : 0,
            0,
          ),
          decoration: BoxDecoration(
            color: chosen
                ? Color.alphaBlend(
                    AppTheme.primary.withValues(alpha: 0.05),
                    AppTheme.surface,
                  )
                : AppTheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: chosen
                  ? AppTheme.primary
                  : _hovering
                  ? AppTheme.primary.withValues(alpha: 0.35)
                  : AppTheme.hairline,
              // One width chosen or not, so choosing moves nothing.
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: chosen
                    ? AppTheme.primary.withValues(alpha: 0.18)
                    : AppTheme.ink.withValues(alpha: _hovering ? 0.1 : 0.04),
                blurRadius: chosen || _hovering ? 22 : 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: widget.onTap,
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

/// The tick on a card: an empty ring until it is chosen, then the brand's
/// green with the accent's tick in it, popping in as it is.
class _Tick extends StatelessWidget {
  final bool chosen;
  final Duration duration;

  const _Tick({required this.chosen, required this.duration});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: duration,
    curve: Curves.easeOutBack,
    width: 26,
    height: 26,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: chosen ? AppTheme.primary : AppTheme.surface,
      border: Border.all(
        color: chosen ? AppTheme.primary : AppTheme.hairline,
        width: 1.6,
      ),
    ),
    child: AnimatedScale(
      scale: chosen ? 1 : 0,
      duration: duration,
      curve: Curves.easeOutBack,
      child: const Icon(Icons.check, size: 16, color: AppTheme.accent),
    ),
  );
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
