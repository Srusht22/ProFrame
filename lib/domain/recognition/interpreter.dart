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

    // Every run that is not part of the outline is a line inside the design:
    // a mullion, a transom, a glazing bar. It is kept exactly where it was
    // drawn, at the angle it was drawn.
    final dividers = <DividerElement>[];
    for (final run in welded) {
      if (_liesOn(run.segment, outline, weld)) continue;
      dividers.add(DividerElement(
        id: nextId('divider'),
        a: run.segment.a,
        b: run.segment.b,
        widthMm: frame.profileMm * 0.8,
        finish: frame.finish,
        fromStrokeId: run.strokeId,
      ));
    }

    var read = design.copyWith(frame: frame, dividers: dividers);
    read = SectionBuilder.rebuild(read, newId: newId);

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

    final questions = <DesignQuestion>[
      ...placed.questions,
      ..._openingQuestions(read, fits, outline),
      ..._scaleQuestion(read),
    ];

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
      final holding = <SectionElement>[];
      for (final section in read.sections) {
        if (symbol.points.every(section.outline.contains)) {
          holding.add(section);
        }
      }

      if (holding.length == 1) {
        read = DesignEdits.setOpening(
          read,
          holding.single.id,
          openingId: nextId('opening'),
          mechanism: symbol.mechanism,
          markAt: symbol.centre,
          markGlyph: symbol.glyph,
          fromStrokeId: symbol.strokeId,
        );
        continue;
      }

      // Not certain. Every section the mark touches at all is offered, so
      // the user picks rather than the application guessing.
      final touched = <SectionElement>[
        for (final section in read.sections)
          if (symbol.points.any(section.outline.contains)) section,
      ];
      final choices = touched.isEmpty ? read.sections : touched;

      questions.add(DesignQuestion(
        id: 'symbol-${symbol.strokeId}',
        prompt: 'Which section does this ${symbol.glyph} belong to?',
        detail: touched.isEmpty
            ? 'The mark is not inside any one section, so nothing has been '
                'opened. Say which section you meant.'
            : 'The mark crosses more than one section, so nothing has been '
                'opened. Say which section you meant.',
        aboutIds: [symbol.strokeId, for (final s in choices) s.id],
        options: [
          for (final section in choices)
            QuestionOption(
              key: section.id,
              label: _describe(section, read),
              detail: 'Open this one, ${symbol.meaning}.',
            ),
          const QuestionOption(
            key: 'not-a-symbol',
            label: 'It is not an opening mark',
            detail: 'Build it as lines, exactly where it was drawn.',
          ),
        ],
      ));
    }

    return _Placed(read, questions);
  }

  /// A section named the way somebody would point at it.
  static String _describe(SectionElement section, Design design) {
    final frame = design.frame;
    final where = StringBuffer();
    if (frame != null) {
      final middleY = (frame.outline.top + frame.outline.bottom) / 2;
      final middleX = (frame.outline.left + frame.outline.right) / 2;
      final centre = section.outline.centroid;
      final rows = design.sections.map((s) => s.outline.top.round()).toSet();
      final columns =
          design.sections.map((s) => s.outline.left.round()).toSet();
      if (rows.length > 1) {
        where.write(centre.y < middleY ? 'upper ' : 'lower ');
      }
      if (columns.length > 1) {
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

  /// Asks about anything that looks like an opening symbol.
  ///
  /// A line drawn at an angle across a pane is how an opening is marked on
  /// an elevation — but the same line could be a glazing bar somebody wants
  /// built. The reading treats it as a bar, because that is what a line is,
  /// and asks. Saying it marks an opening takes the bar out again and makes
  /// the pane open; saying it is a bar leaves it exactly where it is.
  static List<DesignQuestion> _openingQuestions(
    Design design,
    List<StrokeFit> fits,
    Polygon outline,
  ) {
    final questions = <DesignQuestion>[];
    for (final divider in design.dividers) {
      if (divider.isVertical || divider.isHorizontal) continue;
      if (divider.segment.offAxisDegrees <= Tol.axisSnapDegrees * 3) continue;

      questions.add(DesignQuestion(
        id: 'opening-bar-${divider.id}',
        prompt: 'Is this diagonal line a bar, or does it mark an opening?',
        detail: 'It is being built as a bar, exactly where you drew it. On a '
            'drawing a diagonal often means the panel opens instead. Say '
            'which you meant.',
        aboutIds: [divider.id, ?divider.fromStrokeId],
        options: [
          QuestionOption(
            key: OpeningMechanism.hingedLeft.name,
            label: 'Opens — ${OpeningMechanism.hingedLeft.label.toLowerCase()}',
            detail: '${OpeningMechanism.hingedLeft.description}. The line is '
                'removed and the panel becomes one opening leaf.',
          ),
          QuestionOption(
            key: OpeningMechanism.hingedRight.name,
            label:
                'Opens — ${OpeningMechanism.hingedRight.label.toLowerCase()}',
            detail: '${OpeningMechanism.hingedRight.description}. The line is '
                'removed and the panel becomes one opening leaf.',
          ),
          QuestionOption(
            key: OpeningMechanism.topHung.name,
            label: 'Opens — ${OpeningMechanism.topHung.label.toLowerCase()}',
            detail: '${OpeningMechanism.topHung.description}. The line is '
                'removed and the panel becomes one opening leaf.',
          ),
          const QuestionOption(
            key: 'keep-line',
            label: 'It is a bar',
            detail: 'Keep the line exactly where it is, as part of the design.',
          ),
        ],
      ));
    }
    return questions;
  }

  /// Asks for a real size once, so the design is in millimetres rather than
  /// in whatever the drawing happened to be.
  static List<DesignQuestion> _scaleQuestion(Design design) {
    if (design.dimensions.any((d) => d.isStated)) return const [];
    final frame = design.frame;
    if (frame == null) return const [];
    return [
      DesignQuestion(
        id: 'scale',
        prompt: 'How wide is this, really?',
        detail: 'The drawing is currently ${frame.widthMm.round()} mm by '
            '${frame.heightMm.round()} mm, taken straight from the shapes you '
            'drew. Give it a real width and everything scales with it, in '
            'proportion. Nothing moves relative to anything else.',
        aboutIds: [frame.id],
        options: const [
          QuestionOption(key: 'type', label: 'Type the width'),
          QuestionOption(
            key: 'keep',
            label: 'Leave it as drawn',
            detail: 'Carry on in the size the drawing already has.',
          ),
        ],
      ),
    ];
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
