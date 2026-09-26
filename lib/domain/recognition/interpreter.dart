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

    // **In a sliding design an arrow is a mark.** `<-` and `->` are how a
    // sliding panel is drawn — the head says it opens, the shaft behind it
    // says which way it runs — and the shaft is part of the mark, not a line
    // to build. Built as a bar it would be a member hanging loose in the
    // middle of a light that nobody drew one in.
    if (design.kind.slides) {
      for (var i = 0; i < symbols.length; i++) {
        for (final stroke in design.sketch.strokes) {
          if (!_isStructural(stroke) || symbolStrokes.contains(stroke.id)) {
            continue;
          }
          final shaft = _shaftOf(symbols[i], stroke);
          if (shaft == null) continue;
          symbols[i] = symbols[i].withShaft(shaft, stroke.id);
          symbolStrokes.add(stroke.id);
          break;
        }
      }
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

    final welded = _weld(_ontoWhatTheyWereDrawnOn(runs, {
      for (final fit in fits) fit.stroke.id: fit.stroke,
    }));
    final span = _spanOf(welded);
    final weld = Tol.weldFor(span);
    final shape = PlanarSubdivision.subdivide(
      [for (final r in welded) r.segment],
      weldTolerance: weld,
      minAreaMmSq: math.max(Tol.minSectionAreaMmSq, weld * weld * 4),
    );

    var outline = shape.outline?.simplified(weld);
    var openEdges = const <int>{};
    // A shape can close and still not be the shape the user drew: a transom
    // near the head closes the strip above it, and the jambs hang on below
    // with nothing across their feet. That is an outline with its bottom
    // left open, and it is asked about like one.
    final gap = _gapIn(welded, weld);
    final gapIsTheSide = gap != null &&
        (outline == null ||
            outline.isEmpty ||
            gap.closes.area - outline.area >
                gap.closes.area * Tol.openSideFraction);
    if (outline == null || outline.isEmpty || gapIsTheSide) {
      // **One side missing is not the same as no shape.** A head and two
      // jambs with nothing across the foot is how a door frame is very
      // often built, and it is also how an outline looks before it is
      // finished. The drawing cannot say which, so the user is asked — and
      // once they have said, the outline is read with that side across it,
      // carrying a member or not as they said.
      final said = design.outlineGap;
      if (!gapIsTheSide || said == null) {
        return _unclosed(
          design,
          welded,
          structural,
          gap: gapIsTheSide ? gap : null,
        );
      }
      final closed = PlanarSubdivision.subdivide(
        [for (final r in welded) r.segment, gap.segment],
        weldTolerance: weld,
        minAreaMmSq: math.max(Tol.minSectionAreaMmSq, weld * weld * 4),
      ).outline?.simplified(weld);
      if (closed == null || closed.isEmpty) {
        return _unclosed(design, welded, structural);
      }
      outline = closed;
      if (said == OutlineGap.leaveOpen) {
        final edges = closed.edges;
        openEdges = {
          for (var i = 0; i < edges.length; i++)
            if (gap.segment.distanceTo(edges[i].a) <= weld &&
                gap.segment.distanceTo(edges[i].b) <= weld)
              i,
        };
      }
    }

    var counter = 0;
    String nextId(String prefix) =>
        newId?.call() ?? '$prefix-${design.id}-${counter++}';

    final frame = FrameElement(
      id: design.frame?.id ?? nextId('frame'),
      outline: outline,
      profileMm: design.frame?.profileMm ?? _profileFor(outline),
      finish: design.frame?.finish ?? Finish.frameDefault,
      openEdges: openEdges,
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

    // What a line of the design the user stopped short can be finished to:
    // the design's own lines and nothing of an opening's. See `_completed`.
    //
    // **Where the user started a line decides whose it is, and that is
    // decided first** — the user's words: *before completing any line,
    // determine where the user started it. Inside Opening #1, it is
    // Opening #1's; inside the main design and outside every opening, it is
    // the main design's. Not the nearest line, not the largest rectangle,
    // not the drawing's bounds: the starting point.* So every new line is
    // given its scope here, by `_scopeOf`, before any line is completed,
    // and each is then completed inside its own scope and against its own
    // scope's lines only — an opening's line against the opening's edge and
    // the opening's other lines, a line of the design against the outline
    // and the design's other lines, never through an opening.
    //
    // A line re-read from a bar the last reading made keeps the scope that
    // bar has: a reading re-reads the drawing, it does not overturn what was
    // settled about it. On a first reading there are no openings, so every
    // line is the design's, exactly as before.
    final width = frame.profileMm * 0.8;
    final memberMm = frame.profileMm + weld;
    final regionOf = <String, Polygon>{
      for (final opening in design.openings)
        if (design.sectionById(opening.sectionId) case final section?)
          opening.id: section.outline,
    };
    final pairing = {
      for (final entry in madeBefore.entries) entry.key: [...entry.value],
    };
    final scoped = <({_Run run, DividerElement? before, String? scope})>[];
    for (final run in welded) {
      if (_liesOn(run.segment, outline, weld)) continue;
      final made = pairing[run.strokeId];
      final before = (made == null || made.isEmpty) ? null : made.removeAt(0);
      scoped.add((
        run: run,
        before: before,
        scope: before != null
            ? design.openingHolding(before.parentId)?.id
            : _scopeOf(design, run.segment, width, memberMm),
      ));
    }

    // Each scope's own lines: what a line in it can be completed to.
    List<Segment> linesOf(String? scope) => [
      for (final p in scoped)
        if (p.scope == scope)
          p.before != null && p.before!.parentId != null
              ? Segment(p.before!.a, p.before!.b)
              : p.run.segment,
      for (final d in dividers)
        if (design.openingHolding(d.parentId)?.id == scope) Segment(d.a, d.b),
    ];
    final designBoundaries = [...outline.edges, ...linesOf(null)];
    final openingBoundaries = {
      for (final entry in regionOf.entries)
        entry.key: [...entry.value.edges, ...linesOf(entry.key)],
    };
    // The regions the design already opens: a line of the design is never
    // completed through one of them.
    final opened = regionOf.values.toList();

    for (final (:run, :before, :scope) in scoped) {
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
        if (before.parentId != null) {
          dividers.add(before);
        } else {
          final completed = _completed(
            run.segment,
            designBoundaries,
            outline,
            weld,
            opened: opened,
          );
          dividers.add(before.copyWith(a: completed.a, b: completed.b));
        }
        continue;
      }

      if (scope != null) {
        // A line started in a region the design **already** opens is that
        // opening's, and only such a line.
        //
        // This is not the inference this file refuses twice over, and the
        // difference is what makes it safe. Deciding *within one reading*
        // which lines an opening contains is circular — a mullion below a
        // `>` and a rail below a `>` are the same picture turned on its
        // side, and each lies wholly within the region the mark is in once
        // you take it away — and deciding it by stroke order is worse, which
        // `only_the_marked_section_opens_test.dart` shows in five orders.
        // Both ask a reading to work out a region that depends on the
        // answer. This asks nothing of the kind: the opening is already
        // there, the user saw it drawn and then drew in it, and the region
        // is the one they were looking at, from the design as it stands
        // before this reading.
        //
        // It is completed within the opening, to the opening's edge or the
        // first of the opening's own lines it meets, and no further: the
        // opening is not expanded, moved or resized. And it is the user's
        // either way: **Divides** moves a bar in or out by hand, and that
        // outlasts every later reading.
        final region = regionOf[scope]!;
        final within = _completedWithin(
          run.segment,
          region,
          openingBoundaries[scope]!,
          weld,
        );
        dividers.add(
          DividerElement(
            id: nextDividerId(),
            a: within.a,
            b: within.b,
            widthMm: width,
            finish: frame.finish,
            parentId: scope,
            fromStrokeId: run.strokeId,
          ),
        );
        continue;
      }

      final completed = _completed(
        run.segment,
        designBoundaries,
        outline,
        weld,
        opened: opened,
      );
      dividers.add(
        DividerElement(
          id: nextDividerId(),
          a: completed.a,
          b: completed.b,
          widthMm: width,
          finish: frame.finish,
          fromStrokeId: run.strokeId,
        ),
      );
    }

    var read = design.copyWith(frame: frame, dividers: dividers);
    read = SectionBuilder.rebuild(read, newId: newId);

    // Two sliding panels drawn in one light: they meet between the marks.
    if (design.kind.slides) {
      final meetings = _meetingsOf(read, symbols, width: frame.profileMm * 0.8);
      if (meetings.isNotEmpty) {
        read = SectionBuilder.rebuild(
          read.copyWith(dividers: [...read.dividers, ...meetings]),
          newId: newId,
        );
      }
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
      // The lines the user drew their mark straight through, and the design
      // with them stood aside.
      //
      // **A line the mark runs through is inside what the mark opens, so it
      // is not one of the edges of it** — and the region has to be read that
      // way round. Read the other way, a `>` drawn over a whole door came
      // back opening whichever quarter of it the mark's middle happened to
      // land in: the rail and the upright the user had drawn their mark
      // across were still cutting the door up, so the smallest region
      // holding the mark was a quarter of it, and the rail could not then go
      // inside that quarter, because it runs the width of the door. Which
      // quarter it was depended on where they had drawn the upright, so the
      // same mark on the same door meant two different things. Standing
      // those lines aside first makes the region the mark's own, and they go
      // back into it afterwards by the ordinary route.
      final through = [
        for (final bar in _barsTheMarkRunsThrough(read, symbol)) bar.id,
      ];
      final stood = [
        for (final bar in read.dividers)
          if (through.contains(bar.id)) bar,
      ];
      final choosing = stood.isEmpty
          ? read
          : SectionBuilder.rebuild(read.copyWith(dividers: [
              for (final bar in read.dividers)
                if (!through.contains(bar.id)) bar,
            ]));

      final section = sectionFor(choosing, symbol);

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

      final openingId = _openingIdFor(design, symbol);

      // **A reading re-reads the drawing; it does not overturn what the user
      // said about it.** The mark says which way a leaf opens the first time
      // it is read. After that the user may have changed it on the opening's
      // panel — hinged the other side, made it bottom hung, made it open
      // outward — and a mark still saying exactly what it said then is not
      // a new instruction: it is the same mark, read again. So the answer
      // they gave stands. Reading it back off the mark undid every such
      // change the moment the sheet was read again, which made the Direction
      // control look as though it had not worked.
      //
      // A mark rubbed out and drawn afresh is a new stroke, and a new
      // stroke is a new opening, so what it says is the instruction again.
      final before = design.openingById(openingId);
      final sameMark = before != null && before.markGlyph == symbol.glyph;
      read = DesignEdits.setOpening(
        choosing,
        section.id,
        openingId: openingId,
        mechanism: sameMark ? before.mechanism : _said(design, symbol),
        direction: sameMark ? before.direction : OpeningDirection.inward,
        markAt: symbol.centre,
        markGlyph: symbol.glyph,
        fromStrokeId: symbol.strokeId,
      );

      // Each of those lines goes back into what the mark opens, by the same
      // route the **Divides** control takes — so nothing arrives inside a
      // section that the user could not have put there by hand, and what
      // the design accepts is exactly what it would have offered them.
      //
      // One at a time, because a line that has gone in is a line that no
      // longer divides the design, and the next is offered the region that
      // leaves. A line the design will not take goes back to dividing it, as
      // it was: a line the user drew is never lost.
      for (final bar in stood) {
        final opening = read.openingById(openingId);
        if (opening == null) break;
        read = DesignEdits.setDividerParent(
          read.copyWith(dividers: [
            ...read.dividers,
            bar.copyWith(clearParent: true),
          ]),
          bar.id,
          opening.sectionId,
        );
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
  /// the bar has to get across whatever is on the far side rather than
  /// stopping in the middle of it — its end nearer the far side of that
  /// light than the bar it came in over. It is a relationship and not a
  /// size: two distances the drawing itself gives, so a mark crosses a
  /// light whether that light is a hand's width or three metres.
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
      // How far each point lies to one side of the bar, as a real distance
      // — the unit normal, so the tolerances below are lengths and not
      // areas that grow with how long the bar happens to be.
      double sideOf(Vec2 p) => bar.segment.unit.cross(p - bar.a);

      final here = sideOf(symbol.centre);
      if (here.abs() <= Tol.samePointMm) continue;

      /// How far past the bar [p] is, counting from the side the mark's own
      /// middle is on. Positive is beyond it.
      double past(Vec2 p) => here > 0 ? -sideOf(p) : sideOf(p);

      for (final arm in arms) {
        final crossing = bar.segment.crossing(arm);
        if (crossing == null) continue;

        // The end of the arm on the other side of the bar from the mark's
        // own middle.
        //
        // **An arm that comes to rest *on* the bar has not got past it, and
        // then neither of its ends is the far one.** This used to fall back
        // to the apex — a point on the *near* side, the mark's own middle
        // end of the arm — and everything below was then measured from the
        // wrong end of the line and came out as "through" every time. It is
        // not a rare shape: a chevron drawn to fill its light ends on the
        // bar bounding that light, which is how anybody draws one. A window
        // with a full-height mullion, a transom across one side and a `>`
        // in each of the two lights it made came back as **one** opening
        // with the transom swallowed into it — two leaves marked, one leaf
        // built, and one question asked where there should have been two.
        final Vec2 away;
        if (past(arm.b) > Tol.samePointMm) {
          away = arm.b;
        } else if (past(arm.a) > Tol.samePointMm) {
          away = arm.a;
        } else {
          continue;
        }

        final beyond = Segment(crossing.at, away);
        if (beyond.length < Tol.minLineMm) continue;

        // The region the arm goes into, picked up just past the bar's own
        // material rather than at its centre line, which is inside the bar
        // and in no region at all.
        final entering =
            crossing.at + beyond.unit * (bar.widthMm + Tol.minLineMm);
        SectionElement? far;
        for (final face in faces) {
          if (face.outline.contains(entering)) far = face;
        }
        if (far == null) continue;

        // **Through, not into.** The arm has to get across whatever it went
        // into, not stop out in the middle of it. `spanAcross` says where
        // the far side is along this very line, and the question is then
        // which the arm's end is nearer: the far side, or the bar it came
        // in over. Nearer the far side, it was drawn across that light;
        // nearer the bar, it strayed over the bar and stopped.
        //
        // **Both figures are the drawing's own, and there is no chosen size
        // in it.** An arm crosses a light whether that light is a hand's
        // width or three metres. The measure was a weld tolerance at
        // first — reach the far side, give or take a hand's width — and a
        // weld is a couple of centimetres, which is the wrong scale
        // entirely for where a chevron's point comes to rest: a `>` drawn
        // across a door stops a hand short of the stile, not a weld short
        // of it.
        //
        // **And it is asked of every arm, not only of one that ends inside
        // the far light.** This ran under `far.outline.contains(away)`, so
        // an arm whose end was *not* in that light skipped the test
        // altogether and took the bar unconditionally — and an end lands
        // outside a light very easily: on the bar's own material, or a
        // hand's width over the mullion beside it. A window with a
        // full-height mullion, a transom across one side and a `>` in each
        // of the two lights it made came back as **one** opening with the
        // transom swallowed into it, because each chevron's tail came to
        // rest on a bar rather than in the daylight. Two leaves the user
        // had marked, one leaf built, and one question asked where there
        // should have been two.
        //
        // Both distances are taken **along the arm's own line**, by
        // projection rather than by asking whether the end is inside the
        // light, so there is no case left to skip: an end resting on the
        // bar has got nowhere at all, and an end that strayed over the
        // mullion beside it has got however far along this line it really
        // did get.
        final run = DesignEdits.spanAcross(
            far.outline, Segment(entering, entering + beyond.unit));
        if (run == null) continue;
        final across = (run.b - entering).dot(beyond.unit);
        if (across <= Tol.samePointMm) continue;
        if ((away - entering).dot(beyond.unit) * 2 < across) continue;

        through.add(bar);
        break;
      }
    }
    return through;
  }

  /// What [symbol] says about the section it is in, in [design].
  ///
  /// **In a sliding design the chevron points the way the panel slides.**
  /// Its point is at the edge that moves, as it is everywhere: on a hinged
  /// leaf that edge swings, and on a sliding panel it leads — so `>` slides
  /// right and `<` slides left. The user chose a sliding design on the
  /// start screen, so this is reading their mark in the terms they set, not
  /// deciding how the panel opens. A `^` or a `v` says what it always says,
  /// because nothing here slides up or down.
  static OpeningMechanism _said(Design design, OpeningSymbol symbol) {
    if (!design.kind.slides) return symbol.mechanism;
    return switch (symbol.mechanism) {
      OpeningMechanism.hingedLeft => OpeningMechanism.slidingRight,
      OpeningMechanism.hingedRight => OpeningMechanism.slidingLeft,
      final other => other,
    };
  }

  /// [stroke] as the shaft of the arrow [symbol] heads, or null when it is
  /// not one.
  ///
  /// A shaft is a short straight line behind the point of a chevron: it
  /// lies along the way the chevron points, starts within the mark's own
  /// reach of the point, and runs back away from it. Every figure is the
  /// mark's own — how long its arms are — so a small arrow and a large one
  /// are read alike, and a rail the mark happens to sit on, which runs far
  /// beyond it, is never taken for its shaft.
  static Segment? _shaftOf(OpeningSymbol symbol, Stroke stroke) {
    final points = stroke.points;
    if (points.length < 2) return null;
    final line = Segment(points.first, points.last);
    final length = line.length;
    final size = symbol.sizeMm;
    if (length <= 0 || size <= 0) return null;

    // Straight, near enough: a hand's wobble, not a corner.
    for (final p in points) {
      if (line.distanceTo(p) > length * _shaftWander) return null;
    }
    // Short: a shaft, not a line of the design.
    if (length > size * _longestShaft) return null;

    // Along the way the mark points.
    final middle = symbol.armA.lerp(symbol.armB, 0.5);
    final pointing = symbol.apex - middle;
    if (pointing.length <= 0) return null;
    final axis = pointing.normalised;
    if ((line.unit.x * axis.x + line.unit.y * axis.y).abs() < _shaftAlong) {
      return null;
    }

    // Starting at the point and running back from it.
    final near = points.first.distanceTo(symbol.apex) <=
            points.last.distanceTo(symbol.apex)
        ? points.first
        : points.last;
    final far = identical(near, points.first) ? points.last : points.first;
    if (near.distanceTo(symbol.apex) > size) return null;
    double ahead(Vec2 p) =>
        (p.x - symbol.apex.x) * axis.x + (p.y - symbol.apex.y) * axis.y;
    if (ahead(far) >= ahead(near) || ahead(far) >= 0) return null;
    return Segment(near, far);
  }

  /// How far a shaft may wander off straight, as a share of its length.
  static const _shaftWander = 0.15;

  /// How long a shaft may be, in lengths of the mark's own arms. An arrow's
  /// shaft is about as long as its head is wide; a few times that is still
  /// an arrow, and anything longer is a line of the design.
  static const _longestShaft = 4.0;

  /// How nearly a shaft lies along the way its mark points: the cosine of
  /// the widest angle a hand draws one at.
  static const _shaftAlong = 0.9;

  /// Where the sliding panels drawn together in one light meet.
  ///
  /// **Two sliding marks in one light are two equal panels.** `<-  ->` side
  /// by side in one light is a pair parting in the middle: the left one
  /// runs left and the right one runs right. That is the user's own
  /// notation, in their words — *when we have `<-  ->` that symbol splits
  /// the opening part into two equal parts and opens it* — so the light is
  /// divided equally, by what the symbol says, and not by where the hand
  /// happened to put each arrow. Three marks make three equal panels, and
  /// so on. The line each pair meets at is as wide as any other bar, so
  /// the daylight either side of it is equal too.
  ///
  /// It lasts as long as the marks do. It is made again from them at every
  /// reading, and rubbing one of them out takes it away.
  static List<DividerElement> _meetingsOf(
    Design design,
    List<OpeningSymbol> symbols, {
    required double width,
  }) {
    final frame = design.frame;
    if (frame == null) return const [];
    final byLight = <String, List<OpeningSymbol>>{};
    for (final symbol in symbols) {
      if (symbol.glyph != '<' && symbol.glyph != '>') continue;
      final light = sectionFor(design, symbol);
      if (light == null) continue;
      byLight.putIfAbsent(light.id, () => []).add(symbol);
    }

    final meetings = <DividerElement>[];
    for (final entry in byLight.entries) {
      final marks = entry.value;
      if (marks.length < 2) continue;
      final light = design.sectionById(entry.key)!.outline;
      marks.sort((a, b) => a.centre.x.compareTo(b.centre.x));
      // Each meeting line takes its own width out of the light, so the
      // panels are equal in the daylight they close: n panels and n - 1
      // lines share the light's width between them.
      final panel = (light.width - (marks.length - 1) * width) / marks.length;
      if (panel <= 0) continue;
      for (var i = 0; i + 1 < marks.length; i++) {
        final x = light.left + (i + 1) * panel + i * width + width / 2;
        final across = DesignEdits.spanAcross(
          light,
          Segment(Vec2(x, light.top), Vec2(x, light.bottom)),
        );
        if (across == null) continue;
        meetings.add(DividerElement(
          id: 'meeting-${marks[i].strokeId}-${marks[i + 1].strokeId}',
          a: across.a,
          b: across.b,
          widthMm: width,
          finish: frame.finish,
          fromStrokeId: marks[i].strokeId,
        ));
      }
    }
    return meetings;
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
  ///
  /// Where one line across the two loose ends would close it — a [gap] —
  /// the question says which side is open and asks whether they want it
  /// that way. Where nothing so simple would, it asks them to finish it.
  static Interpretation _unclosed(
    Design design,
    List<_Run> runs,
    List<Stroke> structural, {
    _Gap? gap,
  }) {
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
        if (gap != null)
          DesignQuestion(
            id: outlineGapQuestion,
            prompt: 'Your design is not closed — ${gap.side} is open.',
            detail: 'Do you want it this way, or are you going to change '
                'it? Nothing has been added or taken away.',
            options: [
              QuestionOption(
                key: 'leave-open',
                label: 'Keep it open',
                detail: 'Build it as drawn, with no frame across '
                    '${gap.side}${gap.isFoot ? ' — a door runs down to the '
                        'floor' : ''}.',
              ),
              QuestionOption(
                key: 'close-it',
                label: 'Close it',
                detail: 'Put the frame across ${gap.side}, straight between '
                    'the two ends you drew.',
              ),
              const QuestionOption(
                key: 'change-it',
                label: 'I will change it',
                detail: 'Go back to the drawing and draw it as you want it.',
              ),
            ],
          )
        else
          const DesignQuestion(
            id: 'frame-not-closed',
            prompt: 'The outline does not close. What would you like to do?',
            detail: 'Your lines do not join up into a shape, so there is no '
                'outer frame yet. Nothing has been changed or added.',
            options: [
              QuestionOption(
                key: 'draw-more',
                label: 'Let me draw the rest',
                detail:
                    'Go back to the drawing and close the outline yourself.',
              ),
            ],
          ),
      ],
      unusedStrokeIds: [for (final s in structural) s.id],
    );
  }

  /// The id of the question asked about an outline with one side missing.
  static const outlineGapQuestion = 'outline-gap';

  /// The one side missing from an outline that does not close: the line
  /// between two loose ends that would close it, or null when no single
  /// line would.
  ///
  /// A loose end is one that touches no other line. Where there are more
  /// than two — a line hanging inside the design has one too — every pair
  /// is tried, and the pair that closes the **largest** shape is the gap,
  /// because that is the outline the user drew; a line from a jamb to the
  /// end of a hanging bar closes something smaller, and is not what was
  /// left undrawn. Nothing is added here: this only says where the gap is.
  static _Gap? _gapIn(List<_Run> runs, double weld) {
    final loose = <Vec2>[];
    for (var i = 0; i < runs.length; i++) {
      for (final end in [runs[i].segment.a, runs[i].segment.b]) {
        var touches = false;
        for (var j = 0; j < runs.length && !touches; j++) {
          if (j != i && runs[j].segment.distanceTo(end) <= weld) {
            touches = true;
          }
        }
        if (touches) continue;
        if (loose.any((p) => p.distanceTo(end) <= weld)) continue;
        loose.add(end);
      }
    }
    // A drawing with this many loose ends is not an outline with one side
    // left off, and trying every pair of them would say nothing useful.
    if (loose.length < 2 || loose.length > 8) return null;

    final segments = [for (final r in runs) r.segment];
    Segment? best;
    Polygon? bestOutline;
    for (var i = 0; i < loose.length; i++) {
      for (var j = i + 1; j < loose.length; j++) {
        final across = Segment(loose[i], loose[j]);
        if (across.length < Tol.minLineMm) continue;
        final closed = PlanarSubdivision.subdivide(
          [...segments, across],
          weldTolerance: weld,
          minAreaMmSq: math.max(Tol.minSectionAreaMmSq, weld * weld * 4),
        ).outline;
        if (closed == null || closed.isEmpty) continue;
        final better = bestOutline == null ||
            closed.area > bestOutline.area + weld * weld ||
            ((closed.area - bestOutline.area).abs() <= weld * weld &&
                across.length < best!.length);
        if (better) {
          best = across;
          bestOutline = closed;
        }
      }
    }
    if (best == null || bestOutline == null) return null;
    return _Gap(best, bestOutline);
  }

  /// Endpoints drawn near each other were meant to be the same point.
  ///
  /// Only the ends move, and only onto each other — a line's angle and
  /// length are otherwise untouched. Without this, a box drawn as four
  /// separate strokes never closes, because a hand does not land twice on
  /// the same pixel.
  /// Which opening a new [line] is started in — its id — or null for the
  /// main design.
  ///
  /// **The starting point decides.** The user's words: *determine which area
  /// contains the start point, and assign the line to that area; not by the
  /// nearest line, not by the largest rectangle, not by the drawing's
  /// bounds.* The regions are the design's as it stands *before* this
  /// reading rebuilds it, so they are the ones the user was looking at when
  /// they drew.
  ///
  /// 1. **A start inside an opening** — inside it by the line's own
  ///    thickness, [widthMm] — makes it that opening's, whatever the line
  ///    does after. Where openings are one inside another, the smallest
  ///    holding the start is the one: it is the region the start is in.
  /// 2. **A start inside a part of the main design** — a light that does not
  ///    open, by the same margin — makes it the main design's.
  /// 3. **A start on an edge** — on the frame or a bar, which is the edge of
  ///    two areas at once and so says nothing by itself — makes it an
  ///    opening's only when the line lies within that opening, give or take
  ///    [memberMm] for the member it was started from, and runs well inside
  ///    it somewhere: the rail drawn from a sash's jamb that stops before the
  ///    far one. A line started on the frame and run across the window
  ///    leaves the opening, and a line along a sash's own jamb never runs
  ///    well inside it, so both are the main design's.
  static String? _scopeOf(
    Design design,
    Segment line,
    double widthMm,
    double memberMm,
  ) {
    final margin = math.max(widthMm, Tol.minLineMm);
    final start = line.a;
    String? smallest;
    var least = double.infinity;
    void consider(String id, Polygon region) {
      if (region.area < least) {
        least = region.area;
        smallest = id;
      }
    }

    // 1. Started inside an opening.
    for (final opening in design.openings) {
      final region = design.sectionById(opening.sectionId)?.outline;
      if (region == null || region.isEmpty) continue;
      final room = region.inset(margin);
      if (room.isEmpty || room.area <= 0) continue;
      if (room.contains(start)) consider(opening.id, region);
    }
    if (smallest != null) return smallest;

    // 2. Started inside a part of the main design. A part with an opening
    // lying inside it — the ground round a box drawn loose in the frame,
    // which is kept as the whole of the frame's daylight because a part is
    // not stored with a hole in it — holds the start only where the opening
    // does not, and that is settled by the edge test below.
    final openedRegions = [
      for (final opening in design.openings)
        ?design.sectionById(opening.sectionId),
    ];
    for (final section in design.sections) {
      if (openedRegions.any((o) => o.id == section.id)) continue;
      if (openedRegions.any(
        (o) => section.outline.contains(o.outline.centroid),
      )) {
        continue;
      }
      final room = section.outline.inset(margin);
      if (room.isEmpty || room.area <= 0) continue;
      if (room.contains(start)) return null;
    }

    // 3. Started on an edge.
    for (final opening in design.openings) {
      final region = design.sectionById(opening.sectionId)?.outline;
      if (region == null || region.isEmpty) continue;
      final room = region.inset(margin);
      if (room.isEmpty || room.area <= 0) continue;
      final onItsEdge =
          region.contains(start) || region.awayFrom(start) <= memberMm;
      final runsWellInside = [
        for (var i = 0; i <= 12; i++) line.pointAt(i / 12),
      ].any(room.contains);
      if (onItsEdge && runsWellInside && region.holds(line, reach: memberMm)) {
        consider(opening.id, region);
      }
    }
    return smallest;
  }

  /// [line], an opening's, completed inside the opening's [region] and
  /// nowhere else.
  ///
  /// What the hand drew past the opening's edge is not the opening's, so it
  /// is trimmed back to the edge — trimming a line drawn past its corner is
  /// cleaning. A level or upright line is then completed as
  /// `_completed` completes one, against the opening's edge and the
  /// opening's own lines ([boundaries]): an end touching nothing is carried
  /// to the first of them, and an end already on one stays where it is. A
  /// line at a slope is laid across the opening, as **Divides** and the line
  /// tools lay one. The opening itself is not touched.
  static Segment _completedWithin(
    Segment line,
    Polygon region,
    List<Segment> boundaries,
    double weld,
  ) {
    final chord = DesignEdits.spanAcross(region, line);
    if (chord == null) return line;
    if (!line.isHorizontalish && !line.isVerticalish) return chord;
    final from = chord.parameterOf(line.a).clamp(0.0, 1.0);
    final to = chord.parameterOf(line.b).clamp(0.0, 1.0);
    if ((to - from).abs() * chord.length < Tol.minLineMm) return chord;
    return _completed(
      Segment(chord.pointAt(from), chord.pointAt(to)),
      boundaries,
      region,
      weld,
      drawn: line,
      weldEnds: true,
    );
  }

  /// Each end of a run that the user drew **onto** another line, carried
  /// onto the straight line that other line became.
  ///
  /// **An end that touches a line on the sheet touches it in the design.**
  /// That is a fact of the drawing, and straightening is not allowed to
  /// break it. A hand's outline is straightened leg by leg — a kink of a few
  /// centimetres in a metre-long jamb is wobble, and taking it out is the
  /// cleaning this file exists to do — but the straight leg can then lie a
  /// hand's width from where the user actually drew it, and a transom drawn
  /// to their jamb now stops short of the straightened one. It divides
  /// nothing on that side: the light above it and the light below run
  /// together, and a `<` the user drew in a small upper light opened the
  /// whole column from head to sill.
  ///
  /// So the question is asked of the **ink**, not of the fit. An end within
  /// a weld of another stroke's own samples was drawn onto it, and is moved
  /// along its own line to where that line meets the leg the stroke became.
  /// Along its own line, so the angle the user drew it at is kept; never
  /// further than that stroke's straightening was allowed to move it, so
  /// this can only undo the fitter's own displacement and never reach
  /// across the design; and only when the fit really did move the line
  /// away, so an end already on its line is left exactly where it was.
  static List<_Run> _ontoWhatTheyWereDrawnOn(
    List<_Run> runs,
    Map<String, Stroke> drawn,
  ) {
    final weld = Tol.weldFor(_spanOf(runs));
    final legs = <String, List<Segment>>{};
    for (final run in runs) {
      legs.putIfAbsent(run.strokeId, () => []).add(run.segment);
    }

    double offTheInk(Vec2 point, Stroke stroke) {
      final ink = stroke.points;
      var nearest = double.infinity;
      for (var i = 1; i < ink.length; i++) {
        nearest =
            math.min(nearest, Segment(ink[i - 1], ink[i]).distanceTo(point));
      }
      return nearest;
    }

    Vec2 follow(Vec2 end, Vec2 from, String own) {
      final along = end - from;
      if (along.length <= Tol.samePointMm) return end;

      Vec2? best;
      var nearest = double.infinity;
      for (final entry in legs.entries) {
        if (entry.key == own) continue;
        final stroke = drawn[entry.key];
        if (stroke == null || offTheInk(end, stroke) > weld) continue;

        var already = double.infinity;
        for (final leg in entry.value) {
          already = math.min(already, leg.distanceTo(end));
        }
        if (already <= weld) continue;

        // How far that stroke's own straightening could have moved it —
        // the fitter's tolerance for it, not a figure chosen here.
        final allowance = math.max(
            stroke.diagonal * Tol.cornerFraction, Tol.cornerFloorMm);
        for (final leg in entry.value) {
          final hit = _whereLinesMeet(from, end, leg);
          if (hit == null || leg.distanceTo(hit) > weld) continue;
          if ((hit - from).dot(along) <= 0) continue;
          final move = hit.distanceTo(end);
          if (move > allowance + weld || move >= nearest) continue;
          best = hit;
          nearest = move;
        }
      }
      return best ?? end;
    }

    return [
      for (final run in runs)
        _Run(
          Segment(
            follow(run.segment.a, run.segment.b, run.strokeId),
            follow(run.segment.b, run.segment.a, run.strokeId),
          ),
          run.strokeId,
        ),
    ];
  }

  /// Where the line through [from] and [to] meets the line [leg] lies on.
  static Vec2? _whereLinesMeet(Vec2 from, Vec2 to, Segment leg) {
    final r = to - from;
    final s = leg.direction;
    final denominator = r.cross(s);
    if (denominator.abs() < 1e-9) return null;
    final t = (leg.a - from).cross(s) / denominator;
    return from + r * t;
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
  /// A straight line the user stopped short of what they were drawing it
  /// to, finished there.
  ///
  /// The user's words: *when I draw a straight line and stop before the
  /// boundary, complete it to that boundary.* A hand drawing a transom
  /// across a door lifts a finger's width before the far jamb, and a line
  /// that stops short divides nothing — the door would come back one part
  /// with a line lying in it, which is not what they drew.
  ///
  /// So an end of a level or upright line that **touches nothing** is carried
  /// along the line's own direction to the **first** line it meets: the
  /// outline, another line drawn on the sheet, or a bar made inside the
  /// design. The first, never further — a line drawn towards a transom stops
  /// at the transom, not at the sill beyond it. An end that already touches
  /// a line, by the weld the rest of the reading uses, is where the user
  /// put it and is not moved: that is what keeps a line drawn from a rail
  /// down to the sill from being stretched on past the rail. Nothing else
  /// moves; the line is only made to reach.
  ///
  /// Only level and upright lines — a line drawn at a slope says nothing
  /// about where it was going — and only ends inside the outline, because
  /// a line drawn off the design is not heading for any part of it.
  ///
  /// And never through an opening. These are the design's lines, so an end
  /// that the hand carried into a region the design already opens ([opened])
  /// is left where it was drawn: completing it would run it on across the
  /// opening, which is the opening's own ground. A line heading for an
  /// opening stops at the opening's edge, because that is where the
  /// surrounding design ends in that direction.
  static Segment _completed(
    Segment line,
    List<Segment> boundaries,
    Polygon outline,
    double weld, {
    List<Polygon> opened = const [],
    Segment? drawn,
    bool weldEnds = false,
  }) {
    if (line.length == 0) return line;
    if (!line.isHorizontalish && !line.isVerticalish) return line;
    if (line.offAxisDegrees > Tol.axisSnapDegrees) return line;
    // Not the line itself, nor the stroke it was cut from when it has been
    // trimmed to an opening: an end always touches its own line.
    final others = [
      for (final b in boundaries)
        if (b != line && b != drawn) b,
    ];
    final reach = math.max(outline.width, outline.height) * 2;

    Vec2 finish(Vec2 end, Vec2 outward) {
      for (final b in others) {
        if (b.distanceTo(end) > weld) continue;
        if (!weldEnds) return end;
        // Welded onto what it all but touches, along its own line: a few
        // millimetres short of a sash's stile is a hand's, and inside a sash
        // it is the difference between two panes and one pane with a line
        // lying on it. Along a line running beside it, there is no point on
        // it to weld to, and the end stays.
        final probe = Segment(end - outward * weld, end + outward * weld);
        return probe.crossing(b)?.at ?? end;
      }
      if (!outline.contains(end)) return end;
      for (final region in opened) {
        if (region.contains(end)) return end;
      }
      final ray = Segment(end, end + outward * reach);
      Vec2? nearest;
      var best = double.infinity;
      for (final b in others) {
        final crossing = ray.crossing(b);
        if (crossing == null) continue;
        final d = crossing.at.distanceTo(end);
        if (d > weld && d < best) {
          best = d;
          nearest = crossing.at;
        }
      }
      return nearest ?? end;
    }

    final u = line.unit;
    return Segment(finish(line.a, u * -1), finish(line.b, u));
  }

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

/// The side missing from an outline, and the shape it would close.
class _Gap {
  final Segment segment;
  final Polygon closes;
  const _Gap(this.segment, this.closes);

  /// Which side of the shape the gap is, the way somebody would say it.
  String get side {
    final at = segment.midpoint;
    final middle = closes.centroid;
    if (segment.isHorizontalish) {
      return at.y > middle.y ? 'the bottom' : 'the top';
    }
    if (segment.isVerticalish) {
      return at.x < middle.x ? 'the left side' : 'the right side';
    }
    return 'one side';
  }

  /// Whether it is the foot of the shape — where a door meets the floor.
  bool get isFoot => side == 'the bottom';
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
