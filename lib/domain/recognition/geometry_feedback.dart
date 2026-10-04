import '../dimensions/units.dart';
import '../geometry/segment.dart';
import '../geometry/tolerances.dart';
import '../model/design.dart';
import '../model/elements.dart';
import 'geometry_validation.dart';

/// One problem the validator found, said in words the user can act on.
///
/// The problem is [GeometryValidation]'s own and nothing here second-guesses
/// it: this only names the part it is about — *the head*, *a line inside
/// Opening 1*, *the dimension you gave as 150 cm* — never an id or a class,
/// and says which parts to show when the user asks where it is.
class GeometryNotice {
  final GeometryProblem problem;

  /// What is wrong, naming the part it is wrong with.
  final String message;

  /// The parts to light up on the drawing when the user asks to be shown —
  /// for a moment, never stored in the design. Empty where there is nothing
  /// that can be drawn, such as a point that is not a number.
  final Set<String> showIds;

  const GeometryNotice({
    required this.problem,
    required this.message,
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
  String get title =>
      hasErrors ? 'Geometry needs attention' : 'Geometry may need review';

  /// What the heading means, in a sentence.
  String get summary => hasErrors
      ? 'Part of this design cannot be built as it is drawn. Nothing has '
            'been changed for you — put it right on your drawing.'
      : 'This design can be built, but something in it may not be what you '
            'meant. Nothing has been changed for you.';

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
    final name = _nameOf(design, element);
    var show = element == null ? <String>{} : {problem.elementId};
    final String message;

    switch (problem.kind) {
      case GeometryProblemKind.coordinate:
        // A point that is not a number cannot be drawn to be shown.
        show = {};
        message =
            '${_capital(name)} has a point that is not a number, so it '
            'cannot be placed.';
      case GeometryProblemKind.boundary:
        message = element is FrameElement
            ? 'The frame\'s outline does not enclose a shape.'
            : '${_capital(name)} encloses no area.';
      case GeometryProblemKind.selfIntersection:
        if (element is FrameElement) {
          final crossing = _crossingSides(design);
          if (crossing != null) {
            final (a, b) = crossing;
            show = {a.id, b.id};
            final first = a.placement.toLowerCase();
            final second = b.placement.toLowerCase();
            message = first == second
                ? 'Two sides of the frame cross each other.'
                : 'The $first of the frame crosses the $second.';
          } else {
            message = 'The frame\'s outline touches itself.';
          }
        } else {
          message = '${_capital(name)} crosses itself.';
        }
      case GeometryProblemKind.disconnected:
        message = element is DividerElement
            ? '${_capital(name)} is not connected to the frame or to '
                  'another bar.'
            : '${_capital(name)} lies outside the frame.';
      case GeometryProblemKind.child:
        final within = switch (element) {
          DividerElement(:final parentId) ||
          SectionElement(:final parentId) ||
          HardwareElement(:final parentId) => _parentName(design, parentId),
          _ => 'the part it belongs to',
        };
        message = switch (element) {
          HardwareElement() => '${_capital(name)} is not on its leaf.',
          SectionElement() => '${_capital(name)} lies outside $within.',
          _ => '${_capital(name)} reaches outside $within.',
        };
      case GeometryProblemKind.opening:
        final region = element is OpeningElement
            ? design.sectionById(element.sectionId)
            : null;
        message = region == null
            ? '${_capital(name)} has lost the region it opens.'
            : 'The mark of ${_lower(name)} is outside the region it opens.';
      case GeometryProblemKind.dimension:
        message = switch (element) {
          DimensionElement(:final measuredMm)
              when measuredMm <= Tol.samePointMm =>
            'A dimension measures nothing: its two ends are at the same '
                'point.',
          DimensionElement(:final statedMm?) when statedMm <= 0 =>
            'A dimension gives ${Units.label(statedMm)}, which is not a size.',
          DimensionElement(:final statedMm?, :final measuredMm) =>
            'The dimension you gave as ${Units.label(statedMm)} no longer '
                'matches the drawing, which measures '
                '${Units.label(measuredMm)}.',
          _ => 'A dimension does not match the drawing.',
        };
    }
    return GeometryNotice(problem: problem, message: message, showIds: show);
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
  static String _nameOf(Design design, DesignElement? element) =>
      switch (element) {
        null => 'part of the design',
        FrameElement() => 'the frame',
        FrameMemberElement(:final placement) =>
          'the ${placement.toLowerCase()} of the frame',
        DividerElement(:final parentId?) =>
          'a line inside ${_parentName(design, parentId)}',
        // Its direction is not to be had from a point that is not a number.
        DividerElement(:final a, :final b)
            when !(a.x.isFinite &&
                a.y.isFinite &&
                b.x.isFinite &&
                b.y.isFinite) =>
          'a bar',
        DividerElement(:final isVertical) when isVertical => 'a mullion',
        DividerElement(:final isHorizontal) when isHorizontal => 'a transom',
        DividerElement() => 'a sloped bar',
        SectionElement(:final parentId?) =>
          'a pane of ${_parentName(design, parentId)}',
        SectionElement(:final id) => switch (design.openings
            .where((o) => o.sectionId == id)
            .firstOrNull) {
          final opening? => 'the region of ${_openingName(design, opening)}',
          null => 'a fixed light',
        },
        OpeningElement() => _openingName(design, element),
        HardwareElement(:final kind, :final parentId) => switch (design
            .openingHolding(parentId)) {
          final opening? =>
            'a ${kind.label.toLowerCase()} of '
                '${_openingName(design, opening)}',
          null => 'a ${kind.label.toLowerCase()}',
        },
        DimensionElement(:final statedMm?) when statedMm > 0 =>
          'the dimension you gave as ${Units.label(statedMm)}',
        DimensionElement() => 'a dimension',
        TextElement() => 'a note',
        ArrowElement() => 'an arrow',
      };

  /// What a child is inside: the opening it is the opening's, or the light.
  static String _parentName(Design design, String? parentId) =>
      switch (design.openingHolding(parentId)) {
        final opening? => _openingName(design, opening),
        null => 'the light it belongs to',
      };

  /// *Opening 2* — its place across the drawing, without the mark.
  static String _openingName(Design design, OpeningElement opening) {
    final number = design.numberOf(opening);
    return number > 0 ? 'Opening $number' : 'the opening';
  }

  static String _capital(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static String _lower(String s) =>
      s.startsWith('Opening') ? s : s[0].toLowerCase() + s.substring(1);
}
