import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/dimensions/dimension_chain.dart';
import '../../domain/dimensions/measurements.dart';
import '../../domain/geometry/vec2.dart';
import '../../domain/model/design.dart';
import 'cad_style.dart';
import 'view_transform.dart';

/// One figure on the drawing, where it is drawn: its run on its dimension
/// line, the witness lines that tie it to the geometry, and where its words
/// go.
class PlacedFigure {
  final DimensionChain chain;
  final ChainRun run;

  /// Whether the user has given this size; one they have not is `?`.
  final bool known;

  /// What is written: the run's own length, in centimetres.
  final String text;

  /// The run's two ends on its dimension line.
  final Offset from, to;

  /// The two witness lines, each from beside the geometry to just past the
  /// dimension line.
  final (Offset, Offset) witnessFrom, witnessTo;

  /// The middle of the words, and their size before any turn.
  final Offset figure;
  final Size size;

  /// Where the words stand beyond the run — too short to hold them — the
  /// dimension line is carried on to them, from here to there.
  final (Offset, Offset)? leader;

  const PlacedFigure({
    required this.chain,
    required this.run,
    required this.known,
    required this.text,
    required this.from,
    required this.to,
    required this.witnessFrom,
    required this.witnessTo,
    required this.figure,
    required this.size,
    this.leader,
  });

  /// Whether the words are turned to read up the page.
  bool get turned => chain.axis == DimensionAxis.vertical;

  /// Where the words are on the screen, turned as they are drawn.
  Rect get rect => Rect.fromCenter(
    center: figure,
    width: turned ? size.height : size.width,
    height: turned ? size.width : size.height,
  );
}

/// The name of a row — OVERALL, DAYLIGHT, OPENING, DIVISION — at its end.
class PlacedName {
  final String text;
  final Offset at;
  final bool turned;
  final Size size;

  const PlacedName(
    this.text,
    this.at, {
    required this.turned,
    required this.size,
  });

  Rect get rect => Rect.fromCenter(
    center: at,
    width: turned ? size.height : size.width,
    height: turned ? size.width : size.height,
  );
}

/// Where every dimension on the technical drawing goes.
///
/// **One answer, read by the painter and the pointer alike**, so what is
/// written and what can be tapped are the same thing by construction.
///
/// - **Each kind of figure has its side.** Along the foot and down the left,
///   what the whole is divided into and, beyond it, the whole; along the
///   head and down the right, what each divided part is divided into and,
///   beyond it, each opening. See [DimensionSide].
/// - **Every figure is a run's own length**, written in centimetres to the
///   millimetre — `160.0 cm`, `91.6 cm` — every one of them ([places]), so a
///   column of figures lines up, no two are written differently, and a line
///   drawn in one part never rewrites the figures of another.
/// - **No two figures on a row overlap.** A figure goes over the middle of
///   its run; where the run is too short to hold it, just past the run's
///   end, with the dimension line carried on to it; and where it would run
///   into the figure before it, on along the line until it is clear — each
///   still on its own row, beside its own run.
/// - **A row's name stands at its end**, past its last figure, where no
///   other row's lines run.
class DimensionLayout {
  final List<PlacedFigure> figures;
  final List<PlacedName> names;

  const DimensionLayout(this.figures, this.names);

  static const empty = DimensionLayout([], []);

  /// How many places of a centimetre every figure on the drawing is written
  /// to: one, the millimetre — what a workshop cuts to — whatever the design,
  /// so the drawing's figures are one format and stay it as it is edited.
  static const int places = 1;

  /// The space a figure keeps clear either side of it along its line, and
  /// between it and the next.
  static const double clearance = 5;

  /// How far a row's name stands from the end of its row.
  static const double nameGap = 14;

  /// How far out from the drawing [chain]'s row sits, in pixels.
  static double outFor(DimensionChain chain) =>
      Cad.dimensionGap + chain.row * Cad.dimensionStep;

  static TextPainter figureText(String text) =>
      Cad.label(text, weight: FontWeight.w600);

  static TextPainter nameText(String text) => Cad.label(
    text.toUpperCase(),
    size: Cad.smallTextSize - 0.5,
    weight: FontWeight.w600,
    spacing: 1.1,
  );

  /// The rows, most wanted first: the whole, what the whole is divided
  /// into, the openings, what each part is divided into.
  static int _rank(DimensionChain chain) => switch (chain.runs.first.of) {
    ChainRunOf.overall => 0,
    ChainRunOf.side => 0,
    ChainRunOf.daylight => 1,
    ChainRunOf.opening => 2,
    ChainRunOf.division => 3,
  };

  /// [canvas], where given, is the sheet the drawing is on: a row that
  /// would put a figure or its name off it is not written at this zoom.
  static DimensionLayout of(Design design, ViewTransform view, {Size? canvas}) {
    final frame = design.frame;
    if (frame == null) return empty;
    final outline = frame.outline;
    final all = DimensionChains.of(design);
    final chains = [
      for (final (_, c)
          in [
            for (var i = 0; i < all.length; i++)
              if (all[i].runs.isNotEmpty) (i, all[i]),
          ]..sort((a, b) {
            final byRank = _rank(a.$2).compareTo(_rank(b.$2));
            return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
          }))
        c,
    ];
    final sheet = canvas == null ? null : (Offset.zero & canvas).deflate(1);
    bool onSheet(Rect r) =>
        sheet == null ||
        (sheet.contains(r.topLeft) && sheet.contains(r.bottomRight));
    final sizes = Measurements.of(design);

    Offset at(double x, double y) => view.toScreen(Vec2(x, y));
    final left = at(outline.left, 0).dx, right = at(outline.right, 0).dx;
    final top = at(0, outline.top).dy, bottom = at(0, outline.bottom).dy;

    final figures = <PlacedFigure>[];
    final names = <PlacedName>[];
    // Everything written so far, and the drawing itself: nothing is written
    // over any of it. Rows are placed most wanted first — the whole, what it
    // is divided into, the openings, what each part is divided into — so
    // those keep the places nearest their runs, and a row that cannot be
    // written legibly at this zoom, every figure over its run or just beside
    // it and on the sheet, is left off until the drawing is looked at
    // closer: a row of figures strewn away from what they measure says less
    // than none. The overall size is always written.
    final taken = <Rect>[Rect.fromLTRB(left, top, right, bottom).inflate(2)];

    for (final chain in chains) {
      final mark = taken.length;
      final rowFigures = <PlacedFigure>[];
      var legible = true;
      final side = chain.side;
      final across = chain.axis == DimensionAxis.horizontal;
      final out = outFor(chain);
      // Where the row's line is, square to it, and where its witness lines
      // start, beside the drawing.
      final (line, base, away) = switch (side) {
        DimensionSide.bottom => (bottom + out, bottom + Cad.witnessGap, 1.0),
        DimensionSide.top => (top - out, top - Cad.witnessGap, -1.0),
        DimensionSide.left => (left - out, left - Cad.witnessGap, -1.0),
        DimensionSide.right => (right + out, right + Cad.witnessGap, 1.0),
      };
      Offset point(double along, double square) =>
          across ? Offset(along, square) : Offset(square, along);
      double alongOf(double mm) => across ? at(mm, 0).dx : at(0, mm).dy;
      // Where words [length] long by [height] high are, centred [centre]
      // along the row and [off] from its line.
      Rect wordsAt(double centre, double length, double height, double off) =>
          Rect.fromCenter(
            center: point(centre, line - off),
            width: across ? length : height,
            height: across ? height : length,
          );
      // The nearest centre from [centre], going [way] along the row, at which
      // the words are clear of everything written so far.
      double clear(
        double centre,
        double length,
        double height,
        double off,
        int way,
      ) {
        var c = centre;
        for (var round = 0; round < 60; round++) {
          final r = wordsAt(c, length, height, off).inflate(clearance / 2);
          final hits = [
            for (final t in taken)
              if (t.overlaps(r)) t,
          ];
          if (hits.isEmpty) return c;
          c = way > 0
              ? hits.map((t) => across ? t.right : t.bottom).reduce(math.max) +
                    clearance +
                    length / 2
              : hits.map((t) => across ? t.left : t.top).reduce(math.min) -
                    clearance -
                    length / 2;
        }
        return c;
      }

      var last = -double.infinity;
      for (final run in chain.runs) {
        final a = alongOf(run.fromMm), b = alongOf(run.toMm);
        final lo = math.min(a, b), hi = math.max(a, b);
        if (hi - lo < 3) continue;
        final known = knows(design, chain.axis, run, sizes);
        final text = Measurements.figure(
          run.valueMm,
          known: known,
          places: places,
        );
        final painter = figureText(text);
        final length = painter.width, height = painter.height;
        // Over the middle of the run where it fits; where not, just past one
        // end of it or the other, whichever is nearer once clear of what is
        // already written.
        final middle = (lo + hi) / 2;
        final fits = hi - lo >= length + 2 * clearance;
        final onward = clear(
          fits ? middle : hi + clearance + length / 2,
          length,
          height,
          figureOff,
          1,
        );
        final back = clear(
          fits ? middle : lo - clearance - length / 2,
          length,
          height,
          figureOff,
          -1,
        );
        var centre = (back - middle).abs() < (onward - middle).abs()
            ? back
            : onward;
        var off = figureOff;
        // Over its run where it fits there; otherwise no further from it
        // than its own length — and never alongside another run of the row,
        // where it would be read as that run's.
        bool alongsideAnother(double c) => chain.runs.any((other) {
          if (identical(other, run)) return false;
          final p = alongOf(other.fromMm), q = alongOf(other.toMm);
          return c - length / 2 < math.max(p, q) - 1 &&
              c + length / 2 > math.min(p, q) + 1;
        });
        bool nearAt(double c) {
          final gap = math.max(
            0.0,
            math.max(c - length / 2 - hi, lo - (c + length / 2)),
          );
          return !alongsideAnother(c) &&
              (fits ? c >= lo && c <= hi : gap <= math.max(length, 24));
        }

        var near = nearAt(centre);
        // Where it cannot stand on the line beside its run — two narrow
        // lights side by side, each figure longer than either — it is
        // staggered: lifted a line further off, over the middle of its own
        // run, and joined to that middle by a leader.
        var lifted = false;
        if (!near) {
          for (final tier in [1, 2]) {
            final o = figureOff + tier * (height + 3);
            final up = clear(middle, length, height, o, 1);
            final down = clear(middle, length, height, o, -1);
            final c = (down - middle).abs() < (up - middle).abs() ? down : up;
            if ((c - middle).abs() <= length / 2) {
              centre = c;
              off = o;
              near = true;
              lifted = true;
              break;
            }
          }
        }
        final words = wordsAt(centre, length, height, off);
        taken.add(words);
        if (!near || !onSheet(words)) legible = false;
        last = math.max(last, centre + length / 2);
        final start = centre - length / 2, end = centre + length / 2;
        rowFigures.add(
          PlacedFigure(
            chain: chain,
            run: run,
            known: known,
            text: text,
            from: point(lo, line),
            to: point(hi, line),
            witnessFrom: (
              point(lo, base),
              point(lo, line + away * Cad.witnessOvershoot),
            ),
            witnessTo: (
              point(hi, base),
              point(hi, line + away * Cad.witnessOvershoot),
            ),
            figure: point(centre, line - off),
            size: Size(length, height),
            // A figure off its run is joined to it: lifted, by a leader from
            // the run's middle; beside it, by its own line carried on.
            leader: lifted
                ? (point(middle, line), point(middle, line - off + height / 2))
                : start > hi + 1
                ? (point(hi, line), point(start - 2, line))
                : end < lo - 1
                ? (point(lo, line), point(end + 2, line))
                : null,
          ),
        );
      }

      // The row's name at its end, where no other row's lines run: after
      // the foot's rows, below the left's, before the head's and above the
      // right's — and on past anything already written there.
      final label = nameText(chain.runs.first.note);
      final w = label.width, h = label.height;
      final (double along, int way) = switch (side) {
        DimensionSide.bottom => (math.max(right, last) + nameGap + w / 2, 1),
        DimensionSide.left => (math.max(bottom, last) + nameGap + w / 2, 1),
        DimensionSide.top => (left - nameGap - w / 2, -1),
        DimensionSide.right => (top - nameGap - w / 2, -1),
      };
      final placed = clear(along, w, h, 0, way);
      final nameAt = wordsAt(placed, w, h, 0);
      if (!onSheet(nameAt)) legible = false;
      if (!legible && _rank(chain) > 0) {
        // Not at this zoom: nothing of it is written.
        taken.removeRange(mark, taken.length);
        continue;
      }
      taken.add(nameAt);
      figures.addAll(rowFigures);
      names.add(
        PlacedName(
          chain.runs.first.note.toUpperCase(),
          point(placed, line),
          turned: !across,
          size: Size(w, h),
        ),
      );
    }
    return DimensionLayout(figures, names);
  }

  /// How far a figure stands off its dimension line, in pixels: just above
  /// a row across, just left of a row down, read up the page — as a drawing
  /// writes them, so the line runs unbroken under its figure.
  static const double figureOff = 8;

  /// Whether the figure for [run], in a chain along [axis], is one the
  /// user has given.
  static bool knows(
    Design design,
    DimensionAxis axis,
    ChainRun run,
    List<Measure> sizes,
  ) {
    final along = axis == DimensionAxis.horizontal
        ? MeasureAxis.across
        : MeasureAxis.down;
    if (run.sideKey case final key?) {
      return Measurements.knowsMeasure(design, key, sizes);
    }
    final section = run.sectionId;
    if (run.of == ChainRunOf.overall || section == null) {
      return Measurements.knowsOverall(design, along);
    }
    return Measurements.knowsSection(design, section, along, sizes);
  }

  /// The room [design]'s dimensions need beside the drawing, in pixels,
  /// beyond what the foot and the left always have: its rows along the
  /// head and down the right, and their names.
  ///
  /// [rightToo] false keeps the right for the drawing — on a narrow screen,
  /// where width is what there is least of — and its rows appear as the
  /// drawing is looked at closer. A side of the frame down the right is
  /// the exception: it is the frame's own figure and always written.
  static EdgeInsets roomFor(Design design, {bool rightToo = true}) {
    var top = -1, right = -1;
    for (final chain in DimensionChains.of(design)) {
      if (chain.side == DimensionSide.top) top = math.max(top, chain.row);
      // A side of the frame down the right is the frame's own figure, as
      // the overall height is, and is always written, so its room is kept
      // even where the right is otherwise left to the drawing.
      if (chain.side == DimensionSide.right &&
          (rightToo || chain.runs.first.of == ChainRunOf.side)) {
        right = math.max(right, chain.row);
      }
    }
    double rows(int last) => last < 0
        ? 0
        : Cad.dimensionGap + last * Cad.dimensionStep + 2 * figureOff + 12;
    return EdgeInsets.only(top: rows(top), right: rows(right));
  }
}
