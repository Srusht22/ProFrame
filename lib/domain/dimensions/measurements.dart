import 'dart:math' as math;

import '../editing/design_edits.dart';
import '../geometry/polygon.dart';
import '../geometry/vec2.dart';
import '../model/design.dart';
import '../model/elements.dart';
import '../sections/section_builder.dart';
import '../sketch/stroke.dart';
import 'units.dart';

/// Which way a size runs.
enum MeasureAxis {
  across,
  down;

  String get label => this == across ? 'Width' : 'Height';
}

/// One size in the design the user is asked for, or one that follows from
/// the sizes they give.
///
/// **A size is asked for only where the user's answer can be built exactly
/// without undoing another answer.** A row of three lights across a window
/// has three widths, but only two of them are free: the third is what is
/// left of the overall width once the other two and the bars between them
/// are taken off. Asking for all three would ask the user to add up, and
/// then either refuse the sum they got wrong or quietly change one of their
/// own figures. So the last of a row [follows], and the form shows it
/// worked out from the others — arithmetic, not a guess.
class Measure {
  /// The key it is kept under in [Design.measured].
  final String key;

  /// What is being measured, for the heading it is listed under.
  final String group;

  /// Width, height, or one of the frame's own figures.
  final String label;

  /// The section it measures, or null for the frame's own figures.
  final String? sectionId;

  final MeasureAxis? axis;

  /// The bar that moves to make this size true, and whether it stands at
  /// the far side of the section (right or bottom) or the near side.
  final String? barId;
  final bool barOnFarSide;

  /// False when it is worked out from the other sizes.
  final bool asked;

  const Measure({
    required this.key,
    required this.group,
    required this.label,
    this.sectionId,
    this.axis,
    this.barId,
    this.barOnFarSide = true,
    this.asked = true,
  });

  bool get follows => !asked;

  /// What it reads on [design] now.
  double currentMm(Design design) {
    switch (key) {
      case Measurements.profileKey:
        return design.frame?.profileMm ?? 0;
      case Measurements.barsKey:
        return design.dividers.isEmpty ? 0 : design.dividers.first.widthMm;
      case Measurements.widthKey:
        return design.widthMm;
      case Measurements.heightKey:
        return design.heightMm;
    }
    final section = design.sectionById(sectionId ?? '');
    if (section == null) return 0;
    return axis == MeasureAxis.across ? section.widthMm : section.heightMm;
  }
}

/// What happened when the sizes were put into the design: the design, and
/// a reason for every size that could not be made true.
class MeasureOutcome {
  final Design design;

  /// By [Measure.key].
  final Map<String, String> problems;

  const MeasureOutcome(this.design, this.problems);

  bool get ok => problems.isEmpty;
}

/// The real sizes of a design, asked for rather than read off the sketch.
///
/// A hand drawing has proportions and no scale, so every figure a reading
/// works out is the drawing's size at whatever size the hand drew it. The
/// user said never to write such a figure as a number: every size is asked
/// for, and until it is given it is shown as `?`. This is the one place
/// that says what is asked, what follows, and how an answer is put into the
/// design.
///
/// **An answer moves the sheet as well as the design.** A typed size moves
/// a bar or a side of the frame, and the ink that bar was read from moves
/// with it, so the ink still lies on the line it made and reading the sheet
/// again builds the same design. A size that moved only the geometry would
/// last until the next reading — which is exactly how typed sizes used to
/// be lost the moment anything was drawn and read.
abstract final class Measurements {
  static const profileKey = 'profile';
  static const barsKey = 'bars';
  static const widthKey = 'width';
  static const heightKey = 'height';

  /// The key a bar's place is kept under, along the axis it divides.
  static String barKey(MeasureAxis axis, String barId) =>
      '${axis == MeasureAxis.across ? 'x' : 'y'}:$barId';

  /// Everything there is to measure on [design], in the order the form
  /// asks it: the frame, then each main division in reading order, each
  /// followed by the panes drawn inside it.
  static List<Measure> of(Design design) {
    if (design.frame == null) return const [];
    final measures = <Measure>[
      const Measure(key: profileKey, group: 'Frame', label: 'Frame border'),
      if (design.dividers.isNotEmpty)
        const Measure(key: barsKey, group: 'Frame', label: 'Bar thickness'),
      const Measure(key: widthKey, group: 'Frame', label: 'Overall width'),
      const Measure(key: heightKey, group: 'Frame', label: 'Overall height'),
    ];
    final claimed = <String>{};
    var fixed = 0;

    void add(SectionElement section, String group) {
      for (final axis in MeasureAxis.values) {
        measures.add(_sizeOf(design, section, axis, group, claimed));
      }
    }

    void panes(SectionElement parent, String around) {
      var n = 0;
      for (final pane in design.childSectionsOf(parent.id)) {
        n++;
        add(pane, '$around — ${pane.finish.material.label} $n');
        panes(pane, '$around — ${pane.finish.material.label} $n');
      }
    }

    for (final section in design.topLevelSections) {
      final opening = design.openingOf(section.id);
      final group = opening != null
          ? design.nameOf(opening)
          : 'Fixed light ${++fixed}';
      add(section, group);
      panes(section, group);
    }
    return measures;
  }

  static Measure _sizeOf(
    Design design,
    SectionElement section,
    MeasureAxis axis,
    String group,
    Set<String> claimed,
  ) {
    final across = axis == MeasureAxis.across;
    final far = DesignEdits.dividerAlong(
      design,
      x: across ? section.outline.right : null,
      y: across ? null : section.outline.bottom,
      within: section.parentId,
    );
    final near = DesignEdits.dividerAlong(
      design,
      x: across ? section.outline.left : null,
      y: across ? null : section.outline.top,
      within: section.parentId,
    );
    for (final (bar, farSide) in [(far, true), (near, false)]) {
      if (bar == null) continue;
      final key = barKey(axis, bar.id);
      if (!claimed.add(key)) continue;
      return Measure(
        key: key,
        group: group,
        label: axis.label,
        sectionId: section.id,
        axis: axis,
        barId: bar.id,
        barOnFarSide: farSide,
      );
    }
    return Measure(
      key: 'follows:${axis.name}:${section.id}',
      group: group,
      label: axis.label,
      sectionId: section.id,
      axis: axis,
      asked: false,
    );
  }

  /// Whether every size asked for on [design] has been given. A design kept
  /// before sizes were asked for has nothing outstanding.
  static bool complete(Design design) {
    final said = design.measured;
    if (said == null) return true;
    return of(design).every((m) => m.follows || said.contains(m.key));
  }

  /// Whether [measure] is known: given by the user, or worked out entirely
  /// from sizes that were.
  static bool knows(Design design, Measure measure, [List<Measure>? all]) {
    final said = design.measured;
    if (said == null) return true;
    if (measure.asked) return said.contains(measure.key);
    // What follows is known once everything it follows from is: the
    // frame's own figures, and every other size asked for along the same
    // axis in the same place.
    final base = [
      profileKey,
      if (design.dividers.isNotEmpty) barsKey,
      if (measure.axis == MeasureAxis.across) widthKey else heightKey,
    ];
    if (!base.every(said.contains)) return false;
    final section = design.sectionById(measure.sectionId ?? '');
    final level = design.sectionHolding(section?.parentId);
    for (final other in all ?? of(design)) {
      if (!other.asked || other.axis != measure.axis) continue;
      final at = design.sectionById(other.sectionId ?? '');
      if (at == null) continue;
      final otherLevel = design.sectionHolding(at.parentId);
      // Its own level, and every level it sits inside.
      if (otherLevel == level || _inside(design, level, otherLevel)) {
        if (!said.contains(other.key)) return false;
      }
    }
    return true;
  }

  static bool _inside(Design design, String? level, String? outer) {
    var at = level;
    for (var i = 0; i < 8 && at != null; i++) {
      final section = design.sectionById(at);
      final parent = design.sectionHolding(section?.parentId);
      if (parent == outer) return true;
      at = parent;
    }
    return outer == null;
  }

  /// Whether the overall size along [axis] is known.
  static bool knowsOverall(Design design, MeasureAxis axis) {
    final said = design.measured;
    if (said == null) return true;
    return said.contains(axis == MeasureAxis.across ? widthKey : heightKey);
  }

  /// Whether a section's size along [axis] is known.
  static bool knowsSection(
    Design design,
    String sectionId,
    MeasureAxis axis, [
    List<Measure>? all,
  ]) {
    if (design.measured == null) return true;
    final measures = all ?? of(design);
    for (final m in measures) {
      if (m.sectionId == sectionId && m.axis == axis) {
        return knows(design, m, measures);
      }
    }
    return false;
  }

  /// [mm] as a figure: centimetres where it is known, `?` where it is not.
  static String figure(double mm, {required bool known}) =>
      known ? Units.label(mm) : '? ${Units.symbol}';

  /// A width by a height, each written only where it is known.
  static String size(
    double widthMm,
    double heightMm, {
    required bool knowsWidth,
    required bool knowsHeight,
  }) =>
      '${knowsWidth ? Units.format(widthMm) : '?'} × '
      '${figure(heightMm, known: knowsHeight)}';

  /// [section]'s width by its height, as far as each is known.
  static String sizeOf(
    Design design,
    SectionElement section, [
    List<Measure>? all,
  ]) {
    final measures = all ?? of(design);
    return size(
      section.widthMm,
      section.heightMm,
      knowsWidth: knowsSection(
        design,
        section.id,
        MeasureAxis.across,
        measures,
      ),
      knowsHeight: knowsSection(design, section.id, MeasureAxis.down, measures),
    );
  }

  /// The design's overall width by its height, as far as each is known.
  static String overallOf(Design design) => size(
    design.widthMm,
    design.heightMm,
    knowsWidth: knowsOverall(design, MeasureAxis.across),
    knowsHeight: knowsOverall(design, MeasureAxis.down),
  );

  /// Whether the frame's own figure [key] is known.
  static bool knowsKey(Design design, String key) =>
      design.measured?.contains(key) ?? true;

  /// Puts [values] — millimetres, by [Measure.key] — into [design].
  ///
  /// In the form's order: the frame's border and the bars first, because
  /// they take their width off every light; then the overall size, which
  /// stretches the whole sheet along that axis; then each light in reading
  /// order, each moving the one bar it was given. A light never moves a bar
  /// an earlier light was given, so no answer undoes another.
  static MeasureOutcome apply(Design design, Map<String, double> values) {
    var d = design;
    final problems = <String, String>{};
    final said = <String>{...?design.measured};

    final profile = values[profileKey];
    if (profile != null && d.frame != null) {
      if (profile <= 0 || profile * 2 >= math.min(d.widthMm, d.heightMm)) {
        problems[profileKey] = 'Too wide for the frame.';
      } else {
        d = SectionBuilder.rebuild(
          d.withElement(d.frame!.copyWith(profileMm: profile)),
        );
        said.add(profileKey);
      }
    }

    final bars = values[barsKey];
    if (bars != null) {
      if (bars <= 0) {
        problems[barsKey] = 'A bar has to have some thickness.';
      } else {
        d = SectionBuilder.rebuild(
          d.copyWith(
            dividers: [
              for (final bar in d.dividers) bar.copyWith(widthMm: bars),
            ],
          ),
        );
        said.add(barsKey);
      }
    }

    for (final (key, axis) in const [
      (widthKey, MeasureAxis.across),
      (heightKey, MeasureAxis.down),
    ]) {
      final value = values[key];
      final frame = d.frame;
      if (value == null || frame == null) continue;
      final box = frame.outline;
      final start = axis == MeasureAxis.across ? box.left : box.top;
      final end = axis == MeasureAxis.across ? box.right : box.bottom;
      if (value <= (frame.profileMm * 2)) {
        problems[key] = 'Smaller than the frame around it.';
        continue;
      }
      d = stretch(d, axis, [start, end], [start, start + value]);
      said.add(key);
    }

    // One light at a time, each read afresh: a light's own section is
    // rebuilt by every answer before it, so it is found again by its key.
    for (final first in of(d)) {
      if (!first.asked || first.barId == null) continue;
      final value = values[first.key];
      if (value == null) continue;
      final measure = of(d).where((m) => m.key == first.key).firstOrNull;
      if (measure == null) continue;
      final result = _moveBarFor(d, measure, value);
      if (result == null) {
        problems[measure.key] =
            'That does not fit beside the parts next '
            'to it.';
        continue;
      }
      d = result;
      said.add(measure.key);
    }

    return MeasureOutcome(d.copyWith(measured: said), problems);
  }

  static Design? _moveBarFor(Design design, Measure measure, double value) {
    final section = design.sectionById(measure.sectionId ?? '');
    final bar = design.dividers.where((b) => b.id == measure.barId).firstOrNull;
    if (section == null || bar == null || value <= 0) return null;
    return _resize(
      design,
      section,
      measure.axis!,
      value,
      _middleOf(bar, measure.axis!),
      measure.barOnFarSide,
      bar.widthMm,
    );
  }

  static double _middleOf(DividerElement bar, MeasureAxis axis) =>
      axis == MeasureAxis.across
      ? bar.segment.midpoint.x
      : bar.segment.midpoint.y;

  /// [section] made [value] along [axis] by moving the stop at [at] — a
  /// bar's middle or a side of the frame — on its far side or its near
  /// side, and nothing else. Null when that does not fit.
  static Design? _resize(
    Design design,
    SectionElement section,
    MeasureAxis axis,
    double value,
    double at,
    bool farSide,
    double room,
  ) {
    final across = axis == MeasureAxis.across;
    final now = across ? section.widthMm : section.heightMm;
    final growth = value - now;
    if (growth.abs() < 0.05) return design;
    final to = at + (farSide ? growth : -growth);

    // Everything else that runs the same way stays where it is: the frame's
    // sides and every other bar across that axis, at any level.
    final stops = _stops(design, axis)..removeWhere((s) => (s - at).abs() < 1);
    final before = stops
        .where((s) => s < at)
        .fold<double?>(null, (m, s) => m == null || s > m ? s : m);
    final after = stops
        .where((s) => s > at)
        .fold<double?>(null, (m, s) => m == null || s < m ? s : m);
    final List<double> from;
    final List<double> onto;
    if (before != null && after != null) {
      if (to <= before + room || to >= after - room) return null;
      from = [before, at, after];
      onto = [before, to, after];
    } else if (before != null) {
      // The far side of the frame: what lies beyond it is carried along.
      if (to <= before + room) return null;
      from = [before, at];
      onto = [before, to];
    } else if (after != null) {
      if (to >= after - room) return null;
      from = [at, after];
      onto = [to, after];
    } else {
      return null;
    }

    final moved = stretch(design, axis, from, onto);
    final check =
        moved.sectionById(section.id) ??
        _sectionNear(moved, section, axis, growth, farSide);
    if (check == null) return moved;
    final reads = across ? check.widthMm : check.heightMm;
    return (reads - value).abs() <= 1 ? moved : null;
  }

  /// [sectionId] made [value] along [axis], from wherever the user typed
  /// it — a figure on the drawing, a field on a panel.
  ///
  /// A size that is asked for is given, exactly as the form gives it. A
  /// size that follows from the others can still be typed over, and then
  /// the bar or the side of the frame that bounds it moves — the one on its
  /// far side where there is one — which changes the size next to it too,
  /// because that is what moving it means.
  static MeasureOutcome setSize(
    Design design,
    String sectionId,
    MeasureAxis axis,
    double value,
  ) {
    final all = of(design);
    final measure = all
        .where((m) => m.sectionId == sectionId && m.axis == axis)
        .firstOrNull;
    final section = design.sectionById(sectionId);
    if (measure == null || section == null || value <= 0) {
      return MeasureOutcome(design, {sectionId: 'Nothing to measure.'});
    }
    if (measure.asked) return apply(design, {measure.key: value});

    final across = axis == MeasureAxis.across;
    for (final (edge, farSide) in [
      (across ? section.outline.right : section.outline.bottom, true),
      (across ? section.outline.left : section.outline.top, false),
    ]) {
      final bar = DesignEdits.dividerAlong(
        design,
        x: across ? edge : null,
        y: across ? null : edge,
        within: section.parentId,
      );
      if (bar == null) continue;
      final moved = _resize(
        design,
        section,
        axis,
        value,
        _middleOf(bar, axis),
        farSide,
        bar.widthMm,
      );
      return moved == null
          ? MeasureOutcome(design, {measure.key: 'That does not fit.'})
          : MeasureOutcome(moved, const {});
    }

    // No bar either side at its own level: a pane that fills its opening
    // is the opening, and the size is the opening's.
    final parent = design.sectionHolding(section.parentId);
    if (parent != null) return setSize(design, parent, axis, value);

    // Otherwise it runs to the frame on both sides, and the frame's far
    // side is what moves.
    final frame = design.frame;
    if (frame == null) {
      return MeasureOutcome(design, {measure.key: 'No frame.'});
    }
    final moved = _resize(
      design,
      section,
      axis,
      value,
      across ? frame.outline.right : frame.outline.bottom,
      true,
      frame.profileMm,
    );
    return moved == null
        ? MeasureOutcome(design, {measure.key: 'That does not fit.'})
        : MeasureOutcome(moved, const {});
  }

  static SectionElement? _sectionNear(
    Design design,
    SectionElement was,
    MeasureAxis axis,
    double growth,
    bool farSide,
  ) {
    final c = was.outline.centroid;
    final shift = farSide ? growth / 2 : -growth / 2;
    final guess = axis == MeasureAxis.across
        ? Vec2(c.x + shift, c.y)
        : Vec2(c.x, c.y + shift);
    SectionElement? best;
    var bestDistance = double.infinity;
    for (final s in design.sections) {
      if (s.parentId != was.parentId) continue;
      final distance = s.outline.centroid.distanceTo(guess);
      if (distance < bestDistance) {
        best = s;
        bestDistance = distance;
      }
    }
    return best;
  }

  /// The places along [axis] that nothing but a typed size may move: the
  /// frame's own sides and the middle of every bar that runs across it.
  static List<double> _stops(Design design, MeasureAxis axis) {
    final across = axis == MeasureAxis.across;
    final frame = design.frame;
    return [
      if (frame != null) ...[
        across ? frame.outline.left : frame.outline.top,
        across ? frame.outline.right : frame.outline.bottom,
      ],
      for (final bar in design.dividers)
        if (across ? bar.isVertical : bar.isHorizontal)
          across ? bar.segment.midpoint.x : bar.segment.midpoint.y,
    ];
  }

  /// [design] with [axis] stretched piece by piece so that each of [from]
  /// lands on the matching [to] — the design and the ink together.
  ///
  /// Every stop is carried with a band round it, moved whole, so the ink a
  /// line was read from moves exactly as the line does and reading it again
  /// finds the line where the size put it. Between the bands the sheet is
  /// stretched evenly; beyond the first and last stops it is carried along.
  static Design stretch(
    Design design,
    MeasureAxis axis,
    List<double> from,
    List<double> to,
  ) {
    final map = _AxisMap.banded(from, to, _band(design, axis));
    final across = axis == MeasureAxis.across;
    Vec2 point(Vec2 p) => across ? Vec2(map(p.x), p.y) : Vec2(p.x, map(p.y));
    Polygon shape(Polygon p) => Polygon([for (final c in p.corners) point(c)]);

    return SectionBuilder.rebuild(
      design.copyWith(
        frame: design.frame?.copyWith(outline: shape(design.frame!.outline)),
        dividers: [
          for (final d in design.dividers)
            d.copyWith(a: point(d.a), b: point(d.b)),
        ],
        hardware: [
          for (final h in design.hardware) h.copyWith(at: point(h.at)),
        ],
        openings: [
          for (final o in design.openings)
            if (o.markAt case final at?) o.copyWith(markAt: point(at)) else o,
        ],
        dimensions: [
          for (final d in design.dimensions)
            d.copyWith(a: point(d.a), b: point(d.b)),
        ],
        texts: [for (final t in design.texts) t.copyWith(at: point(t.at))],
        arrows: [
          for (final a in design.arrows)
            a.copyWith(from: point(a.from), to: point(a.to)),
        ],
        sketch: Sketch(
          strokes: [
            for (final stroke in design.sketch.strokes)
              stroke.copyWith(
                samples: [
                  for (final s in stroke.samples) s.movedTo(point(s.at)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// How much of the sheet round a line moves with it: a hand's wobble
  /// either side, taken as a share of the design.
  static double _band(Design design, MeasureAxis axis) {
    final span = axis == MeasureAxis.across ? design.widthMm : design.heightMm;
    return span <= 0 ? 0 : span * 0.03;
  }

  /// [read], a fresh reading of [before]'s sheet, with every size the user
  /// gave kept exactly.
  ///
  /// Because an answer moves the ink with the line, a reading finds each
  /// line where the size put it — to within how straight the hand drew it.
  /// This takes out that last wobble: a bar the user gave a place keeps it,
  /// and a frame they gave a size keeps that size while it is still the
  /// same frame. A frame drawn afresh is a new frame, and its size is asked
  /// for again. What the user said is kept; nothing is kept that they did
  /// not say.
  static Design keepAfterReading(Design before, Design read) {
    final said = before.measured;
    if (said == null) return read;
    final keep = <String>{...said};
    var d = read;

    final was = before.frame;
    final now = d.frame;
    if (was != null && now != null) {
      final tolerance = math.max(
        3.0,
        0.02 * math.max(was.widthMm, was.heightMm),
      );
      final same =
          was.outline.corners.length == now.outline.corners.length &&
          (was.outline.left - now.outline.left).abs() <= tolerance &&
          (was.outline.right - now.outline.right).abs() <= tolerance &&
          (was.outline.top - now.outline.top).abs() <= tolerance &&
          (was.outline.bottom - now.outline.bottom).abs() <= tolerance;
      if (same) {
        d = d.copyWith(
          frame: now.copyWith(outline: was.outline, profileMm: was.profileMm),
        );
      } else {
        keep
          ..remove(widthKey)
          ..remove(heightKey);
      }
    } else if (now == null) {
      keep
        ..remove(widthKey)
        ..remove(heightKey);
    }

    final barWidth = said.contains(barsKey) && before.dividers.isNotEmpty
        ? before.dividers.first.widthMm
        : null;
    final oldBars = {for (final b in before.dividers) b.id: b};
    d = d.copyWith(
      dividers: [
        for (final bar in d.dividers)
          _keptBar(bar, oldBars[bar.id], said, barWidth),
      ],
    );
    // A size given to a bar that has gone is not a size of anything.
    keep.removeWhere((key) {
      final colon = key.indexOf(':');
      if (colon < 0 || key.startsWith('follows')) return false;
      final id = key.substring(colon + 1);
      return !d.dividers.any((b) => b.id == id);
    });
    return SectionBuilder.rebuild(d.copyWith(measured: keep));
  }

  static DividerElement _keptBar(
    DividerElement bar,
    DividerElement? was,
    Set<String> said,
    double? barWidth,
  ) {
    if (was == null) {
      return barWidth == null ? bar : bar.copyWith(widthMm: barWidth);
    }
    var kept = bar;
    final middle = kept.segment.midpoint;
    final old = was.segment.midpoint;
    if (said.contains(barKey(MeasureAxis.across, bar.id)) && bar.isVertical) {
      final by = Vec2(old.x - middle.x, 0);
      kept = kept.copyWith(a: kept.a + by, b: kept.b + by);
    }
    if (said.contains(barKey(MeasureAxis.down, bar.id)) && bar.isHorizontal) {
      final by = Vec2(0, old.y - middle.y);
      kept = kept.copyWith(a: kept.a + by, b: kept.b + by);
    }
    return kept;
  }
}

/// A piecewise-straight map of one axis, carrying a band round each stop
/// whole and stretching the sheet evenly between the bands.
class _AxisMap {
  final List<double> from;
  final List<double> to;

  const _AxisMap(this.from, this.to);

  factory _AxisMap.banded(List<double> stops, List<double> onto, double band) {
    final from = <double>[];
    final to = <double>[];
    for (var i = 0; i < stops.length; i++) {
      // The band never reaches half way to the next stop, before or after,
      // on the sheet as it was or as it will be.
      var h = band;
      if (i > 0) {
        h = math.min(h, (stops[i] - stops[i - 1]) * 0.45);
        h = math.min(h, (onto[i] - onto[i - 1]) * 0.45);
      }
      if (i + 1 < stops.length) {
        h = math.min(h, (stops[i + 1] - stops[i]) * 0.45);
        h = math.min(h, (onto[i + 1] - onto[i]) * 0.45);
      }
      h = math.max(0, h);
      if (h > 0) {
        from.add(stops[i] - h);
        to.add(onto[i] - h);
      }
      from.add(stops[i]);
      to.add(onto[i]);
      if (h > 0) {
        from.add(stops[i] + h);
        to.add(onto[i] + h);
      }
    }
    return _AxisMap(from, to);
  }

  double call(double v) {
    if (from.isEmpty) return v;
    if (v <= from.first) return v + (to.first - from.first);
    if (v >= from.last) return v + (to.last - from.last);
    for (var i = 0; i + 1 < from.length; i++) {
      final a = from[i];
      final b = from[i + 1];
      if (v >= a && v <= b) {
        if (b - a < 1e-9) return to[i];
        return to[i] + (v - a) * (to[i + 1] - to[i]) / (b - a);
      }
    }
    return v;
  }
}
