import '../dimensions/units.dart';
import '../geometry/segment.dart';
import '../geometry/tolerances.dart';
import '../model/design.dart';
import '../model/elements.dart';
import '../text/names.dart';
import '../text/words.dart';
import 'geometry_validation.dart';

/// One problem the validator found, said in words the user can act on.
///
/// The problem is [GeometryValidation]'s own and nothing here second-guesses
/// it: this only names the part it is about — *the head*, *a line inside
/// Opening 1*, *the dimension you gave as 150 cm* — never an id or a class,
/// and says which parts to show when the user asks where it is.
class GeometryNotice {
  final GeometryProblem problem;

  /// What is wrong, naming the part it is wrong with, in a language.
  final String Function(Words w) say;

  /// What is wrong, in English.
  String get message => say(const EnglishWords());

  /// What is wrong, in [w].
  String messageIn(Words w) => say(w);

  /// The parts to light up on the drawing when the user asks to be shown —
  /// for a moment, never stored in the design. Empty where there is nothing
  /// that can be drawn, such as a point that is not a number.
  final Set<String> showIds;

  const GeometryNotice({
    required this.problem,
    required this.say,
    required this.showIds,
  });

  GeometryProblemSeverity get severity => problem.severity;
  bool get isError => problem.isError;
}

/// What the user is told about an Angled / Asymmetrical design's geometry.
///
/// **Worked out from the design, never kept beside it.** An angled design is
/// checked rather than squared, and the check was made on every reading
/// and then put away unseen. [of] runs the one validator,
/// [GeometryValidation.of], on the design as it now is, so what is said is
/// always about the geometry on the screen. Put the geometry right — by
/// drawing and reading again, by dragging a line, by undoing — and the
/// design is a new design, checked afresh, and the problem is simply gone.
/// There is no stored list for a stale problem to outlive.
///
/// **It says; it never mends.** Nothing here moves, squares, equalises or
/// deletes anything: an angled design's slopes are meant, and a problem in
/// one is the user's to put right on their own drawing.
///
/// **Angled designs only.** A standard design is squared by the
/// normaliser, which says so in its own quiet way; this is the category's
/// [GeometryPolicy.preserve], and nothing else about the category is asked.
class GeometryFeedback {
  final List<GeometryNotice> notices;

  const GeometryFeedback._(this.notices);

  static const none = GeometryFeedback._([]);

  bool get isEmpty => notices.isEmpty;
  bool get isNotEmpty => notices.isNotEmpty;
  bool get hasErrors => notices.any((n) => n.isError);
  int get errors => notices.where((n) => n.isError).length;
  int get warnings => notices.length - errors;

  /// The heading: an error needs attention; a warning may need review.
  String get title => titleIn(const EnglishWords());

  /// [title], in [w].
  String titleIn(Words w) => hasErrors ? w.gfTitleAttention : w.gfTitleReview;

  /// What the heading means, in a sentence.
  String get summary => summaryIn(const EnglishWords());

  /// [summary], in [w].
  String summaryIn(Words w) =>
      hasErrors ? w.gfSummaryError : w.gfSummaryWarning;

  // A design is immutable, so its check is worked out once and kept with
  // the object itself; an edit is a new design and is checked afresh.
  static final _checked = Expando<GeometryFeedback>();

  /// What to tell the user about [design]'s geometry: nothing for a
  /// standard design, and for an angled one every problem the validator
  /// finds, errors first.
  static GeometryFeedback of(Design design) {
    if (design.kind.geometryPolicy != GeometryPolicy.preserve) return none;
    return _checked[design] ??= _feedbackOn(design);
  }

  static GeometryFeedback _feedbackOn(Design design) {
    final problems = GeometryValidation.of(design);
    if (problems.isEmpty) return none;
    final notices = [for (final p in problems) _noticeOf(design, p)]
      ..sort(
        (a, b) => b.severity.index.compareTo(a.severity.index),
      ); // errors first, in the validator's own order within each.
    return GeometryFeedback._(List.unmodifiable(notices));
  }

  static GeometryNotice _noticeOf(Design design, GeometryProblem problem) {
    final element = design.elementById(problem.elementId);
    var show = element == null ? <String>{} : {problem.elementId};
    String name(Words w) => _capital(_nameOf(w, design, element));
    final String Function(Words w) say;

    switch (problem.kind) {
      case GeometryProblemKind.coordinate:
        // A point that is not a number cannot be drawn to be shown.
        show = {};
        say = (w) => w.gfNotANumber(name(w));
      case GeometryProblemKind.boundary:
        say = element is FrameElement
            ? (w) => w.gfFrameEnclosesNothing
            : (w) => w.gfEnclosesNothing(name(w));
      case GeometryProblemKind.selfIntersection:
        if (element is FrameElement) {
          final crossing = _crossingSides(design);
          if (crossing != null) {
            final (a, b) = crossing;
            show = {a.id, b.id};
            say = a.placement == b.placement
                ? (w) => w.gfSidesCross
                : (w) => w.gfSideCrosses(
                    placementIn(w, a.placement).toLowerCase(),
                    placementIn(w, b.placement).toLowerCase(),
                  );
          } else {
            say = (w) => w.gfFrameTouchesItself;
          }
        } else {
          say = (w) => w.gfCrossesItself(name(w));
        }
      case GeometryProblemKind.disconnected:
        say = element is DividerElement
            ? (w) => w.gfNotConnected(name(w))
            : (w) => w.gfOutsideFrame(name(w));
      case GeometryProblemKind.child:
        String within(Words w) => switch (element) {
          DividerElement(:final parentId) ||
          SectionElement(:final parentId) ||
          HardwareElement(:final parentId) => _parentName(w, design, parentId),
          _ => w.gfPartItBelongsTo,
        };
        say = switch (element) {
          HardwareElement() => (w) => w.gfNotOnLeaf(name(w)),
          SectionElement() => (w) => w.gfLiesOutside(name(w), within(w)),
          _ => (w) => w.gfReachesOutside(name(w), within(w)),
        };
      case GeometryProblemKind.opening:
        final region = element is OpeningElement
            ? design.sectionById(element.sectionId)
            : null;
        say = region == null
            ? (w) => w.gfLostRegion(name(w))
            : (w) => w.gfMarkOutside(_lower(_nameOf(w, design, element)));
      case GeometryProblemKind.dimension:
        say = switch (element) {
          DimensionElement(:final measuredMm)
              when measuredMm <= Tol.samePointMm =>
            (w) => w.gfDimensionNothing,
          DimensionElement(:final statedMm?) when statedMm <= 0 => (
            w,
          ) => w.gfDimensionNotSize(Units.label(statedMm)),
          DimensionElement(:final statedMm?, :final measuredMm) =>
            (w) => w.gfDimensionDisagrees(
              Units.label(statedMm),
              Units.label(measuredMm),
            ),
          _ => (w) => w.gfDimensionMismatch,
        };
    }
    return GeometryNotice(problem: problem, say: say, showIds: show);
  }

  /// The two sides of the frame that cross each other, where two do.
  static (FrameMemberElement, FrameMemberElement)? _crossingSides(
    Design design,
  ) {
    final sides = design.frameMembers;
    final n = design.frame?.outline.corners.length ?? 0;
    for (var i = 0; i < sides.length; i++) {
      for (var j = i + 1; j < sides.length; j++) {
        final a = sides[i], b = sides[j];
        final neighbours =
            (a.index - b.index).abs() == 1 ||
            (a.index - b.index).abs() == n - 1;
        if (neighbours) continue;
        if (Segment(a.run.a, a.run.b).crossing(b.run) != null) return (a, b);
      }
    }
    return null;
  }

  /// What to call [element] in a sentence: never its id, never its class.
  static String _nameOf(Words w, Design design, DesignElement? element) =>
      switch (element) {
        null => w.gfPartOfDesign,
        FrameElement() => w.gfFrame,
        FrameMemberElement(:final placement) => w.gfMemberOfFrame(
          placementIn(w, placement).toLowerCase(),
        ),
        DividerElement(:final parentId?) => w.gfLineInside(
          _parentName(w, design, parentId),
        ),
        // Its direction is not to be had from a point that is not a number.
        DividerElement(:final a, :final b)
            when !(a.x.isFinite &&
                a.y.isFinite &&
                b.x.isFinite &&
                b.y.isFinite) =>
          w.gfBar,
        DividerElement(:final isVertical) when isVertical => w.gfMullion,
        DividerElement(:final isHorizontal) when isHorizontal => w.gfTransom,
        DividerElement() => w.gfSlopedBar,
        SectionElement(:final parentId?) => w.gfPaneOf(
          _parentName(w, design, parentId),
        ),
        SectionElement(:final id) => switch (design.openings
            .where((o) => o.sectionId == id)
            .firstOrNull) {
          final opening? => w.gfRegionOf(design.plainNameOfIn(w, opening)),
          null => w.gfFixedLight,
        },
        OpeningElement() => design.plainNameOfIn(w, element),
        HardwareElement(:final kind, :final parentId) => switch (design
            .openingHolding(parentId)) {
          final opening? => w.gfPieceOf(
            kind.labelIn(w).toLowerCase(),
            design.plainNameOfIn(w, opening),
          ),
          null => w.gfPiece(kind.labelIn(w).toLowerCase()),
        },
        DimensionElement(:final statedMm?) when statedMm > 0 =>
          w.gfDimensionGiven(Units.label(statedMm)),
        DimensionElement() => w.gfDimension,
        TextElement() => w.gfNote,
        ArrowElement() => w.gfArrow,
      };

  /// What a child is inside: the opening it is the opening's, or the light.
  static String _parentName(Words w, Design design, String? parentId) =>
      switch (design.openingHolding(parentId)) {
        final opening? => design.plainNameOfIn(w, opening),
        null => w.gfLightItBelongsTo,
      };

  static String _capital(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// [s] as it reads after *The mark of*: its first letter small, unless
  /// it is a name — *Opening 2*, in any language — which keeps its own.
  static String _lower(String s) => s.isEmpty || RegExp(r'\d$').hasMatch(s)
      ? s
      : s[0].toLowerCase() + s.substring(1);
}
