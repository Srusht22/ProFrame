import 'dart:math' as math;

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

  const Interpretation({
    required this.design,
    this.questions = const [],
    this.unusedStrokeIds = const [],
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
  static Interpretation interpret(Design design, {String Function()? newId}) {
    final structural = [
      for (final stroke in design.sketch.strokes)
        if (_isStructural(stroke)) stroke,
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

    final questions = <DesignQuestion>[
      ..._openingQuestions(read, fits, outline),
      ..._scaleQuestion(read),
    ];

    final usedStrokes = {
      for (final run in welded) run.strokeId,
    };
    return Interpretation(
      design: read,
      questions: questions,
      unusedStrokeIds: [
        for (final stroke in structural)
          if (!usedStrokes.contains(stroke.id)) stroke.id,
      ],
    );
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
  /// A diagonal or a chevron drawn across a section is how an opening is
  /// marked on a drawing, but the same mark could be a glazing bar. The
  /// reading never decides: it says what it saw and lets the user say what
  /// they meant.
  static List<DesignQuestion> _openingQuestions(
    Design design,
    List<StrokeFit> fits,
    Polygon outline,
  ) {
    final questions = <DesignQuestion>[];
    for (final section in design.sections) {
      final marks = <StrokeFit>[];
      for (final fit in fits) {
        if (fit.kind == FitKind.mark || fit.isClosed) continue;
        final inside = fit.segments.where((s) =>
            section.outline.contains(s.midpoint) &&
            s.offAxisDegrees > Tol.axisSnapDegrees * 3);
        if (inside.isNotEmpty) marks.add(fit);
      }
      if (marks.isEmpty) continue;

      questions.add(DesignQuestion(
        id: 'opening-${section.id}',
        prompt: 'Does this section open?',
        detail: 'There is a diagonal mark across it. On a drawing that '
            'usually means an opening, but it could be a bar you meant to '
            'keep. Nothing has been decided.',
        aboutIds: [
          section.id,
          for (final mark in marks) mark.stroke.id,
        ],
        options: [
          QuestionOption(
            key: OpeningMechanism.hingedLeft.name,
            label: OpeningMechanism.hingedLeft.label,
            detail: OpeningMechanism.hingedLeft.description,
          ),
          QuestionOption(
            key: OpeningMechanism.hingedRight.name,
            label: OpeningMechanism.hingedRight.label,
            detail: OpeningMechanism.hingedRight.description,
          ),
          QuestionOption(
            key: OpeningMechanism.topHung.name,
            label: OpeningMechanism.topHung.label,
            detail: OpeningMechanism.topHung.description,
          ),
          const QuestionOption(
            key: 'keep-line',
            label: 'No — it is a bar',
            detail: 'Keep the line exactly where it is as part of the design.',
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
