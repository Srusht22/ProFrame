import 'dart:math' as math;

import '../editing/design_edits.dart';
import '../geometry/polygon.dart';
import '../geometry/segment.dart';
import '../geometry/tolerances.dart';
import '../geometry/vec2.dart';
import '../model/design.dart';
import '../model/elements.dart';
import '../model/materials.dart';
import '../model/question.dart';
import '../sections/planar_graph.dart';
import '../sections/section_bands.dart';
import '../sections/section_builder.dart';
import '../sketch/stroke.dart';
import 'opening_symbol.dart';
import 'stroke_fit.dart';

/// What was read from a drawing, and what could not be read with confidence.
class Interpretation {
  /// The design as read. The sketch inside it is untouched.
  final Design design;

  /// Everything the reading was unsure about. These are put to the user; the
  /// application does not answer them itself.
  final List<DesignQuestion> questions;

  /// Strokes that carried no structure — a scribble, a mark, a stray dot.
  /// They stay in the sketch. Nothing is deleted on their account.
  final List<String> unusedStrokeIds;

  /// The `<` and `>` marks that were read, whether or not they could be
  /// placed in a section.
  final List<OpeningSymbol> symbols;

  const Interpretation({
    required this.design,
    this.questions = const [],
    this.unusedStrokeIds = const [],
    this.symbols = const [],
  });

  bool get hasQuestions => questions.isNotEmpty;
}

/// Reads a sketch as a door or a window.
///
/// It does exactly two things: it takes the shake out of the lines, and it
/// works out which lines enclose what. It does not decide how many panels
/// there should be, where an opening belongs, or what a design of this kind
/// usually looks like. Where the drawing is ambiguous it produces a question
/// rather than an answer.
abstract final class SketchInterpreter {
  /// Reads [design]'s sketch.
  ///
  /// [notSymbols] holds the ids of strokes the user has said are lines to
  /// build rather than opening marks. Their answer is kept, so a mark they
  /// have already ruled on is not asked about again.
  static Interpretation interpret(
    Design design, {
    String Function()? newId,
    Set<String> notSymbols = const {},
  }) {
    // The opening marks come out first. A `>` is two strokes' worth of
    // straight lines to a line-fitter, and building it as two bars would put
    // something in the design that the user drew as an instruction.
    final symbols = <OpeningSymbol>[];
    final symbolStrokes = <String>{};
    for (final stroke in design.sketch.strokes) {
      if (!_isStructural(stroke)) continue;
      if (notSymbols.contains(stroke.id)) continue;
      final symbol = OpeningSymbolReader.read(stroke);
      if (symbol == null) continue;
      symbols.add(symbol);
      symbolStrokes.add(stroke.id);
    }

    final structural = [
      for (final stroke in design.sketch.strokes)
        if (_isStructural(stroke) && !symbolStrokes.contains(stroke.id))
          stroke,
    ];
    if (structural.isEmpty) {
      return Interpretation(
        design: design.copyWith(
          clearFrame: true,
          dividers: const [],
          sections: const [],
        ),
      );
    }

    final fits = [for (final stroke in structural) StrokeFitter.fit(stroke)];
    final runs = <_Run>[];
    for (final fit in fits) {
      if (fit.kind == FitKind.mark) continue;
      for (final segment in fit.segments) {
        if (segment.length < Tol.minLineMm) continue;
        runs.add(_Run(StrokeFitter.straightened(segment), fit.stroke.id));
      }
    }

    if (runs.isEmpty) {
      return Interpretation(
        design: design.copyWith(
          clearFrame: true,
          dividers: const [],
          sections: const [],
        ),
        unusedStrokeIds: [for (final s in structural) s.id],
      );
    }

    final welded = _weld(runs);
    final span = _spanOf(welded);
    final weld = Tol.weldFor(span);
    final shape = PlanarSubdivision.subdivide(
      [for (final r in welded) r.segment],
      weldTolerance: weld,
      minAreaMmSq: math.max(Tol.minSectionAreaMmSq, weld * weld * 4),
    );

    final outline = shape.outline?.simplified(weld);
    if (outline == null || outline.isEmpty) {
      return _unclosed(design, welded, structural);
    }

    var counter = 0;
    String nextId(String prefix) =>
        newId?.call() ?? '$prefix-${design.id}-${counter++}';

    final frame = FrameElement(
      id: design.frame?.id ?? nextId('frame'),
      outline: outline,
      profileMm: design.frame?.profileMm ?? _profileFor(outline),
      finish: design.frame?.finish ?? Finish.frameDefault,
    );

    // Which lines belong inside an opening rather than dividing the whole
    // design. A mark makes the region it is in an opening, and what is drawn
    // in that region afterwards is drawn in the opening.
    final insideOpening = _openingContents(
      welded: welded,
      symbols: symbols,
      sketch: design.sketch,
      outline: outline,
      weld: weld,
    );

    // Every run that is not part of the outline is a line inside the design:
    // a mullion, a transom, a glazing bar. It is kept exactly where it was
    // drawn, at the angle it was drawn.
    final dividers = <DividerElement>[];
    final contained = <(DividerElement, Polygon)>[];
    for (final run in welded) {
      if (_liesOn(run.segment, outline, weld)) continue;
      final divider = DividerElement(
        id: nextId('divider'),
        a: run.segment.a,
        b: run.segment.b,
        widthMm: frame.profileMm * 0.8,
        finish: frame.finish,
        fromStrokeId: run.strokeId,
      );
      final region = insideOpening[run.strokeId];
      if (region == null) {
        dividers.add(divider);
      } else {
        contained.add((divider, region));
      }
    }

    // The main structure first, from the lines that divide the design as a
    // whole. Only once that is known is there something for a contained line
    // to be contained by.
    var read = design.copyWith(frame: frame, dividers: dividers);
    read = SectionBuilder.rebuild(read, newId: newId);

    if (contained.isNotEmpty) {
      final all = [...read.dividers];
      for (final (divider, region) in contained) {
        SectionElement? parent;
        for (final section in read.topLevelSections) {
          if (!section.outline.contains(region.centroid)) continue;
          if (parent == null || section.areaMmSq > parent.areaMmSq) {
            parent = section;
          }
        }
        // A line that turns out to be contained by nothing is a line that
        // divides the design, so it is one.
        if (parent == null) {
          all.add(divider);
          continue;
        }
        // Trimmed to the section it is inside, so a line drawn a little long
        // does not reach out of the opening and across the design. Only the
        // overshoot goes: what the user drew inside the opening stays where
        // they drew it, at the angle they drew it.
        final trimmed = _trimmedTo(divider.segment, parent.outline);
        all.add(divider.copyWith(
          parentId: parent.id,
          a: trimmed?.a,
          b: trimmed?.b,
        ));
      }
      read = SectionBuilder.rebuild(
        read.copyWith(dividers: all),
        newId: newId,
      );
    }

    // An opening that came from a mark lasts exactly as long as the mark
    // does. Rub the mark out, or say it was never one, and the opening goes
    // with it — otherwise the drawing and the design would disagree about
    // who decided what.
    read = read.copyWith(openings: [
      for (final opening in read.openings)
        if (opening.fromStrokeId == null ||
            symbolStrokes.contains(opening.fromStrokeId))
          opening,
    ]);

    final placed = _placeSymbols(read, symbols, nextId);
    read = placed.design;

    // The only questions are the ones the drawing genuinely cannot answer.
    // Everything else is built as the user drew it and left for them to
    // change — a size they can type over, a bar they can turn into an
    // opening, a pane they can make glass or panel. Asking about something
    // that is already on the panel beside the drawing is asking them to say
    // twice what they have said once.
    final questions = <DesignQuestion>[...placed.questions];

    final usedStrokes = {
      for (final run in welded) run.strokeId,
    };
    return Interpretation(
      design: read,
      questions: questions,
      symbols: symbols,
      unusedStrokeIds: [
        for (final stroke in structural)
          if (!usedStrokes.contains(stroke.id)) stroke.id,
      ],
    );
  }

  /// The lines that belong inside an opening rather than dividing the whole
  /// design, as a map from the stroke that made them to the region they are
  /// inside.
  ///
  /// Two things make a line the opening's, and either is enough.
  ///
  /// **Where it is.** A line that lies wholly inside one marked region is
  /// that opening's, whenever it was drawn. This is the plain meaning of
  /// drawing inside something, and it is what most drawings rely on: a line
  /// across the narrow light on the left of a window divides that light, not
  /// the window, because it does not reach anything else. Working it out is
  /// not circular — each line is measured against the regions the *other*
  /// lines make, so nothing is asked to define itself.
  ///
  /// **When it was drawn.** A line that crosses the whole design looks
  /// exactly like a division of the design, because that is also what it
  /// could be: on an elevation a transom and a sash bar are the same stroke.
  /// There the order settles it. Whatever was on the sheet when the mark was
  /// made is the structure the mark was placed into, and a line drawn in the
  /// marked region after it is drawn in the opening.
  ///
  /// Neither is a guess. The first reads where the line is, the second reads
  /// when it was made; both are facts about the drawing. Where the drawing
  /// says neither, the line divides the design, and a bar's own panel
  /// carries a **Divides** control for saying otherwise.
  static Map<String, Polygon> _openingContents({
    required List<_Run> welded,
    required List<OpeningSymbol> symbols,
    required Sketch sketch,
    required Polygon outline,
    required double weld,
  }) {
    if (symbols.isEmpty) return const {};

    final contents = <String, Polygon>{};
    _byPlace(
      welded: welded,
      symbols: symbols,
      outline: outline,
      weld: weld,
      into: contents,
    );
    _byOrder(
      welded: welded,
      symbols: symbols,
      sketch: sketch,
      weld: weld,
      into: contents,
    );
    return contents;
  }

  /// A line that does not reach across the design, and lies inside a marked
  /// region, belongs to that region.
  ///
  /// The test is what a line reaches. A line running from one side of the
  /// frame to the opposite side divides the design: that is what a mullion
  /// or a transom is, and it bounds whatever is on both sides of it. A line
  /// that stops short of that — one that ends on another bar — cannot be
  /// dividing the design, because it does not cross it. It divides only the
  /// region it is in, and if that region is marked, it is the opening's.
  ///
  /// This is what makes a line across the narrow light on the left of a
  /// window belong to that light rather than to the window, whenever it was
  /// drawn. The regions are measured from the lines that *do* reach across,
  /// so no line helps decide its own place and nothing here is circular.
  static void _byPlace({
    required List<_Run> welded,
    required List<OpeningSymbol> symbols,
    required Polygon outline,
    required double weld,
    required Map<String, Polygon> into,
  }) {
    // The lines that divide the design whatever else is true of them: the
    // frame itself, and every line running right across it.
    final across = <Segment>[];
    final within = <_Run>[];
    for (final run in welded) {
      if (_liesOn(run.segment, outline, weld) ||
          _reachesAcross(run.segment, outline, weld)) {
        across.add(run.segment);
      } else {
        within.add(run);
      }
    }
    if (within.isEmpty) return;

    final regions = PlanarSubdivision.facesOf(
      across,
      weldTolerance: weld,
      minAreaMmSq: math.max(Tol.minSectionAreaMmSq, weld * weld * 4),
    );
    if (regions.isEmpty) return;

    for (final run in within) {
      // The region holding most of this line. A line drawn in an opening is
      // sometimes drawn a little long, so it is not required to be wholly
      // inside — only to be more inside this region than any other, and
      // mostly inside it. The overshoot is cut off afterwards.
      Polygon? region;
      var best = 0.0;
      for (final candidate in regions) {
        final held = _shareInside(run.segment, candidate);
        if (held <= best) continue;
        best = held;
        region = candidate;
      }
      if (region == null || best < mostlyInsideFraction) continue;

      // A mark must be in it: an opening is the only thing a line can be
      // inside. A line in a plain section divides the design, as before.
      if (!symbols.any((symbol) => region!.contains(symbol.centre))) continue;

      into[run.strokeId] = region;
    }
  }

  /// [line] cut back to the part of it that is inside [outline], or null
  /// when it is inside already or there is nothing left of it.
  ///
  /// Only the ends move, and only inwards. This is trimming a line drawn
  /// past its corner, which is cleaning; it never lengthens a line and never
  /// changes its angle.
  static Segment? _trimmedTo(Segment line, Polygon outline) {
    final length = line.length;
    if (length < Tol.minLineMm) return null;
    final direction = line.unit;

    // Where the line meets the boundary, measured along itself. The ends of
    // the trimmed line sit exactly on the boundary — a line pulled back
    // inside it would touch nothing and so divide nothing.
    final hits = <double>[];
    for (final edge in outline.edges) {
      final at = _meetsAt(line.a, direction, edge);
      if (at != null) hits.add(at);
    }
    if (hits.length < 2) return null;
    hits.sort();

    final from = hits.first.clamp(0.0, length);
    final to = hits.last.clamp(0.0, length);
    if (to - from < Tol.minLineMm) return null;
    // Inside already: there is nothing hanging out to cut off.
    if (from <= Tol.samePointMm && to >= length - Tol.samePointMm) return null;

    return Segment(line.a + direction * from, line.a + direction * to);
  }

  /// How far along a line from [from] in [direction] it meets [edge], or null
  /// when it does not meet it within the edge's own length.
  static double? _meetsAt(Vec2 from, Vec2 direction, Segment edge) {
    final along = edge.direction;
    final denominator = direction.cross(along);
    if (denominator.abs() < 1e-12) return null;
    final onEdge = (edge.a - from).cross(direction) / denominator;
    if (onEdge < -1e-9 || onEdge > 1 + 1e-9) return null;
    return (edge.a - from).cross(along) / denominator;
  }

  /// True when a line runs from one side of [outline] to the opposite side,
  /// which is what dividing the design means.
  ///
  /// Both ends on the frame, and not on the same side of it: a line from the
  /// head to the sill, or from one jamb to the other. A line ending on
  /// another bar is not one of these, and neither is a short line tucked
  /// into a corner.
  static bool _reachesAcross(Segment line, Polygon outline, double weld) {
    final reach = math.max(weld, Tol.minLineMm);
    final onA = _edgeOf(line.a, outline, reach);
    final onB = _edgeOf(line.b, outline, reach);
    if (onA == null || onB == null) return false;
    return onA != onB;
  }

  /// Which side of [outline] a point sits on, or null when it sits on none.
  static int? _edgeOf(Vec2 point, Polygon outline, double reach) {
    final edges = outline.edges;
    for (var i = 0; i < edges.length; i++) {
      if (edges[i].distanceTo(point) <= reach) return i;
    }
    return null;
  }

  /// A line drawn in a marked region after the mark belongs to it.
  static void _byOrder({
    required List<_Run> welded,
    required List<OpeningSymbol> symbols,
    required Sketch sketch,
    required double weld,
    required Map<String, Polygon> into,
  }) {
    final order = <String, int>{};
    for (var i = 0; i < sketch.strokes.length; i++) {
      order[sketch.strokes[i].id] = i;
    }

    var firstMark = 1 << 30;
    for (final symbol in symbols) {
      final at = order[symbol.strokeId];
      if (at != null && at < firstMark) firstMark = at;
    }

    // The structure as it stood when the first mark was made.
    final before = [
      for (final run in welded)
        if ((order[run.strokeId] ?? 0) < firstMark) run,
    ];
    if (before.isEmpty) return;

    final regions = PlanarSubdivision.facesOf(
      [for (final run in before) run.segment],
      weldTolerance: weld,
      minAreaMmSq: math.max(Tol.minSectionAreaMmSq, weld * weld * 4),
    );
    if (regions.isEmpty) return;

    for (final symbol in symbols) {
      final markedAt = order[symbol.strokeId] ?? 0;

      // The smallest region that holds the whole mark is the one it is in.
      Polygon? region;
      for (final candidate in regions) {
        if (!symbol.points.every(candidate.contains)) continue;
        if (region == null || candidate.area < region.area) region = candidate;
      }
      if (region == null) continue;

      for (final run in welded) {
        if ((order[run.strokeId] ?? 0) <= markedAt) continue;
        if (!_mostlyInside(run.segment, region)) continue;
        into[run.strokeId] = region;
      }
    }
  }

  /// True when a line lies inside a region rather than merely crossing it.
  ///
  /// The ends are not tested. A line drawn inside a region usually runs from
  /// one side of it to the other, so its ends sit on the boundary, where
  /// containment is a coin toss decided by a fraction of a millimetre of
  /// wobble. What settles the question is the body of the line: sampled
  /// between the ends, it is either in the region throughout or it leaves it,
  /// and a line that leaves the region is not inside it.
  static bool _mostlyInside(Segment line, Polygon region) {
    const samples = 12;
    for (var i = 1; i < samples; i++) {
      if (!region.contains(line.pointAt(i / samples))) return false;
    }
    return true;
  }

  /// How much of a line is drawn inside a region, before it may be said to
  /// have been drawn in it.
  ///
  /// Not all of it, because a hand draws a line in an opening a little long
  /// and it strays over the bar at the end. Comfortably most of it, because
  /// a line that leaves the opening for a third of its length was not drawn
  /// in the opening at all.
  static const double mostlyInsideFraction = 0.66;

  /// What fraction of the body of [line] lies inside [region].
  static double _shareInside(Segment line, Polygon region) {
    const samples = 24;
    var inside = 0;
    for (var i = 1; i < samples; i++) {
      if (region.contains(line.pointAt(i / samples))) inside++;
    }
    return inside / (samples - 1);
  }

  /// Gives each mark the section it was drawn in.
  ///
  /// A mark opens the section it is inside and no other. Where every part of
  /// the mark lies in one section there is nothing to decide, so the opening
  /// is made. Where it does not — the mark straddles a bar, sits over the
  /// frame, or falls outside the design — nothing is decided at all and the
  /// user is asked which section they meant.
  static _Placed _placeSymbols(
    Design design,
    List<OpeningSymbol> symbols,
    String Function(String) nextId,
  ) {
    var read = design;
    final questions = <DesignQuestion>[];

    for (final symbol in symbols) {
      final section = sectionFor(read, symbol);

      // A mark drawn right off the design has no section to open. That is
      // the one case with nothing to work from, and it is the only one that
      // is asked about.
      if (section == null) {
        questions.add(DesignQuestion(
          id: 'symbol-${symbol.strokeId}',
          prompt: 'Which section does this ${symbol.glyph} belong to?',
          detail: 'The mark is outside the design, so there is no section it '
              'could be in. Say which one you meant.',
          aboutIds: [
            symbol.strokeId,
            for (final s in read.topLevelSections) s.id,
          ],
          options: [
            for (final option in read.topLevelSections)
              QuestionOption(
                key: option.id,
                label: _describe(option, read),
                detail: 'Open this one, ${symbol.meaning}.',
              ),
            const QuestionOption(
              key: 'not-a-symbol',
              label: 'It is not an opening mark',
              detail: 'Build it as lines, exactly where it was drawn.',
            ),
          ],
        ));
        continue;
      }

      read = DesignEdits.setOpening(
        read,
        section.id,
        openingId: nextId('opening'),
        mechanism: symbol.mechanism,
        markAt: symbol.centre,
        markGlyph: symbol.glyph,
        fromStrokeId: symbol.strokeId,
      );
    }

    return _Placed(read, questions);
  }

  /// The section a mark opens.
  ///
  /// The mark is an instruction, not a puzzle: the user has already said
  /// which section opens by drawing the mark in it, so this works out which
  /// one that is rather than asking them to say it again.
  ///
  /// The point of the mark decides it. A mark sits in the section its middle
  /// is in — that is what being in a section means, and it holds however
  /// shakily the mark was drawn and however near a bar it strayed. Where the
  /// middle falls on a bar or outside the daylight, the section holding most
  /// of the mark takes it. Only a mark drawn right off the design leaves
  /// nothing to go on.
  ///
  /// Only the main divisions are candidates. A mark makes the region it is
  /// in an opening; what is inside that region is the opening's, not a rival
  /// for it.
  static SectionElement? sectionFor(Design design, OpeningSymbol symbol) {
    final sections = design.topLevelSections;
    if (sections.isEmpty) return null;

    for (final section in sections) {
      if (section.outline.contains(symbol.centre)) return section;
    }

    // The middle landed on a bar or in the frame. Whichever section holds
    // most of the mark is the one it was drawn in.
    SectionElement? best;
    var most = 0;
    for (final section in sections) {
      var held = 0;
      for (final point in symbol.points) {
        if (section.outline.contains(point)) held++;
      }
      if (held > most) {
        most = held;
        best = section;
      }
    }
    if (best != null) return best;

    // Nothing holds any of it, but it may still be nearest to one.
    SectionElement? nearest;
    var away = double.infinity;
    for (final section in sections) {
      final gap = section.outline.centroid.distanceTo(symbol.centre);
      if (gap < away) {
        away = gap;
        nearest = section;
      }
    }
    // Only when the mark is well outside the design is there nothing to go
    // on. Inside it, the nearest section is the one it is in.
    final frame = design.frame;
    if (frame != null && frame.outline.contains(symbol.centre)) {
      return nearest;
    }
    return null;
  }

  /// A section named the way somebody would point at it.
  static String _describe(SectionElement section, Design design) {
    final frame = design.frame;
    final where = StringBuffer();
    if (frame != null) {
      final middleY = (frame.outline.top + frame.outline.bottom) / 2;
      final middleX = (frame.outline.left + frame.outline.right) / 2;
      final centre = section.outline.centroid;
      if (SectionBands.rows(design) > 1) {
        where.write(centre.y < middleY ? 'upper ' : 'lower ');
      }
      if (SectionBands.columns(design) > 1) {
        where.write(centre.x < middleX ? 'left' : 'right');
      }
    }
    final place = where.toString().trim();
    final size = '${section.widthMm.round()} × ${section.heightMm.round()} mm';
    return place.isEmpty ? size : 'The $place section — $size';
  }

  /// A stroke made with a tool that draws structure. Notes, arrows and
  /// dimensions are the user talking about the design, not the design.
  static bool _isStructural(Stroke stroke) =>
      stroke.tool == StrokeTool.pen ||
      stroke.tool == StrokeTool.line ||
      stroke.tool == StrokeTool.rectangle ||
      stroke.tool == StrokeTool.polyline;

  /// Nothing closed. The lines are still kept as dividers so the user sees
  /// their own drawing turned into real geometry, and the question tells
  /// them what is missing rather than guessing a frame around it.
  static Interpretation _unclosed(
    Design design,
    List<_Run> runs,
    List<Stroke> structural,
  ) {
    var counter = 0;
    return Interpretation(
      design: design.copyWith(
        clearFrame: true,
        sections: const [],
        dividers: [
          for (final run in runs)
            DividerElement(
              id: 'divider-${design.id}-${counter++}',
              a: run.segment.a,
              b: run.segment.b,
              fromStrokeId: run.strokeId,
            ),
        ],
      ),
      questions: [
        const DesignQuestion(
          id: 'frame-not-closed',
          prompt: 'The outline does not close. What would you like to do?',
          detail: 'Your lines do not join up into a shape, so there is no '
              'outer frame yet. Nothing has been changed or added.',
          options: [
            QuestionOption(
              key: 'draw-more',
              label: 'Let me draw the rest',
              detail: 'Go back to the drawing and close the outline yourself.',
            ),
            QuestionOption(
              key: 'join-ends',
              label: 'Join the nearest ends for me',
              detail: 'Extend the lines you drew until they meet. Their '
                  'angles and positions are kept.',
            ),
          ],
        ),
      ],
      unusedStrokeIds: [for (final s in structural) s.id],
    );
  }

  /// Endpoints drawn near each other were meant to be the same point.
  ///
  /// Only the ends move, and only onto each other — a line's angle and
  /// length are otherwise untouched. Without this, a box drawn as four
  /// separate strokes never closes, because a hand does not land twice on
  /// the same pixel.
  static List<_Run> _weld(List<_Run> runs) {
    final span = _spanOf(runs);
    final tolerance = math.max(span * Tol.joinFraction * 0.25, Tol.minLineMm);

    final anchors = <Vec2>[];
    Vec2 anchorFor(Vec2 point) {
      for (var i = 0; i < anchors.length; i++) {
        if (anchors[i].distanceTo(point) <= tolerance) {
          // The anchor drifts to the average of the ends that met there, so
          // no one stroke wins over the others.
          anchors[i] = anchors[i].lerp(point, 0.5);
          return anchors[i];
        }
      }
      anchors.add(point);
      return point;
    }

    final welded = [
      for (final run in runs)
        _Run(
          Segment(anchorFor(run.segment.a), anchorFor(run.segment.b)),
          run.strokeId,
        ),
    ];

    // Anchors moved while welding, so read them back to their final places.
    Vec2 settled(Vec2 point) {
      for (final anchor in anchors) {
        if (anchor.distanceTo(point) <= tolerance) return anchor;
      }
      return point;
    }

    return [
      for (final run in welded)
        if (settled(run.segment.a).distanceTo(settled(run.segment.b)) >=
            Tol.minLineMm)
          _Run(
            Segment(settled(run.segment.a), settled(run.segment.b)),
            run.strokeId,
          ),
    ];
  }

  static double _spanOf(List<_Run> runs) {
    var left = double.infinity, right = -double.infinity;
    var top = double.infinity, bottom = -double.infinity;
    for (final run in runs) {
      for (final p in [run.segment.a, run.segment.b]) {
        left = math.min(left, p.x);
        right = math.max(right, p.x);
        top = math.min(top, p.y);
        bottom = math.max(bottom, p.y);
      }
    }
    final w = right - left, h = bottom - top;
    return math.sqrt(w * w + h * h);
  }

  /// True when a run is part of the outline rather than a line inside it.
  ///
  /// Tested along the whole run, not just at its ends, because a run that
  /// starts and finishes on the boundary can still cut straight across the
  /// middle — a diagonal from one corner to another does exactly that.
  static bool _liesOn(Segment run, Polygon outline, double tolerance) {
    const samples = 9;
    for (var i = 0; i <= samples; i++) {
      final point = run.pointAt(i / samples);
      var nearest = double.infinity;
      for (final edge in outline.edges) {
        nearest = math.min(nearest, edge.distanceTo(point));
      }
      if (nearest > tolerance) return false;
    }
    return true;
  }

  /// A frame profile in proportion to the opening, as a starting point the
  /// user can change. Sixty millimetres on a normal window, less on a very
  /// small one, so the drawing never comes back as solid frame.
  static double _profileFor(Polygon outline) {
    final smallest = math.min(outline.width, outline.height);
    return math.max(20.0, math.min(60.0, smallest * 0.06));
  }
}

class _Run {
  final Segment segment;
  final String strokeId;
  const _Run(this.segment, this.strokeId);
}

class _Placed {
  final Design design;
  final List<DesignQuestion> questions;
  const _Placed(this.design, this.questions);
}
