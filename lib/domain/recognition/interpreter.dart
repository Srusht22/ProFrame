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

    // Every run that is not part of the outline is a line inside the design:
    // a mullion, a transom, a glazing bar. It is kept exactly where it was
    // drawn, at the angle it was drawn, and it divides the design.
    //
    // Every one of them. Nothing here works out that a line the user drew
    // was "really" inside something and quietly absorbs it: that is how an
    // opening grows to swallow a mullion, and then a whole window. A drawn
    // line is a division of the design until the user says otherwise, which
    // they do with the line tools inside an opening or with the **Divides**
    // control on the bar's own panel.
    //
    // The bars the user made inside the design rather than on the sheet are
    // not among them, and are not the sheet's to remove. A line drawn inside
    // an opening with the line tools has no stroke of its own: reading the
    // sheet again would find nothing to make it from and the opening would
    // come back one undivided pane, taking the glass and the panel with it.
    // A reading reads the drawing; what is not in the drawing it leaves
    // alone.
    final dividers = [
      for (final divider in design.dividers)
        if (divider.fromStrokeId == null) divider,
    ];

    // The bars the last reading made from these strokes, in the order it
    // made them, so each run can be paired with its own bar again.
    //
    // **A reading re-reads the drawing; it does not overturn what the user
    // said about it.** A bar built from scratch every time is a bar with a
    // new id and no parent, so saying a line is an opening's — with the
    // **Divides** control, which is the one place the drawing cannot decide
    // for itself — lasted exactly until the sheet was read again, and then
    // the line went back to cutting the whole door in half and took the
    // opening down to one side of it. Nothing in the drawing had changed.
    //
    // The pairing is by stroke and by order within it, which is how the
    // runs are made: one stroke drawn as a polyline gives its legs in the
    // same order every time.
    final madeBefore = <String, List<DividerElement>>{};
    for (final divider in design.dividers) {
      final stroke = divider.fromStrokeId;
      if (stroke == null) continue;
      madeBefore.putIfAbsent(stroke, () => []).add(divider);
    }

    final taken = {for (final divider in design.dividers) divider.id};
    String nextDividerId() {
      var id = nextId('divider');
      while (taken.contains(id)) {
        id = nextId('divider');
      }
      taken.add(id);
      return id;
    }

    for (final run in welded) {
      if (_liesOn(run.segment, outline, weld)) continue;

      final made = madeBefore[run.strokeId];
      final before = (made == null || made.isEmpty) ? null : made.removeAt(0);
      if (before != null) {
        // A bar that divides the design is a faithful copy of its stroke, so
        // it is read from the stroke again — the line is wherever the user's
        // line now is.
        //
        // A bar the user has put inside an opening is not: joining it laid
        // it right across the section it joined, because a bar that stops a
        // few millimetres short divides nothing and the face does not close.
        // Reading its ends back off the stroke would undo that and leave one
        // undivided pane with a line lying on it — moving a line the user
        // never moved. Its ends are the design's now; only the stroke's
        // going takes it away.
        dividers.add(before.parentId == null
            ? before.copyWith(a: run.segment.a, b: run.segment.b)
            : before);
        continue;
      }

      // A line drawn inside a region the design **already** opens is that
      // opening's, and only such a line.
      //
      // This is not the inference this file refuses twice over, and the
      // difference is what makes it safe. Deciding *within one reading*
      // which lines an opening contains is circular — a mullion below a `>`
      // and a rail below a `>` are the same picture turned on its side, and
      // each lies wholly within the region the mark is in once you take it
      // away — and deciding it by stroke order is worse, which
      // `only_the_marked_section_opens_test.dart` shows in five orders. Both
      // ask a reading to work out a region that depends on the answer.
      //
      // This asks nothing of the kind. The opening is already there: the
      // user marked it, saw it drawn, and then drew inside it. The region
      // is the one they were looking at, from the design as it stands
      // before this reading, and it exists whether or not this line joins
      // it. On a first reading there are no openings yet, so nothing is
      // decided, and every drawn line divides the design exactly as before.
      //
      // Only a line with room to spare counts — its own thickness clear of
      // the sash all round. A line along a jamb is bounding that region, not
      // dividing it, and belongs to whatever it separates.
      //
      // And it is the user's either way: **Divides** moves a bar in or out
      // by hand, and that now outlasts every later reading.
      final width = frame.profileMm * 0.8;
      final joined = _openingAlreadyHolding(design, run.segment, width);
      if (joined != null) {
        // Laid right across the region it has joined, as **Divides** and the
        // line tools both do: a hand-drawn line stops a few millimetres
        // short of a stile, and inside a sash that is the difference between
        // two panes and one pane with a line lying on it.
        final across =
            DesignEdits.spanAcross(joined.outline, run.segment) ?? run.segment;
        dividers.add(DividerElement(
          id: nextDividerId(),
          a: across.a,
          b: across.b,
          widthMm: width,
          finish: frame.finish,
          parentId: joined.openingId,
          fromStrokeId: run.strokeId,
        ));
        continue;
      }

      dividers.add(DividerElement(
        id: nextDividerId(),
        a: run.segment.a,
        b: run.segment.b,
        widthMm: width,
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

      // The lines the user drew their mark straight through. Taken before
      // the opening is made, because a bar's id is its own and outlasts the
      // rebuilds that follow; a section's does not.
      final through = [
        for (final bar in _barsTheMarkRunsThrough(read, symbol)) bar.id,
      ];

      final openingId = _openingIdFor(design, symbol);
      read = DesignEdits.setOpening(
        read,
        section.id,
        openingId: openingId,
        mechanism: symbol.mechanism,
        markAt: symbol.centre,
        markGlyph: symbol.glyph,
        fromStrokeId: symbol.strokeId,
      );

      // Each of those lines is inside what the mark opens, by the same route
      // the **Divides** control takes — so nothing arrives inside a section
      // that the user could not have put there by hand, and what the design
      // accepts is exactly what it would have offered them.
      for (final barId in through) {
        final opening = read.openingById(openingId);
        if (opening == null) break;
        read = DesignEdits.setDividerParent(read, barId, opening.sectionId);
      }
    }

    return _Placed(read, questions);
  }

  /// The bars the user drew their mark **through**.
  ///
  /// A mark says which region opens. Drawn right through a line of their
  /// own, it says something more: that the line is inside the thing being
  /// marked. A door with a rail across it and a `>` drawn over the whole
  /// leaf is one leaf with a rail in it, and reading it as two lights with
  /// only the lower one opening is not the drawing.
  ///
  /// **This is not the inference this file refuses twice over.** Those ask a
  /// reading to work out, from the lines alone, which side of a bar the mark
  /// meant — and a mullion below a `>` and a rail below a `>` are the same
  /// picture turned on its side, so containment takes both or neither, and
  /// stroke order helps itself to the window. Nothing is worked out here.
  /// The user drew one mark through the other. The two touch on the sheet,
  /// and where they touch is the whole of the test.
  ///
  /// **Through, not into** — and that is the difference between this and a
  /// hand straying over a mullion, which is the case
  /// `the_mark_picks_one_face_test.dart` holds: a `>` whose point pokes six
  /// millimetres past a mullion and stops there is in the light it was drawn
  /// in, and the mullion is nothing to do with it. So the arm that crosses
  /// the bar has to carry on out of whatever is on the far side rather than
  /// ending inside it, which `Polygon.holds` — this repository's one
  /// containment test — answers. It is a relationship and not a size: a mark
  /// that runs off the far edge of a light does so whether the light is a
  /// hand's width or three metres.
  static List<DividerElement> _barsTheMarkRunsThrough(
    Design design,
    OpeningSymbol symbol,
  ) {
    final arms = [
      Segment(symbol.apex, symbol.armA),
      Segment(symbol.apex, symbol.armB),
    ];
    final faces = design.topLevelSections;

    final through = <DividerElement>[];
    for (final bar in design.topLevelDividers) {
      final here = bar.segment.direction.cross(symbol.centre - bar.a);
      if (here.abs() <= Tol.samePointMm) continue;

      for (final arm in arms) {
        final crossing = bar.segment.crossing(arm);
        if (crossing == null) continue;

        // The end of the arm on the other side of the bar from the mark's
        // own middle, and the region it goes into — picked up just past the
        // bar's own material rather than at its centre line, which is inside
        // the bar and in no region at all.
        final away = bar.segment.direction.cross(arm.b - bar.a) * here < 0
            ? arm.b
            : arm.a;
        final beyond = Segment(crossing.at, away);
        if (beyond.length < Tol.minLineMm) continue;

        final entering =
            crossing.at + beyond.unit * (bar.widthMm + Tol.minLineMm);
        SectionElement? far;
        for (final face in faces) {
          if (face.outline.contains(entering)) far = face;
        }

        // Nothing over there, or the arm stopped inside it. Running *into* a
        // region is a hand straying over a line; running *through* it is the
        // user drawing their mark across the thing they mean.
        if (far == null) continue;
        if (far.outline.contains(away)) continue;

        through.add(bar);
        break;
      }
    }
    return through;
  }

  /// The id the opening carries, which is the same one every time the sheet
  /// is read.
  ///
  /// An opening is what the user authored by drawing the mark, so its id is
  /// the mark's and not a number from a counter. Things drawn inside an
  /// opening name it as their parent, and a fresh id on every reading would
  /// orphan every one of them — a line the user drew inside a sash would
  /// come back dividing the window, which is the design changing itself.
  /// The opening already on that stroke is kept where there is one, so an id
  /// the user has been working with never changes underneath them.
  static String _openingIdFor(Design design, OpeningSymbol symbol) {
    for (final opening in design.openings) {
      if (opening.fromStrokeId == symbol.strokeId) return opening.id;
    }
    return 'opening-${symbol.strokeId}';
  }

  /// The section a mark opens.
  ///
  /// The mark is an instruction, not a puzzle: the user has already said
  /// which section opens by drawing the mark in it, so this works out which
  /// one that is rather than asking them to say it again.
  ///
  /// **The smallest region holding the mark is the opening, and nothing
  /// larger ever is.** The user's own lines cut the daylight into regions;
  /// the mark falls in one of them; that one opens and every other stays
  /// fixed. A window is not an opening because a mark was drawn somewhere
  /// inside it, and an opening never grows to take in a neighbour. Being
  /// wrong the other way is cheap — the user marks another section — but an
  /// opening that swallowed a fixed light is a leaf that swings in a window
  /// somebody has to build.
  ///
  /// **Containment decides it, and nothing else does.** The mark's middle is
  /// a point; the design's own lines cut the daylight into closed faces; the
  /// answer is the smallest face that point is inside. Where the middle
  /// lands on a bar — inside no face at all — the face holding most of the
  /// rest of the mark takes it, which is still containment, of the mark's
  /// other points. Where no face holds any part of it, there is no opening.
  ///
  /// Nothing here falls back to the nearest section, the first section, the
  /// largest one, the outer rectangle or a bounding box. Each of those can
  /// name a face the mark is not in, which is the whole failure this rule
  /// exists to prevent: a mark in one light opening a window somebody has to
  /// build.
  ///
  /// *Smallest*, not first. The main divisions tile the daylight without
  /// overlapping, so in the ordinary case exactly one face holds the point
  /// and smallest-of-one is that face. Two can hold it when the point lands
  /// on the line between them, because a point on a boundary is in the
  /// shapes either side of it; taking the smaller is then a real choice, and
  /// it is the one that cannot make an opening too big.
  ///
  /// The faces are the ones the *design's own lines* make. The panes inside
  /// an opening are not among them: a pane is a region of the opening, not
  /// of the design, and it exists only because that section is already an
  /// opening and the user drew inside it. Offering them would have a reading
  /// reinterpret its own output — the mark that opened a 40 × 160 sash would,
  /// next time the sheet was read, be found inside the 40 × 40 pane of glass
  /// it had caused, and the sash the user built would shrink to it.
  static SectionElement? sectionFor(Design design, OpeningSymbol symbol) {
    final faces = design.topLevelSections;
    if (faces.isEmpty) return null;

    final holding = [
      for (final face in faces)
        if (face.outline.contains(symbol.centre)) face,
    ];
    if (holding.isNotEmpty) return _smallest(holding);

    // The middle landed on a bar. The mark is still drawn in a face — its
    // point and its two ends say which — so the one holding most of it takes
    // it, and the smallest of those where several hold the same number.
    var most = 0;
    var best = <SectionElement>[];
    for (final face in faces) {
      var held = 0;
      for (final point in symbol.points) {
        if (face.outline.contains(point)) held++;
      }
      if (held == 0) continue;
      if (held > most) {
        most = held;
        best = [face];
      } else if (held == most) {
        best.add(face);
      }
    }
    if (best.isNotEmpty) return _smallest(best);

    // No face holds any part of the mark. There is nothing to open, and
    // guessing at the nearest one would open a section the user did not mark.
    return null;
  }

  /// The smallest of [faces] by area — the one that cannot be too big.
  static SectionElement _smallest(List<SectionElement> faces) {
    var smallest = faces.first;
    for (final face in faces) {
      if (face.areaMmSq < smallest.areaMmSq) smallest = face;
    }
    return smallest;
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
  /// The opening [design] already has whose region holds [line] with room
  /// to spare, or null when the line is in none of them.
  ///
  /// Read from the design as it stands, *before* this reading rebuilds it,
  /// so the region is the one the user was looking at when they drew. The
  /// margin is the bar's own thickness: a line closer than that to an edge
  /// is running along it rather than dividing what is inside.
  static ({String openingId, Polygon outline})? _openingAlreadyHolding(
    Design design,
    Segment line,
    double widthMm,
  ) {
    for (final opening in design.openings) {
      final section = design.sectionById(opening.sectionId);
      if (section == null || section.outline.isEmpty) continue;
      final room = section.outline.inset(math.max(widthMm, Tol.minLineMm));
      if (room.isEmpty || room.area <= 0) continue;
      if (!room.holds(line)) continue;
      return (openingId: opening.id, outline: section.outline);
    }
    return null;
  }

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
