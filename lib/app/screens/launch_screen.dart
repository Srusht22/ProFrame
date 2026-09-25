import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// What the workshop is called — exactly as written, in Sorani Kurdish,
/// right to left. It is set in text, never drawn as a picture, so it is
/// shaped by the typeface like any other text and stays the workshop's own
/// words.
const brandName = 'کارگەی وەستا سۆران شارباژێڕی';

/// The name as it is set on the launch: three lines, one above another,
/// read top to bottom as the name is read — the workshop, the master's
/// name, and where he is from.
///
/// **Only broken where the name already breaks.** Each line is whole words
/// in their own order, so joined with the spaces between them the lines are
/// [brandName] exactly; nothing is split inside a word, reordered or left
/// out.
const brandLines = ['کارگەی', 'وەستا سۆران', 'شارباژێڕی'];

/// The typeface the name is set in: a geometric Kufi, bundled with the app
/// in three weights, with every letter of Sorani Kurdish the name uses.
const brandFontFamily = 'Noto Kufi Arabic';

/// The workshop's mark, played once as the app opens, and then the home
/// screen.
///
/// One emblem, three things the workshop makes and fits, sharing one frame:
/// a hinged door down the left, a framed window above on the right, and a
/// sliding panel below it. They come together, each shows how it works —
/// the door turns on its hinge, the sliding panel runs along its track, the
/// window's sash tilts open at the top and shuts, then its glass catches
/// the light — and then the name comes in under them, composed in three
/// lines. It is all painted from lines, like everything else in the app.
///
/// **Once.** It is the first screen and replaces itself with the home
/// screen when it is done, so nothing navigates back to it and a rebuild
/// does not start it again. A device that has asked for less motion gets
/// the finished mark and the name faded in gently, and then the home
/// screen.
class LaunchScreen extends StatefulWidget {
  /// The screen to go on to.
  final WidgetBuilder next;

  const LaunchScreen({super.key, required this.next});

  /// How long the whole launch takes. Every part of it is a share of this,
  /// so changing it here changes the pace of all of it together.
  static const duration = Duration(milliseconds: 4000);

  /// How long the gentle version takes, for a device asking for less
  /// motion.
  static const reducedDuration = Duration(milliseconds: 900);

  /// How long the hand-over to the home screen takes.
  static const handOver = Duration(milliseconds: 450);

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

/// The parts of the launch, each as a share of [LaunchScreen.duration].
abstract final class LaunchTiming {
  /// The background, calm, coming up.
  static const background = Interval(0, 0.125, curve: Curves.easeOut);

  /// The frame drawing itself, and the three pieces coming into it.
  static const frame = Interval(0.125, 0.29, curve: Curves.easeInOutCubic);
  static const door = Interval(0.175, 0.33, curve: Curves.easeOutCubic);
  static const window = Interval(0.2, 0.355, curve: Curves.easeOutCubic);
  static const sliding = Interval(0.225, 0.375, curve: Curves.easeOutCubic);

  /// Each piece showing how it works.
  static const working = Interval(0.375, 0.625);

  /// The name coming in under the mark, a line at a time: the fine rules
  /// and the first word, the master's name wiping in from the right as it
  /// is read, and the last line settling under it.
  static const rules = Interval(0.6, 0.74, curve: Curves.easeOutCubic);
  static const firstLine = Interval(0.61, 0.72, curve: Curves.easeOut);
  static const mainLine = Interval(0.64, 0.8, curve: Curves.easeInOutCubic);
  static const lastLine = Interval(0.7, 0.82, curve: Curves.easeOutCubic);
}

class _LaunchScreenState extends State<LaunchScreen>
    with SingleTickerProviderStateMixin {
  // Preserved: this screen makes its own gentle version for a device asking
  // for less motion, and it has to last long enough for the name to be
  // read. Left to the controller, that request squeezes it to a flicker.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );
  bool _started = false;
  bool _left = false;

  bool get _gentle => MediaQuery.of(context).disableAnimations;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _clock.duration = _gentle
        ? LaunchScreen.reducedDuration
        : LaunchScreen.duration;
    _clock.forward().whenComplete(_goOn);
  }

  void _goOn() {
    if (!mounted || _left) return;
    _left = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: _gentle ? Duration.zero : LaunchScreen.handOver,
        pageBuilder: (context, _, _) => widget.next(context),
        transitionsBuilder: (context, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.ink,
    body: AnimatedBuilder(
      animation: _clock,
      builder: (context, _) {
        final t = _clock.value;
        // The gentle version is the finished mark faded in: nothing
        // moves, only the light comes up.
        final gentle = _gentle;
        double at(Interval part) =>
            gentle ? t : part.transform(t.clamp(0.0, 1.0));
        final background = gentle ? 1.0 : at(LaunchTiming.background);
        final working = gentle
            ? 1.0
            : LaunchTiming.working.transform(t.clamp(0.0, 1.0));

        return LayoutBuilder(
          builder: (context, box) {
            final shortest = math.min(box.maxWidth, box.maxHeight);
            // Sized from the screen, so it sits well clear of the edges on
            // a narrow phone and does not sprawl on a wide one.
            final mark = math.min(shortest * 0.46, 240.0);
            double part(Interval of) => gentle ? t : at(of);
            final name = _BrandName(
              size: (mark * 0.2).clamp(24.0, 46.0),
              rules: part(LaunchTiming.rules),
              first: part(LaunchTiming.firstLine),
              main: part(LaunchTiming.mainLine),
              last: part(LaunchTiming.lastLine),
            );

            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.1,
                  colors: [
                    Color.lerp(AppTheme.ink, _lift, background)!,
                    Color.lerp(AppTheme.ink, AppTheme.primary, background)!,
                  ],
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Opacity(
                          opacity: gentle ? t : 1,
                          child: SizedBox.square(
                            dimension: mark,
                            child: CustomPaint(
                              painter: LaunchEmblemPainter(
                                frame: gentle ? 1 : at(LaunchTiming.frame),
                                door: gentle ? 1 : at(LaunchTiming.door),
                                window: gentle ? 1 : at(LaunchTiming.window),
                                sliding: gentle ? 1 : at(LaunchTiming.sliding),
                                working: working,
                                gentle: gentle,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: mark * 0.14),
                        FittedBox(fit: BoxFit.scaleDown, child: name),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  );

  /// The centre of the background, a shade lighter than the brand's green
  /// so the mark sits in a little light rather than on a flat field.
  static final _lift = Color.lerp(AppTheme.primary, AppTheme.accent, 0.08)!;
}

/// The workshop's name as a composed mark rather than a line of text.
///
/// ```
///        ── کارگەی ──          small, gold, between two fine rules
///        وەستا سۆران           large and heavy: the name people say
///         شارباژێڕی            lighter, beneath it
/// ```
///
/// One family in three weights, so the lines belong together and the
/// contrast between them is the only ornament. Every line is set right to
/// left and shaped by the typeface; nothing is letter-spaced, because
/// spacing the letters of a joined script pulls them apart.
class _BrandName extends StatelessWidget {
  /// How big the master's name is; the other lines are set from it.
  final double size;

  /// How far each part has come in, 0 to 1.
  final double rules;
  final double first;
  final double main;
  final double last;

  const _BrandName({
    required this.size,
    required this.rules,
    required this.first,
    required this.main,
    required this.last,
  });

  static final _gold = Color.lerp(AppTheme.selection, AppTheme.accent, 0.35)!;

  TextStyle _style(double fontSize, FontWeight weight, Color colour) =>
      TextStyle(
        fontFamily: brandFontFamily,
        fontSize: fontSize,
        fontWeight: weight,
        height: 1.35,
        color: colour,
      );

  @override
  Widget build(BuildContext context) {
    final rule = size * 1.5;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The first word, between two fine rules that draw out from it.
        Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.rtl,
          children: [
            _Rule(length: rule, shown: rules, towardsRight: true),
            SizedBox(width: size * 0.35),
            Opacity(
              opacity: first,
              child: Text(
                brandLines[0],
                textDirection: TextDirection.rtl,
                style: _style(size * 0.46, FontWeight.w500, _gold),
              ),
            ),
            SizedBox(width: size * 0.35),
            _Rule(length: rule, shown: rules, towardsRight: false),
          ],
        ),
        // The master's name, wiping in from the right, the way it is read.
        ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) {
            final edge = (1 - main) * 1.25 - 0.25;
            return LinearGradient(
              colors: const [Colors.transparent, Colors.white],
              stops: [edge.clamp(0.0, 1.0), (edge + 0.25).clamp(0.0, 1.0)],
            ).createShader(bounds);
          },
          child: Text(
            brandLines[1],
            textDirection: TextDirection.rtl,
            style: _style(size, FontWeight.w800, AppTheme.accent),
          ),
        ),
        // Where he is from, settling in beneath.
        Opacity(
          opacity: last,
          child: Transform.translate(
            offset: Offset(0, size * 0.25 * (1 - last)),
            child: Text(
              brandLines[2],
              textDirection: TextDirection.rtl,
              style: _style(
                size * 0.6,
                FontWeight.w300,
                AppTheme.accent.withValues(alpha: 0.9),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A fine gold rule beside the first word, drawing out away from it and
/// fading at its far end.
class _Rule extends StatelessWidget {
  final double length;
  final double shown;
  final bool towardsRight;

  const _Rule({
    required this.length,
    required this.shown,
    required this.towardsRight,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: length,
    height: 2,
    child: Align(
      alignment: towardsRight ? Alignment.centerLeft : Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: shown,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: towardsRight
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              end: towardsRight ? Alignment.centerRight : Alignment.centerLeft,
              colors: [_BrandName._gold, _BrandName._gold.withValues(alpha: 0)],
            ),
          ),
          child: const SizedBox(height: 1.4),
        ),
      ),
    ),
  );
}

/// Where the moving parts of the emblem are, as the parts of the launch
/// play. Pure geometry, so the motion can be held to being physically right:
/// the door turns about its hinge and the sliding panel only runs along its
/// track.
abstract final class LaunchMotion {
  /// How far the door opens at its widest, and where it comes to rest.
  static const doorWidest = 38 * math.pi / 180;
  static const doorResting = 16 * math.pi / 180;

  /// How far the door is turned, [t] of the way through the working part.
  static double doorAngle(double t) {
    if (t <= 0) return 0;
    if (t < 0.45) {
      return doorWidest * Curves.easeInOutCubic.transform(t / 0.45);
    }
    final back = Curves.easeInOutCubic.transform(
      ((t - 0.45) / 0.55).clamp(0, 1),
    );
    return doorWidest + (doorResting - doorWidest) * back;
  }

  /// The door leaf turned by [angle] about its hinge edge at [hingeX],
  /// between [top] and [bottom], [width] wide — seen in perspective from
  /// [viewer] away, opening away from the viewer as a door opens into the
  /// room. The hinge edge never moves; the free edge comes round towards
  /// the hinge and, going away, looks shorter.
  static List<Offset> doorLeaf({
    required double hingeX,
    required double top,
    required double bottom,
    required double width,
    required double angle,
    required double viewer,
  }) {
    final across = width * math.cos(angle);
    final away = width * math.sin(angle);
    final shrink = viewer / (viewer + away);
    final middle = (top + bottom) / 2;
    final half = (bottom - top) / 2 * shrink;
    final free = hingeX + across * shrink;
    return [
      Offset(hingeX, top),
      Offset(free, middle - half),
      Offset(free, middle + half),
      Offset(hingeX, bottom),
    ];
  }

  /// How far along its track the sliding panel comes to rest, as a share
  /// of the whole run: past half, so the finished mark still shows two
  /// panels overlapping — which is what says *sliding* — and no empty slot.
  static const slideResting = 0.55;

  /// How far the sliding panel has run along its track, as a share of the
  /// distance it could run, [t] of the way through the working part. One
  /// way only, easing to a stop: it settles, it does not bounce back.
  static double slide(double t) =>
      slideResting *
      Curves.easeInOutCubic.transform(((t - 0.1) / 0.8).clamp(0.0, 1.0));

  /// How far the window's sash tips in at its widest.
  static const windowWidest = 24 * math.pi / 180;

  /// How far the window's sash is tipped in, [t] of the way through the
  /// working part: it tilts open at the top and closes again.
  static double windowTilt(double t) {
    if (t < 0.05) return 0;
    if (t < 0.4) {
      return windowWidest * Curves.easeInOutCubic.transform((t - 0.05) / 0.35);
    }
    final back = Curves.easeInOutCubic.transform(
      ((t - 0.4) / 0.35).clamp(0, 1),
    );
    return windowWidest * (1 - back);
  }

  /// The window's sash tipped in by [angle] about its bottom edge — the way
  /// a tilting sash opens — seen in perspective from [viewer] away. The
  /// bottom edge never moves; the top comes away into the room, so it
  /// drops and looks narrower. Corners: top left, top right, bottom right,
  /// bottom left.
  static List<Offset> windowSash(Rect sash, double angle, double viewer) {
    final height = sash.height;
    final away = height * math.sin(angle);
    final shrink = viewer / (viewer + away);
    final top = sash.bottom - height * math.cos(angle) * shrink;
    final half = sash.width / 2 * shrink;
    final middle = sash.center.dx;
    return [
      Offset(middle - half, top),
      Offset(middle + half, top),
      sash.bottomRight,
      sash.bottomLeft,
    ];
  }

  /// Where the light is across the window's glass, from before its near
  /// edge (below 0) to past its far one (above 1). It passes once the sash
  /// has shut again.
  static double sweep(double t) =>
      -0.4 +
      1.8 * Curves.easeInOut.transform(((t - 0.62) / 0.36).clamp(0.0, 1.0));
}

/// The emblem: one frame holding a hinged door, a framed window and a
/// sliding panel, drawn in lines of one weight.
///
/// Drawn in a 200 × 200 square and scaled to the size it is given, so it is
/// the same mark on every screen.
class LaunchEmblemPainter extends CustomPainter {
  /// How far each part has come in, 0 to 1.
  final double frame;
  final double door;
  final double window;
  final double sliding;

  /// How far through showing how they work, 0 to 1.
  final double working;

  /// The still version: everything in place, nothing moving.
  final bool gentle;

  const LaunchEmblemPainter({
    required this.frame,
    required this.door,
    required this.window,
    required this.sliding,
    required this.working,
    this.gentle = false,
  });

  /// The one weight every line of the mark is drawn in.
  static const stroke = 5.0;

  // The layout, in the 200 × 200 square: one outer frame, a jamb between
  // the door and the rest, and a transom between the window and the slider.
  static const outer = Rect.fromLTRB(20, 20, 180, 180);
  static const jambX = 88.0;
  static const transomY = 92.0;
  static const gap = 7.0;

  static const doorBay = Rect.fromLTRB(
    20 + gap,
    20 + gap,
    jambX - gap,
    180 - gap,
  );
  static const windowBay = Rect.fromLTRB(
    jambX + gap,
    20 + gap,
    180 - gap,
    transomY - gap,
  );
  static const slidingBay = Rect.fromLTRB(
    jambX + gap,
    transomY + gap,
    180 - gap,
    180 - gap,
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 200, size.height / 200);

    final line = Paint()
      ..color = AppTheme.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final glass = Paint()..color = AppTheme.accent.withValues(alpha: 0.1);

    _frame(canvas, line);
    _door(canvas, line, glass);
    _window(canvas, line, glass);
    _sliding(canvas, line, glass);

    canvas.restore();
  }

  /// The frame and its two members, drawn in as by a pen.
  void _frame(Canvas canvas, Paint line) {
    if (frame <= 0) return;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(outer, const Radius.circular(6)))
      ..moveTo(jambX, outer.top)
      ..lineTo(jambX, outer.bottom)
      ..moveTo(jambX, transomY)
      ..lineTo(outer.right, transomY);
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * frame), line);
    }
  }

  /// The door: the opening behind it, and the leaf turning on its hinge.
  void _door(Canvas canvas, Paint line, Paint glass) {
    if (door <= 0) return;
    final shift = Offset(-18 * (1 - door), 0);
    final fade = door;
    final bay = doorBay.shift(shift);

    // The way through, dark, seen as the leaf comes away from it.
    final angle = gentle
        ? LaunchMotion.doorResting
        : LaunchMotion.doorAngle(working);
    canvas.drawRect(
      bay,
      Paint()..color = AppTheme.ink.withValues(alpha: 0.55 * fade),
    );

    final leaf = LaunchMotion.doorLeaf(
      hingeX: bay.left,
      top: bay.top,
      bottom: bay.bottom,
      width: bay.width,
      angle: angle,
      viewer: 260,
    );
    final shape = Path()..addPolygon(leaf, true);
    // The leaf's face darkens a little as it turns from the light.
    final lit = 0.1 + 0.08 * math.cos(angle);
    canvas.drawPath(
      shape,
      Paint()..color = AppTheme.accent.withValues(alpha: lit * fade),
    );
    canvas.drawPath(shape, _faded(line, fade));

    // The handle, on the free edge, half way up, going where the edge goes.
    final free = leaf[1].dx;
    final middle = (leaf[1].dy + leaf[2].dy) / 2;
    final reach = (leaf[2].dy - leaf[1].dy) * 0.07;
    canvas.drawLine(
      Offset(free - 7 * math.cos(angle), middle - reach),
      Offset(free - 7 * math.cos(angle), middle + reach),
      _faded(line, fade),
    );
  }

  /// The window: a sash of four panes that tilts open at the top and
  /// shuts again, and then catches the light.
  void _window(Canvas canvas, Paint line, Paint glass) {
    if (window <= 0) return;
    final bay = windowBay.shift(Offset(0, -18 * (1 - window)));
    final fade = window;
    final angle = gentle ? 0.0 : LaunchMotion.windowTilt(working);

    // The opening behind, seen as the sash tips away from it.
    canvas.drawRect(
      bay,
      Paint()..color = AppTheme.ink.withValues(alpha: 0.55 * fade),
    );

    final corners = LaunchMotion.windowSash(bay, angle, 260);
    // A point on the sash, [u] across and [v] down it, wherever it has
    // tipped to — so the bars go with the glass.
    Offset on(double u, double v) {
      final top = Offset.lerp(corners[0], corners[1], u)!;
      final bottom = Offset.lerp(corners[3], corners[2], u)!;
      return Offset.lerp(top, bottom, v)!;
    }

    final sash = Path()..addPolygon(corners, true);
    canvas.drawPath(
      sash,
      Paint()
        ..color = AppTheme.accent.withValues(
          alpha: (0.1 + 0.06 * math.cos(angle * 3)) * fade,
        ),
    );

    // The light, a soft band crossing the glass once, kept to the glass.
    final sweep = gentle ? -1.0 : LaunchMotion.sweep(working);
    if (sweep > -0.4 && sweep < 1.4) {
      canvas.save();
      canvas.clipPath(sash);
      final x = bay.left + bay.width * sweep;
      canvas.drawRect(
        bay,
        Paint()
          ..shader = LinearGradient(
            colors: [
              AppTheme.selection.withValues(alpha: 0),
              AppTheme.accent.withValues(alpha: 0.5 * fade),
              AppTheme.selection.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromLTRB(x - 24, bay.top, x + 24, bay.bottom)),
      );
      canvas.restore();
    }

    // The glazing bars: a cross, lighter than the frame, dividing the sash
    // into four panes.
    final bars = _faded(line, fade)..strokeWidth = stroke * 0.6;
    canvas.drawLine(on(0.5, 0), on(0.5, 1), bars);
    canvas.drawLine(on(0, 0.5), on(1, 0.5), bars);
    canvas.drawPath(sash, _faded(line, fade));
  }

  /// The sliding panel: a fixed pane behind, and the panel in front running
  /// along the track beneath them.
  void _sliding(Canvas canvas, Paint line, Paint glass) {
    if (sliding <= 0) return;
    final bay = slidingBay.shift(Offset(18 * (1 - sliding), 0));
    final fade = sliding;
    final panelWidth = bay.width * 0.58;

    // The track it runs on.
    canvas.drawLine(
      Offset(bay.left, bay.bottom + gap / 2),
      Offset(bay.right, bay.bottom + gap / 2),
      _faded(line..strokeWidth = stroke * 0.6, fade),
    );
    line.strokeWidth = stroke;

    // The fixed pane, on the left.
    final fixed = Rect.fromLTWH(bay.left, bay.top, panelWidth, bay.height - 4);
    canvas.drawRect(fixed, _faded(glass, fade));
    canvas.drawRect(fixed, _faded(line, fade * 0.7));

    // The panel that slides: across the right of the bay at rest, running
    // left along the track over the fixed pane. It only moves along.
    final runs = bay.width - panelWidth;
    final along =
        (gentle ? LaunchMotion.slideResting : LaunchMotion.slide(working)) *
        runs;
    final panel = Rect.fromLTWH(
      bay.right - panelWidth - along,
      bay.top,
      panelWidth,
      bay.height - 4,
    );
    canvas.drawRect(
      panel,
      Paint()..color = AppTheme.accent.withValues(alpha: 0.16 * fade),
    );
    canvas.drawRect(panel, _faded(line, fade));
    // Its pull, on the stile it closes with.
    final pullX = panel.right - 7;
    canvas.drawLine(
      Offset(pullX, panel.center.dy - panel.height * 0.14),
      Offset(pullX, panel.center.dy + panel.height * 0.14),
      _faded(line, fade),
    );
  }

  static Paint _faded(Paint paint, double by) => Paint()
    ..color = paint.color.withValues(alpha: paint.color.a * by)
    ..style = paint.style
    ..strokeWidth = paint.strokeWidth
    ..strokeCap = paint.strokeCap
    ..strokeJoin = paint.strokeJoin;

  @override
  bool shouldRepaint(LaunchEmblemPainter old) =>
      old.frame != frame ||
      old.door != door ||
      old.window != window ||
      old.sliding != sliding ||
      old.working != working ||
      old.gentle != gentle;
}
