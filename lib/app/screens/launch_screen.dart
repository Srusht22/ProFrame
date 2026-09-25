import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// What the workshop is called — exactly as written, in Sorani Kurdish,
/// right to left. It is set in text, never drawn as a picture, so it is
/// shaped by the typeface like any other text and stays the workshop's own
/// words.
const brandName = 'کارگەی وەستا سۆران شارباژێڕی';

/// The typeface the name is set in: bundled with the app, and covering
/// every letter of Sorani Kurdish the name uses.
const brandFontFamily = 'Noto Sans Arabic';

/// The workshop's mark, played once as the app opens, and then the home
/// screen.
///
/// One emblem, three things the workshop makes and fits, sharing one frame:
/// a hinged door down the left, a framed window above on the right, and a
/// sliding panel below it. They come together, each shows how it works —
/// the door turns on its hinge, the sliding panel runs along its track, the
/// window's glass catches the light — and then the name comes in under
/// them. It is all painted from lines, like everything else in the app.
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

  /// The name coming in under the mark.
  static const name = Interval(0.625, 0.8, curve: Curves.easeOutCubic);
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
            final nameSize = (mark * 0.13).clamp(17.0, 30.0);
            final name = gentle ? t : at(LaunchTiming.name);

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
                        SizedBox(height: mark * 0.16),
                        Opacity(
                          opacity: name,
                          child: Transform.translate(
                            offset: Offset(0, 10 * (1 - name)),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                brandName,
                                textDirection: TextDirection.rtl,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                style: TextStyle(
                                  fontFamily: brandFontFamily,
                                  fontWeight: FontWeight.w700,
                                  fontSize: nameSize,
                                  height: 1.4,
                                  color: AppTheme.accent,
                                ),
                              ),
                            ),
                          ),
                        ),
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

  /// Where the light is across the window's glass, from before its near
  /// edge (below 0) to past its far one (above 1).
  static double sweep(double t) =>
      -0.4 +
      1.8 * Curves.easeInOut.transform(((t - 0.15) / 0.7).clamp(0.0, 1.0));
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

  /// The window: its own frame, a bar across the glass, and the light
  /// passing over the glass.
  void _window(Canvas canvas, Paint line, Paint glass) {
    if (window <= 0) return;
    final bay = windowBay.shift(Offset(0, -18 * (1 - window)));
    final fade = window;
    canvas.drawRect(bay, _faded(glass, fade));

    // The light, a soft band crossing the glass once, kept to the glass.
    final sweep = gentle ? -1.0 : LaunchMotion.sweep(working);
    if (sweep > -0.4 && sweep < 1.4) {
      canvas.save();
      canvas.clipRect(bay);
      final x = bay.left + bay.width * sweep;
      canvas.drawRect(
        bay,
        Paint()
          ..shader = LinearGradient(
            colors: [
              AppTheme.selection.withValues(alpha: 0),
              AppTheme.accent.withValues(alpha: 0.42 * fade),
              AppTheme.selection.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromLTRB(x - 26, bay.top, x + 26, bay.bottom)),
      );
      canvas.restore();
    }

    canvas.drawRect(bay, _faded(line, fade));
    final middle = bay.center.dx;
    canvas.drawLine(
      Offset(middle, bay.top),
      Offset(middle, bay.bottom),
      _faded(line, fade),
    );
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
