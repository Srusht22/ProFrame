import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/dimensions/dimension_chain.dart';
import '../../domain/geometry/polygon.dart';
import '../../domain/geometry/segment.dart';
import '../../domain/geometry/vec2.dart';
import '../../domain/model/design.dart';
import '../../domain/model/elements.dart';
import 'cad_layers.dart';
import 'cad_style.dart';
import 'view_transform.dart';

/// Draws the design as a technical drawing.
///
/// It draws the geometry that is there and nothing else. There is no second
/// version of the design for this view to show: the same frame, the same
/// bars at the same angles, the same sections, straight out of the document.
/// What this painter adds is the language of a drawing — line weights that
/// mean something, hatching that says what a thing is made of, dimensions
/// that measure what is in front of them.
class CadPainter extends CustomPainter {
  final Design design;
  final ViewTransform view;
  final CadLayers layers;
  final String? selectedId;
  final Set<String> highlighted;

  /// Where the pointer is, in millimetres, for the snap marker.
  final Vec2? snapAt;

  /// The grips of the selected object, in millimetres.
  final List<Grip> grips;

  const CadPainter({
    required this.design,
    required this.view,
    required this.layers,
    this.selectedId,
    this.highlighted = const {},
    this.snapAt,
    this.grips = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Cad.fill(Cad.sheet));
    if (layers.grid) _grid(canvas, size);

    if (design.frame == null) return;

    if (layers.sketch) _sketch(canvas);
    _infill(canvas);
    _frame(canvas);
    _bars(canvas);
    if (layers.openings) _openings(canvas);
    _hardware(canvas);
    if (layers.dimensions) {
      _chains(canvas);
      _userDimensions(canvas);
    }
    if (layers.annotations) _annotations(canvas);
    _selection(canvas);
    if (layers.grips) _grips(canvas);
    _snap(canvas);
  }

  // ------------------------------------------------------------------ paper

  void _grid(Canvas canvas, Size size) {
    for (final (step, colour) in [
      (100.0, Cad.grid),
      (1000.0, Cad.gridStrong),
    ]) {
      final spacing = view.lengthToScreen(step);
      if (spacing < 10) continue;
      final paint = Cad.stroke(colour, Cad.hairline);
      for (var x = view.origin.dx % spacing; x < size.width; x += spacing) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
      for (var y = view.origin.dy % spacing; y < size.height; y += spacing) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }
  }

  /// The user's own marks, as an underlay — the drafting equivalent of the
  /// pencil under the ink. Faint, so the drawing reads, and there so the
  /// user can check the drawing against what they actually drew.
  void _sketch(Canvas canvas) {
    for (final stroke in design.sketch.strokes) {
      if (stroke.isEmpty) continue;
      final path = Path();
      final first = view.toScreen(stroke.samples.first.at);
      path.moveTo(first.dx, first.dy);
      for (final sample in stroke.samples.skip(1)) {
        final at = view.toScreen(sample.at);
        path.lineTo(at.dx, at.dy);
      }
      canvas.drawPath(
        path,
        Cad.stroke(Cad.hidden.withValues(alpha: 0.4), 1.1, round: true),
      );
    }
  }

  // --------------------------------------------------------------- geometry

  /// What fills each section, drawn the way a drawing shows a material
  /// rather than the way a photograph shows it.
  void _infill(Canvas canvas) {
    for (final section in design.sections) {
      final path = view.pathOf(section.outline);
      final material = section.finish.material;

      if (material.isGlazing) {
        canvas.drawPath(path, Cad.fill(Cad.glass));
        if (layers.hatching) _glazingMark(canvas, section.outline);
      } else {
        canvas.drawPath(
          path,
          Cad.fill(Color(section.finish.colour).withValues(alpha: 0.32)),
        );
        if (layers.hatching) _hatch(canvas, section.outline);
      }

      canvas.drawPath(path, Cad.stroke(Cad.medium, Cad.detail));
    }
  }

  /// The two parallel strokes across a corner that mean glass on an
  /// elevation.
  void _glazingMark(Canvas canvas, Polygon outline) {
    final across = view.lengthToScreen(outline.width);
    final down = view.lengthToScreen(outline.height);
    final reach = math.min(across, down) * 0.3;
    if (reach < 9) return;

    final topRight = view.toScreen(Vec2(outline.right, outline.top));
    canvas.save();
    canvas.clipPath(view.pathOf(outline));
    final paint = Cad.stroke(Cad.glassLine, Cad.hairline);
    for (final inset in [0.0, 5.0]) {
      canvas.drawLine(
        topRight + Offset(-reach - inset, inset),
        topRight + Offset(-inset, reach + inset),
        paint,
      );
    }
    canvas.restore();
  }

  /// Forty-five degree hatching, for anything solid.
  void _hatch(Canvas canvas, Polygon outline) {
    final path = view.pathOf(outline);
    final bounds = path.getBounds();
    if (bounds.width < 6 || bounds.height < 6) return;

    canvas.save();
    canvas.clipPath(path);
    final paint = Cad.stroke(Cad.hatch.withValues(alpha: 0.55), Cad.hairline);
    const spacing = 9.0;
    final reach = bounds.width + bounds.height;
    for (var at = 0.0; at < reach; at += spacing) {
      canvas.drawLine(
        Offset(bounds.left + at, bounds.top),
        Offset(bounds.left + at - bounds.height, bounds.bottom),
        paint,
      );
    }
    canvas.restore();
  }

  /// True when a width and a height really do describe this shape.
  ///
  /// Measured by area rather than by angle: a frame drawn by hand is a degree
  /// or two off square, and its panes inherit that, so a test that demands
  /// exact right angles rejects every real drawing. A shape that fills its
  /// own bounding box is one the two figures describe.
  static bool _isRectangle(Polygon shape) {
    if (shape.corners.length != 4) return false;
    final box = shape.width * shape.height;
    if (box <= 0) return false;
    return shape.area >= box * 0.97;
  }

  /// The frame, drawn as a profile: the outside heavy, the daylight edge
  /// lighter, exactly on the outline the user drew.
  void _frame(Canvas canvas) {
    final frame = design.frame!;
    canvas.drawPath(
      view.pathOf(frame.outline),
      Cad.stroke(Cad.heavy, Cad.outline),
    );
    final inner = frame.innerOutline;
    if (!inner.isEmpty) {
      canvas.drawPath(view.pathOf(inner), Cad.stroke(Cad.medium, Cad.profile));
      if (layers.hatching) _profileHatch(canvas, frame.outline, inner);
    }
  }

  /// Hatching in the frame ring, which is what says it is a section through
  /// material rather than an empty border.
  void _profileHatch(Canvas canvas, Polygon outer, Polygon inner) {
    final ring = Path.combine(
      PathOperation.difference,
      view.pathOf(outer),
      view.pathOf(inner),
    );
    final bounds = ring.getBounds();
    canvas.save();
    canvas.clipPath(ring);
    final paint = Cad.stroke(Cad.hatch.withValues(alpha: 0.7), Cad.hairline);
    const spacing = 6.0;
    final reach = bounds.width + bounds.height;
    for (var at = 0.0; at < reach; at += spacing) {
      canvas.drawLine(
        Offset(bounds.left + at, bounds.top),
        Offset(bounds.left + at - bounds.height, bounds.bottom),
        paint,
      );
    }
    canvas.restore();
  }

  /// Each bar as its two faces, at the angle it was drawn at.
  void _bars(Canvas canvas) {
    for (final divider in design.dividers) {
      final body = _barBody(divider);
      canvas.drawPath(view.pathOf(body), Cad.fill(Cad.sheet));
      if (layers.hatching) _hatch(canvas, body);
      canvas.drawPath(view.pathOf(body), Cad.stroke(Cad.heavy, Cad.bar));

      // The centre line, as a drawing shows the axis of a member.
      if (layers.centreLines) {
        final line = Path()
          ..moveTo(view.toScreen(divider.a).dx, view.toScreen(divider.a).dy)
          ..lineTo(view.toScreen(divider.b).dx, view.toScreen(divider.b).dy);
        canvas.drawPath(
          Cad.dashed(line, dash: 12, gap: 3),
          Cad.stroke(Cad.light.withValues(alpha: 0.75), Cad.hairline),
        );
      }
    }
  }

  Polygon _barBody(DividerElement divider) {
    final side = divider.segment.unit.perpendicular * (divider.widthMm / 2);
    return Polygon([
      divider.a + side,
      divider.b + side,
      divider.b - side,
      divider.a - side,
    ]);
  }

  /// The swing lines: the standard elevation symbol, dashed, pointing at the
  /// hinge.
  void _openings(Canvas canvas) {
    for (final opening in design.openings) {
      final section = design.sectionById(opening.sectionId);
      if (section == null) continue;
      final box = section.outline;
      final edge = opening.mechanism.hingeEdge;
      final paint = Cad.stroke(Cad.medium, Cad.detail);

      if (edge == null) {
        final middle = view.toScreen(box.centroid);
        final reach = view.lengthToScreen(box.width * 0.28);
        final towards =
            opening.mechanism == OpeningMechanism.slidingLeft ? -1.0 : 1.0;
        final shaft = Path()
          ..moveTo(middle.dx - reach * towards, middle.dy)
          ..lineTo(middle.dx + reach * towards, middle.dy);
        canvas.drawPath(shaft, paint);
        canvas.drawLine(
          middle + Offset(reach * towards, 0),
          middle + Offset(reach * towards * 0.76, -reach * 0.18),
          paint,
        );
        canvas.drawLine(
          middle + Offset(reach * towards, 0),
          middle + Offset(reach * towards * 0.76, reach * 0.18),
          paint,
        );
        continue;
      }

      final (Vec2 hingeA, Vec2 hingeB, Vec2 apex) = switch (edge) {
        OpeningEdge.left => (
            Vec2(box.left, box.top),
            Vec2(box.left, box.bottom),
            Vec2(box.right, (box.top + box.bottom) / 2),
          ),
        OpeningEdge.right => (
            Vec2(box.right, box.top),
            Vec2(box.right, box.bottom),
            Vec2(box.left, (box.top + box.bottom) / 2),
          ),
        OpeningEdge.top => (
            Vec2(box.left, box.top),
            Vec2(box.right, box.top),
            Vec2((box.left + box.right) / 2, box.bottom),
          ),
        OpeningEdge.bottom => (
            Vec2(box.left, box.bottom),
            Vec2(box.right, box.bottom),
            Vec2((box.left + box.right) / 2, box.top),
          ),
      };

      final swing = Path()
        ..moveTo(view.toScreen(hingeA).dx, view.toScreen(hingeA).dy)
        ..lineTo(view.toScreen(apex).dx, view.toScreen(apex).dy)
        ..lineTo(view.toScreen(hingeB).dx, view.toScreen(hingeB).dy);
      canvas.drawPath(Cad.dashed(swing), paint);

      // Which way it opens, in words, because a triangle alone does not say.
      final tag = Cad.label(
        opening.direction == OpeningDirection.outward ? 'OUT' : 'IN',
        colour: Cad.light,
        size: Cad.smallTextSize,
        weight: FontWeight.w600,
      );
      // Inside the section, not hanging off the apex — the apex sits on the
      // section's own edge, so anything placed outside it lands on the frame
      // or off the drawing altogether.
      // The apex sits on the edge opposite the hinge, so the tag steps back
      // towards the middle of the section: away from the apex, not past it.
      final inward = switch (edge) {
        OpeningEdge.left => Offset(-tag.width - 8, -tag.height / 2),
        OpeningEdge.right => Offset(8, -tag.height / 2),
        OpeningEdge.top => Offset(-tag.width / 2, -tag.height - tagGap),
        OpeningEdge.bottom => Offset(-tag.width / 2, tagGap),
      };
      tag.paint(canvas, view.toScreen(apex) + inward);

      _openingMark(canvas, opening);
    }
  }

  /// The `<` or `>` the user drew, shown where they drew it.
  ///
  /// Not decoration: it is the record of who decided this section opens. The
  /// mark stays at the point it was made, so the drawing can be checked
  /// against the instruction it came from.
  /// How far above a bottom-hinged apex the direction tag sits.
  static const double tagGap = 18;

  void _openingMark(Canvas canvas, OpeningElement opening) {
    final at = opening.markAt;
    // The glyph of what the opening does now. Where the user has changed it
    // since drawing the mark, the drawing shows what is built rather than
    // what was first asked for — the inspector keeps the record of both.
    final glyph = opening.mechanism.glyph ?? opening.markGlyph;
    if (at == null || glyph == null) return;

    final chosen = opening.id == selectedId;

    final on = view.toScreen(at);
    final text = Cad.label(
      glyph,
      colour: Cad.dimension,
      size: 15,
      weight: FontWeight.w700,
    );
    final box = Rect.fromCenter(
      center: on,
      width: text.width + 13,
      height: text.height + 7,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(5)),
      Cad.fill(Cad.sheet),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(5)),
      chosen
          ? Cad.stroke(Cad.selection, 2.2)
          : Cad.stroke(Cad.dimension.withValues(alpha: 0.6), Cad.annotation),
    );
    text.paint(
      canvas,
      Offset(on.dx - text.width / 2, on.dy - text.height / 2),
    );
  }

  void _hardware(Canvas canvas) {
    for (final piece in design.hardware) {
      final at = view.toScreen(piece.at);
      final scale = math.max(design.widthMm, design.heightMm);
      final length = view.lengthToScreen(
        (switch (piece.kind) {
          HardwareKind.lever => scale * 0.07,
          HardwareKind.handle => scale * 0.09,
          HardwareKind.letterplate => scale * 0.22,
          _ => scale * 0.035,
        })
            .clamp(24.0, 420.0),
      );
      final width = math.max(3.0, length * 0.26);

      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(piece.rotation * math.pi / 180);
      final body = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: length, height: width),
        Radius.circular(width / 2),
      );
      canvas.drawRRect(body, Cad.fill(Cad.sheet));
      canvas.drawRRect(body, Cad.stroke(Cad.heavy, Cad.bar));
      canvas.restore();

      // A cross at the exact point, because that is where it goes.
      final tick = view.lengthToScreen(math.max(scale * 0.006, 8));
      final paint = Cad.stroke(Cad.medium, Cad.hairline);
      canvas.drawLine(at - Offset(tick, 0), at + Offset(tick, 0), paint);
      canvas.drawLine(at - Offset(0, tick), at + Offset(0, tick), paint);
    }
  }

  // ------------------------------------------------------------- dimensions

  void _chains(Canvas canvas) {
    final frame = design.frame!;
    for (final chain in DimensionChains.of(design)) {
      final out = Cad.dimensionGap + chain.row * Cad.dimensionStep;
      for (final run in chain.runs) {
        if (chain.axis == DimensionAxis.horizontal) {
          _horizontalRun(canvas, run, frame.outline.bottom, out);
        } else {
          _verticalRun(canvas, run, frame.outline.left, out);
        }
      }
      _chainName(canvas, chain, frame.outline, out);
    }
    _sectionSizes(canvas);
  }

  /// What a row of dimensions is measuring, at the end of it.
  ///
  /// A chain of daylight openings does not add up to the overall size — the
  /// frame and the bars are the difference — so each row says which it is
  /// rather than leaving the reader to work out why the numbers disagree.
  void _chainName(
    Canvas canvas,
    DimensionChain chain,
    Polygon outline,
    double outPixels,
  ) {
    if (chain.runs.isEmpty) return;
    final text = Cad.label(
      chain.runs.first.note.toUpperCase(),
      colour: Cad.dimension.withValues(alpha: 0.75),
      size: Cad.smallTextSize,
      weight: FontWeight.w700,
    );

    if (chain.axis == DimensionAxis.horizontal) {
      final y = view.toScreen(Vec2(0, outline.bottom)).dy + outPixels;
      final x = view.toScreen(Vec2(outline.right, 0)).dx + 14;
      text.paint(canvas, Offset(x, y - text.height / 2));
    } else {
      // Below the chain and turned to read up it, so two rows of vertical
      // dimensions never print their names on top of each other.
      final x = view.toScreen(Vec2(outline.left, 0)).dx - outPixels;
      final y = view.toScreen(Vec2(0, outline.bottom)).dy + 14;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(-math.pi / 2);
      text.paint(canvas, Offset(-text.width, -text.height / 2));
      canvas.restore();
    }
  }

  /// Every section's own size, written in it.
  ///
  /// The chains give the story along each edge; this gives the figure for
  /// each pane, including the ones no chain can reach — a section in a
  /// column of its own, or one bounded by a bar that stops part way.
  void _sectionSizes(Canvas canvas) {
    for (final section in design.sections) {
      // A width and a height describe a rectangle. On a triangle they would
      // be the box around it, which is not the pane and not what anybody
      // would cut — so a section that is not a rectangle is left to the
      // dimensions and the inspector rather than being labelled wrongly.
      if (!_isRectangle(section.outline)) continue;

      final across = view.lengthToScreen(section.widthMm);
      final down = view.lengthToScreen(section.heightMm);
      if (across < 62 || down < 26) continue;

      final text = Cad.label(
        '${section.widthMm.round()} × ${section.heightMm.round()}',
        colour: Cad.light,
        size: Cad.smallTextSize,
        weight: FontWeight.w600,
      );
      // Where the user marked this section, their mark has the middle and
      // the size steps aside. Their instruction is the more important of
      // the two things written there.
      final marked = design.openingOf(section.id)?.markAt != null;
      final at = view.toScreen(section.outline.centroid) +
          (marked ? const Offset(0, -19) : Offset.zero);
      final box = Rect.fromCenter(
        center: at,
        width: text.width + 9,
        height: text.height + 3,
      );
      canvas.drawRect(box, Cad.fill(Cad.sheet.withValues(alpha: 0.9)));
      text.paint(
        canvas,
        Offset(at.dx - text.width / 2, at.dy - text.height / 2),
      );
    }
  }

  void _horizontalRun(
    Canvas canvas,
    ChainRun run,
    double fromMm,
    double outPixels,
  ) {
    final base = view.toScreen(Vec2(0, fromMm)).dy;
    final y = base + outPixels;
    final x1 = view.toScreen(Vec2(run.fromMm, 0)).dx;
    final x2 = view.toScreen(Vec2(run.toMm, 0)).dx;
    if ((x2 - x1).abs() < 3) return;

    final paint = Cad.stroke(Cad.dimension, Cad.annotation);
    // Witness lines, standing off the geometry so they never touch it.
    for (final x in [x1, x2]) {
      canvas.drawLine(
        Offset(x, base + Cad.witnessGap),
        Offset(x, y + Cad.witnessOvershoot),
        paint,
      );
    }
    canvas.drawLine(Offset(x1, y), Offset(x2, y), paint);
    _tick(canvas, Offset(x1, y), paint);
    _tick(canvas, Offset(x2, y), paint);

    _dimensionLabel(
      canvas,
      '${run.valueMm.round()}',
      Offset((x1 + x2) / 2, y),
      horizontal: true,
    );
  }

  void _verticalRun(
    Canvas canvas,
    ChainRun run,
    double fromMm,
    double outPixels,
  ) {
    final base = view.toScreen(Vec2(fromMm, 0)).dx;
    final x = base - outPixels;
    final y1 = view.toScreen(Vec2(0, run.fromMm)).dy;
    final y2 = view.toScreen(Vec2(0, run.toMm)).dy;
    if ((y2 - y1).abs() < 3) return;

    final paint = Cad.stroke(Cad.dimension, Cad.annotation);
    for (final y in [y1, y2]) {
      canvas.drawLine(
        Offset(base - Cad.witnessGap, y),
        Offset(x - Cad.witnessOvershoot, y),
        paint,
      );
    }
    canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
    _tick(canvas, Offset(x, y1), paint);
    _tick(canvas, Offset(x, y2), paint);

    _dimensionLabel(
      canvas,
      '${run.valueMm.round()}',
      Offset(x, (y1 + y2) / 2),
      horizontal: false,
    );
  }

  /// The forty-five degree slash that building drawings use instead of an
  /// arrowhead.
  void _tick(Canvas canvas, Offset at, Paint paint) {
    const reach = 4.0;
    canvas.drawLine(
      at + const Offset(-reach, reach),
      at + const Offset(reach, -reach),
      paint,
    );
  }

  void _dimensionLabel(
    Canvas canvas,
    String text,
    Offset at, {
    required bool horizontal,
  }) {
    final painter = Cad.label(
      text,
      colour: Cad.dimension,
      weight: FontWeight.w600,
    );
    canvas.save();
    canvas.translate(at.dx, at.dy);
    if (!horizontal) canvas.rotate(-math.pi / 2);

    final box = Rect.fromCenter(
      center: Offset.zero,
      width: painter.width + 8,
      height: painter.height + 1,
    );
    canvas.drawRect(box, Cad.fill(Cad.sheet));
    painter.paint(
      canvas,
      Offset(-painter.width / 2, -painter.height / 2 - 1),
    );
    canvas.restore();
  }

  /// The dimensions the user drew themselves, where they put them.
  void _userDimensions(Canvas canvas) {
    for (final dimension in design.dimensions) {
      final line = Segment(dimension.a, dimension.b);
      if (line.length < 1e-6) continue;
      final off = line.unit.perpendicular * dimension.offsetMm;
      final from = view.toScreen(dimension.a + off);
      final to = view.toScreen(dimension.b + off);
      final paint = Cad.stroke(Cad.dimension, Cad.annotation);

      canvas.drawLine(view.toScreen(dimension.a), from, paint);
      canvas.drawLine(view.toScreen(dimension.b), to, paint);
      canvas.drawLine(from, to, paint);
      _tick(canvas, from, paint);
      _tick(canvas, to, paint);

      final text = dimension.isStated
          ? '${dimension.valueMm.round()}'
          : '${dimension.valueMm.round()} ~';
      _dimensionLabel(
        canvas,
        text,
        Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2),
        horizontal: (to.dy - from.dy).abs() < (to.dx - from.dx).abs(),
      );
    }
  }

  void _annotations(Canvas canvas) {
    for (final note in design.texts) {
      final painter = Cad.label(note.text, colour: Color(note.colour));
      final at = view.toScreen(note.at);
      canvas.drawRect(
        Rect.fromLTWH(
          at.dx - 3,
          at.dy - painter.height / 2 - 2,
          painter.width + 6,
          painter.height + 4,
        ),
        Cad.fill(Cad.sheet),
      );
      painter.paint(canvas, Offset(at.dx, at.dy - painter.height / 2));
      canvas.drawCircle(at, 2.2, Cad.fill(Cad.heavy));
    }

    for (final arrow in design.arrows) {
      final from = view.toScreen(arrow.from);
      final to = view.toScreen(arrow.to);
      final paint = Cad.stroke(Color(arrow.colour), Cad.annotation);
      canvas.drawLine(from, to, paint);
      final delta = to - from;
      final length = delta.distance;
      if (length < 1) continue;
      final unit = delta / length;
      final across = Offset(-unit.dy, unit.dx);
      final head = math.min(11.0, length * 0.3);
      canvas.drawLine(to, to - unit * head + across * head * 0.38, paint);
      canvas.drawLine(to, to - unit * head - across * head * 0.38, paint);
    }
  }

  // -------------------------------------------------------------- selection

  void _selection(Canvas canvas) {
    final ids = {...highlighted, ?selectedId};
    for (final id in ids) {
      final element = design.elementById(id);
      if (element == null) continue;
      final chosen = id == selectedId;
      final paint = Cad.stroke(
        Cad.selection.withValues(alpha: chosen ? 1 : 0.55),
        chosen ? 2.2 : 1.6,
      );

      switch (element) {
        case FrameElement():
          canvas.drawPath(view.pathOf(element.outline), paint);
        case FrameMemberElement():
          // The one side, drawn as thick as the profile it is, so picking a
          // jamb shows the jamb rather than a line through the middle of it.
          canvas.drawLine(
            view.toScreen(element.run.a),
            view.toScreen(element.run.b),
            paint
              ..strokeWidth = math.max(
                3,
                view.lengthToScreen(design.frame?.profileMm ?? 60),
              )
              ..color = Cad.selection.withValues(alpha: 0.4),
          );
        case SectionElement():
          canvas.drawPath(view.pathOf(element.outline), paint);
        case DividerElement():
          canvas.drawPath(view.pathOf(_barBody(element)), paint);
        case HardwareElement():
          canvas.drawCircle(view.toScreen(element.at), 14, paint);
        case DimensionElement():
          canvas.drawLine(
            view.toScreen(element.a),
            view.toScreen(element.b),
            paint,
          );
        case ArrowElement():
          canvas.drawLine(
            view.toScreen(element.from),
            view.toScreen(element.to),
            paint,
          );
        case TextElement():
          canvas.drawCircle(view.toScreen(element.at), 13, paint);
        case OpeningElement():
          final section = design.sectionById(element.sectionId);
          if (section != null) {
            canvas.drawPath(view.pathOf(section.outline), paint);
          }
      }
    }
  }

  /// The little squares you take hold of to change a boundary.
  void _grips(Canvas canvas) {
    for (final grip in grips) {
      final at = view.toScreen(grip.at);
      final box = Rect.fromCenter(center: at, width: 9, height: 9);
      canvas.drawRect(box, Cad.fill(Cad.sheet));
      canvas.drawRect(box, Cad.stroke(Cad.grip, 1.6));
    }
  }

  void _snap(Canvas canvas) {
    final at = snapAt;
    if (at == null) return;
    final on = view.toScreen(at);
    final paint = Cad.stroke(Cad.snap, 1.6);
    canvas.drawCircle(on, 7, paint);
    canvas.drawLine(on - const Offset(11, 0), on + const Offset(11, 0), paint);
    canvas.drawLine(on - const Offset(0, 11), on + const Offset(0, 11), paint);
  }

  @override
  bool shouldRepaint(CadPainter old) =>
      old.design != design ||
      old.view.scale != view.scale ||
      old.view.origin != view.origin ||
      old.selectedId != selectedId ||
      old.layers != layers ||
      old.snapAt != snapAt ||
      old.grips.length != grips.length ||
      old.highlighted.length != highlighted.length;
}

/// A point you can take hold of to change the geometry.
///
/// A grip says what it moves, not what it belongs to: taking hold of the
/// edge of a pane moves the bar that makes that edge, because the pane is
/// the space between the bars and has no edges of its own to move.
class Grip {
  final Vec2 at;

  /// The element the grip is shown on.
  final String elementId;

  final GripKind kind;

  /// The bar this grip actually moves, where it moves one.
  final String? dividerId;

  /// The frame edge this grip actually moves, where it moves one.
  final int? memberIndex;

  const Grip({
    required this.at,
    required this.elementId,
    required this.kind,
    this.dividerId,
    this.memberIndex,
  });

  /// True where the grip moves something square to itself rather than to a
  /// point — a boundary, which has one direction that means anything.
  bool get isBoundary => kind == GripKind.boundary;
}

enum GripKind {
  /// Moves the whole thing.
  move,

  /// Moves one end of a bar, or one end of a dimension.
  endStart,
  endFinish,

  /// Moves a boundary square to itself: a bar, or one side of the frame.
  boundary,

  /// Slides a dimension line away from what it measures.
  offset,
}
