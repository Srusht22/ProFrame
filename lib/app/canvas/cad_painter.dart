import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/dimensions/measurements.dart';
import '../../domain/dimensions/units.dart';
import '../../domain/geometry/polygon.dart';
import '../../domain/geometry/segment.dart';
import '../../domain/geometry/vec2.dart';
import '../../domain/hardware/opening_hardware.dart';
import '../../domain/model/design.dart';
import '../../domain/model/design_geometry.dart';
import '../../domain/model/design_tree.dart';
import '../../domain/model/elements.dart';
import '../../domain/model/materials.dart';
import '../../domain/model/opening_leaf.dart';
import '../../domain/model/surface.dart';
import 'cad_layers.dart';
import 'cad_style.dart';
import 'dimension_handles.dart';
import 'dimension_layout.dart';
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

  /// Where a line tool would put a line if the user clicked now, and the
  /// opening it would go in. Shown as a ghost, so the user places the line
  /// having seen exactly where it lands.
  final Segment? guide;
  final Polygon? guideWithin;

  /// The colours the drawing is drawn in: paper, unless the appearance in
  /// effect is dark.
  final CadColours ink;

  const CadPainter({
    required this.design,
    required this.view,
    required this.layers,
    this.selectedId,
    this.highlighted = const {},
    this.snapAt,
    this.grips = const [],
    this.guide,
    this.guideWithin,
    this.ink = Cad.paper,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Cad.fill(ink.sheet));
    if (layers.grid) _grid(canvas, size);

    if (design.frame == null) return;

    // The drawing is built up the way the design is put together, not by
    // sweeping flat lists: the frame, the bars that divide the design, its
    // main divisions, and inside each of those whatever the user drew there.
    // The tree is the model's own hierarchy read once — the solid walks the
    // same one — so the elevation cannot decide that something is inside
    // something else by a route the model does not have.
    final tree = DesignTree.of(design);

    if (layers.sketch) _sketch(canvas);
    _infill(canvas, tree.sections);
    _frame(canvas);
    _bars(canvas, tree.barIds, inside: false);
    for (final section in tree.everySection) {
      _bars(canvas, section.barIds, inside: true);
    }
    if (layers.openings) _openings(canvas, tree);
    if (layers.annotations) _materialNames(canvas, tree.sections);
    _hardware(canvas);
    if (layers.dimensions) {
      _chains(canvas, size, tree);
      _userDimensions(canvas);
    }
    if (layers.annotations) _annotations(canvas);
    _selection(canvas);
    if (layers.grips) _grips(canvas);
    _guide(canvas);
    _snap(canvas);
  }

  /// The opening being drawn inside, and where the line would land.
  ///
  /// The opening is outlined so it is plain what the line will belong to,
  /// because a line drawn inside an opening is that opening's and nothing
  /// about the drawing afterwards would say so more clearly than this does
  /// beforehand.
  void _guide(Canvas canvas) {
    final within = guideWithin;
    if (within != null && !within.isEmpty) {
      canvas.drawPath(
        view.pathOf(within),
        Cad.stroke(ink.selection, Cad.profile),
      );
    }
    final line = guide;
    if (line == null) return;
    canvas.drawLine(
      view.toScreen(line.a),
      view.toScreen(line.b),
      Cad.stroke(ink.selection, Cad.outline),
    );
  }

  // ------------------------------------------------------------------ paper

  void _grid(Canvas canvas, Size size) {
    for (final (step, colour) in [
      (100.0, ink.grid),
      (1000.0, ink.gridStrong),
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
        Cad.stroke(ink.hidden.withValues(alpha: 0.4), 1.1, round: true),
      );
    }
  }

  // --------------------------------------------------------------- geometry

  /// What fills each section, drawn the way a drawing shows a material
  /// rather than the way a photograph shows it.
  ///
  /// Down the tree: a section the user drew lines in is filled by the panes
  /// those lines make, not by a pane of its own painted over them, and each
  /// of those panes may have been divided again.
  void _infill(Canvas canvas, List<TreeSection> branches) {
    for (final branch in branches) {
      if (!branch.isLeaf) {
        _infill(canvas, branch.panes);
        continue;
      }
      final section = design.sectionById(branch.sectionId);
      if (section == null) continue;

      // A section that opens — and every pane the user divided it into — is
      // filled to the daylight of its own leaf, not to the edge of the
      // region: the sash is real material and the glass stops at it, as it
      // does in the model and as it will on the bench.
      final outline = OpeningLeaf.fillOf(design, section);
      if (outline.isEmpty) continue;
      final path = view.pathOf(outline);

      // **The material says how it is indicated** — glass by the sheet's
      // pale glass tint and the two strokes across a corner, anything solid
      // by hatching on the paper — from its [CadIndication], the same
      // description the solid is shaded from. A panel's colour is written
      // on it by name (see `_materialNames`), never flooded over it.
      final cad = section.finish.material.surface.cad;
      canvas.drawPath(
        path,
        Cad.fill(
          cad.inGlassTint
              ? Color.lerp(ink.glass, Color(section.finish.colour), cad.shade)!
              : ink.sheet,
        ),
      );
      if (layers.hatching) {
        if (cad.stipple) _stipple(canvas, outline);
        _indicate(canvas, outline, path, cad.hatch);
      }

      canvas.drawPath(path, Cad.stroke(ink.medium, Cad.detail));

      // The glazing bead, where it is on the face this is a drawing of: the
      // line it stops at on the glass, from the one answer the solid runs
      // its bead to. A fine line, because it is an edge of a strip of the
      // frame, not an outline.
      final bead = DesignGeometry.of(design).beadLineOf(section, outline);
      if (bead != null) {
        canvas.drawPath(view.pathOf(bead), Cad.stroke(ink.light, Cad.hairline));
      }
    }
  }

  /// What fills each part, written on it — GLASS, PANEL — as a joiner's
  /// elevation says it, so the drawing carries what the user chose and not
  /// only the hatching that stands for it.
  ///
  /// Written above where the part's size goes, and only where the part is
  /// big enough on the screen to hold both; the part itself is drawn from
  /// the design's outline, so nothing here can move a line.
  void _materialNames(Canvas canvas, List<TreeSection> branches) {
    for (final branch in branches) {
      if (!branch.isLeaf) {
        _materialNames(canvas, branch.panes);
        continue;
      }
      final section = design.sectionById(branch.sectionId);
      if (section == null) continue;
      if (view.lengthToScreen(section.widthMm) < 62) continue;
      if (view.lengthToScreen(section.heightMm) < 44) continue;

      final finish = section.finish;
      final look = GlassLook.of(finish);
      // A panel's colour is named, as a joiner's schedule names it, rather
      // than painted: PANEL · BROWN. A colour of the user's own has no name
      // to give, and is left to the part's own panel.
      final colour = PanelColour.of(finish);
      final word = finish.material.surface.cad.inGlassTint
          ? (look == null || look == GlassLook.clear
                ? 'GLASS'
                : '${look.label.toUpperCase()} GLASS')
          : [
              finish.material.label.toUpperCase().replaceFirst('SOLID ', ''),
              ?colour?.label.toUpperCase(),
            ].join(' · ');
      // Only where the word fits inside the part it names.
      final wide = Cad.label(
        word,
        size: Cad.smallTextSize,
        weight: FontWeight.w600,
        spacing: 1.1,
      ).width;
      if (view.lengthToScreen(section.widthMm) < wide + 10) continue;
      final marked = design.openingOf(section.id)?.markAt != null;
      final at =
          view.toScreen(section.outline.centroid) +
          Offset(0, marked ? -35 : -16);
      // Spaced capitals, as a drawing letters what a part is — masked by
      // the paper round each letter, not boxed.
      Cad.write(
        canvas,
        word,
        at,
        colour: ink.medium,
        paper: ink.sheet,
        size: Cad.smallTextSize,
        weight: FontWeight.w600,
        spacing: 1.1,
      );
    }
  }

  /// A part's material indicated inside [outline] as a drafting convention.
  void _indicate(Canvas canvas, Polygon outline, Path path, CadHatch hatch) {
    switch (hatch) {
      case CadHatch.glazing:
        _glazingMark(canvas, outline);
      case CadHatch.diagonal:
        _hatch(canvas, outline);
      case CadHatch.solid:
        canvas.drawPath(path, Cad.fill(ink.heavy.withValues(alpha: 0.85)));
      case CadHatch.none:
        break;
    }
  }

  /// Fine dots across a part: the drawing's mark for obscured glass, which
  /// lets light through and no view. Light enough that every line drawn
  /// over the part still reads.
  void _stipple(Canvas canvas, Polygon outline) {
    final path = view.pathOf(outline);
    final bounds = path.getBounds();
    if (bounds.width < 6 || bounds.height < 6) return;
    canvas.save();
    canvas.clipPath(path);
    final dot = Paint()..color = ink.glassLine.withValues(alpha: 0.55);
    const spacing = 7.0;
    var row = 0;
    for (var y = bounds.top + spacing / 2; y < bounds.bottom; y += spacing) {
      final offset = row.isEven ? 0.0 : spacing / 2;
      for (var x = bounds.left + offset; x < bounds.right; x += spacing) {
        canvas.drawCircle(Offset(x, y), 0.7, dot);
      }
      row++;
    }
    canvas.restore();
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
    final paint = Cad.stroke(ink.glassLine, Cad.hairline);
    for (final inset in [0.0, 5.0]) {
      canvas.drawLine(
        topRight + Offset(-reach - inset, inset),
        topRight + Offset(-inset, reach + inset),
        paint,
      );
    }
    canvas.restore();
  }

  /// Forty-five degree hatching, for a solid infill — a panel. Evenly
  /// spaced fine lines on the paper: plainly not glass, and quiet enough
  /// that the part's outline and its name read over it.
  void _hatch(Canvas canvas, Polygon outline) {
    final path = view.pathOf(outline);
    final bounds = path.getBounds();
    if (bounds.width < 6 || bounds.height < 6) return;

    canvas.save();
    canvas.clipPath(path);
    final paint = Cad.stroke(ink.hatch, Cad.hairline);
    const spacing = 8.0;
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

  /// The frame, drawn as a profile: the outside heavy, the daylight edge
  /// lighter, exactly on the outline the user drew.
  void _frame(Canvas canvas) {
    final frame = design.frame!;
    // Side by side rather than as two closed outlines, because a side the
    // user left open has no member and so no line.
    final lines = frame.lines;
    final inner = frame.innerOutline;
    // The frame is structure: laid in the structural tone, whatever it is
    // made of, under its lines — which is what tells it at a glance from
    // the glass and the panels it holds.
    if (layers.hatching && !inner.isEmpty) {
      _structure(canvas, frame.outline, inner);
    }
    final heavy = Cad.stroke(ink.heavy, Cad.outline);
    for (final edge in lines.outside) {
      canvas.drawLine(view.toScreen(edge.a), view.toScreen(edge.b), heavy);
    }
    if (!inner.isEmpty) {
      final medium = Cad.stroke(ink.medium, Cad.profile);
      for (final edge in lines.daylight) {
        canvas.drawLine(view.toScreen(edge.a), view.toScreen(edge.b), medium);
      }
      // What a joiner's elevation shows of the profile between the two: the
      // line where the frame's face turns into its sightline — the slope of
      // a PVC profile, an extrusion's shadow step. Fine lines, because they
      // are edges of the face and not its outline; from the same profile the
      // solid is swept along, so the two show one frame.
      final sightline = Cad.stroke(ink.light, Cad.hairline);
      for (final edge in DesignGeometry.of(design).frameSightlines) {
        canvas.drawLine(
          view.toScreen(edge.a),
          view.toScreen(edge.b),
          sightline,
        );
      }
    }
  }

  /// The ring between [outer] and [inner] — a frame's or a sash's members —
  /// laid in the structural tone: flat, with no lines of its own, so the
  /// structure reads as one band and its sightlines as edges on it.
  ///
  /// The ring is one path holding both outlines, filled even-odd: the inner
  /// lies wholly within the outer, so that is exactly the band between them
  /// on every renderer. A path difference was tried first and is not to come
  /// back — the web's renderer filled the whole of the outer with it, over
  /// the glass and the panels.
  void _structure(Canvas canvas, Polygon outer, Polygon inner) {
    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(view.pathOf(outer), Offset.zero)
      ..addPath(view.pathOf(inner), Offset.zero);
    canvas.drawPath(ring, Cad.fill(ink.structure));
  }

  /// Each bar as its two faces, at the angle it was drawn at.
  ///
  /// [inside] says which level of the tree these are: a bar that divides the
  /// design is a mullion or a transom and carries a mullion's weight, while a
  /// bar drawn inside a section is a glazing bar within it and is drawn
  /// lighter. That is what a drawing does with a smaller member, and it is
  /// what lets somebody reading the elevation see which bars belong to a
  /// sash without being told.
  void _bars(Canvas canvas, List<String> barIds, {required bool inside}) {
    for (final id in barIds) {
      final divider = design.dividerById(id);
      if (divider == null) continue;
      final body = _barBody(divider);
      if (body.isEmpty) continue;
      // A bar is structure too — the frame's own tone, so a mullion reads
      // as part of what holds the glass and the panels and never as one of
      // them.
      canvas.drawPath(
        view.pathOf(body),
        Cad.fill(layers.hatching ? ink.structure : ink.sheet),
      );
      canvas.drawPath(
        view.pathOf(body),
        Cad.stroke(inside ? ink.medium : ink.heavy,
            inside ? Cad.glazingBar : Cad.bar),
      );

      // The centre line, as a drawing shows the axis of a member.
      if (layers.centreLines) {
        final line = Path()
          ..moveTo(view.toScreen(divider.a).dx, view.toScreen(divider.a).dy)
          ..lineTo(view.toScreen(divider.b).dx, view.toScreen(divider.b).dy);
        canvas.drawPath(
          Cad.dashed(line, dash: 12, gap: 3),
          Cad.stroke(ink.light.withValues(alpha: 0.75), Cad.hairline),
        );
      }
    }
  }

  /// The body a bar occupies: [DesignGeometry.barBody], the one the solid
  /// builds — stopped at the frame's inner face, or at the sash when it is a
  /// bar inside an opening, because a glazing bar runs between the faces of
  /// the sash it is in and not over them.
  Polygon _barBody(DividerElement divider) =>
      DesignGeometry.of(design).barBody(divider);

  /// The swing lines: the standard elevation symbol, dashed, pointing at the
  /// hinge.
  void _openings(Canvas canvas, DesignTree tree) {
    for (final branch in tree.openings) {
      final opening = design.openingById(branch.openingId!);
      final section = design.sectionById(branch.sectionId);
      if (opening == null || section == null) continue;
      _leaf(canvas, section);
      final box = section.outline;
      final edge = opening.mechanism.hingeEdge;
      // How a leaf opens is a reference line, not the leaf: thin, and in the
      // lighter ink, so the swing never reads as a member.
      final paint = Cad.stroke(ink.light, Cad.annotation);

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

      // On the leaf's own edges, so a raked leaf's swing starts on the
      // stile it hangs on rather than at the corners of its box.
      final (hingeA, hingeB, apex) = OpeningHardware.swingOf(box, edge);

      final swing = Path()
        ..moveTo(view.toScreen(hingeA).dx, view.toScreen(hingeA).dy)
        ..lineTo(view.toScreen(apex).dx, view.toScreen(apex).dy)
        ..lineTo(view.toScreen(hingeB).dx, view.toScreen(hingeB).dy);
      canvas.drawPath(Cad.dashed(swing), paint);

      // Which way it opens, in words, because a triangle alone does not say.
      final tag = Cad.label(
        opening.direction == OpeningDirection.outward ? 'OUT' : 'IN',
        colour: ink.light,
        size: Cad.smallTextSize,
        weight: FontWeight.w600,
        spacing: 1.1,
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
      // The apex is on the stile the handle is on, half way along it — where
      // the handle is — so the word steps along that stile until it is clear
      // of every piece of this leaf's ironmongery, rather than lying on it.
      var word = (view.toScreen(apex) + inward) & Size(tag.width, tag.height);
      final pieces = [
        for (final piece in design.hardware)
          if (design.openingHolding(piece.parentId)?.id == opening.id &&
              (layers.hiddenDetail || !design.isConcealed(piece)))
            for (final shape in DesignGeometry.of(design).hardwareOf(piece))
              if (!shape.isEmpty) view.pathOf(shape).getBounds().inflate(3),
      ]..sort((a, b) => a.top.compareTo(b.top));
      final sideHung = edge == OpeningEdge.left || edge == OpeningEdge.right;
      for (var round = 0; round < pieces.length; round++) {
        final hit = pieces.where((p) => p.overlaps(word)).toList();
        if (hit.isEmpty) break;
        word = sideHung
            ? word.translate(
                0,
                hit.map((p) => p.bottom).reduce(math.max) - word.top,
              )
            : word.translate(
                hit.map((p) => p.right).reduce(math.max) - word.left,
                0,
              );
      }
      tag.paint(canvas, word.topLeft);

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

  /// The boundary of the leaf: its own frame, inside the region that opens.
  ///
  /// An opening is a specific region of the design and the leaf filling it is
  /// a thing of its own, with an edge of its own. Drawing that edge is what
  /// makes the elevation say where the opening stops — and it stops at the
  /// section, never at the window. It is the same leaf the solid builds, from
  /// the same description, so the two cannot disagree about where it is.
  void _leaf(Canvas canvas, SectionElement section) {
    final frame = design.frame;
    if (frame == null) return;
    final inner = OpeningLeaf.innerOf(section, frame);
    if (inner == null) return;

    final outer = OpeningLeaf.outerOf(section);
    if (layers.hatching) _structure(canvas, outer, inner);
    canvas.drawPath(view.pathOf(outer), Cad.stroke(ink.medium, Cad.profile));
    canvas.drawPath(view.pathOf(inner), Cad.stroke(ink.medium, Cad.profile));
  }

  void _openingMark(Canvas canvas, OpeningElement opening) {
    final at = opening.markAt;
    // The glyph of what the opening does now. Where the user has changed it
    // since drawing the mark, the drawing shows what is built rather than
    // what was first asked for — the inspector keeps the record of both.
    final glyph = opening.mechanism.glyph ?? opening.markGlyph;
    if (at == null || glyph == null) return;

    final chosen = opening.id == selectedId;

    // A drawing's tag: the glyph in a thin circle, where it was drawn — a
    // reference to the instruction, in the annotation ink, not a button.
    final on = view.toScreen(at);
    final text = Cad.label(
      glyph,
      colour: ink.dimension,
      size: 13,
      weight: FontWeight.w600,
    );
    final radius = math.max(text.width, text.height) / 2 + 4;
    canvas.drawCircle(on, radius, Cad.fill(ink.sheet));
    canvas.drawCircle(
      on,
      radius,
      chosen
          ? Cad.stroke(ink.selection, 2.2)
          : Cad.stroke(ink.dimension, Cad.annotation),
    );
    text.paint(
      canvas,
      Offset(on.dx - text.width / 2, on.dy - text.height / 2),
    );
  }

  void _hardware(Canvas canvas) {
    final geometry = DesignGeometry.of(design);
    for (final piece in design.hardware) {
      // **A piece on the face this drawing is not of is hidden detail.** A
      // door is drawn from outside, so its hinges are round the back and
      // cannot be seen standing where this elevation is drawn from — so by
      // default they are not drawn, as they are not seen in the solid. The
      // **Hidden** layer puts them back dashed, as a joiner's hidden
      // detail, because somebody still has to fit them. A window is drawn
      // from inside, where its hinges are, so they are solid.
      // `Design.isConcealed` is the one answer, read here and by the solid
      // alike.
      final concealed = design.isConcealed(piece);
      if (concealed && !layers.hiddenDetail) continue;

      // **Drawn as the shapes it is built as**, from the one description
      // the solid stands off the leaf: a lever's backplate, rose and arm, a
      // window handle's base, boss and arm, a hinge's leaf and knuckle, each
      // sized from the leaf it is on. A screen's cassette and a sensor are
      // fixed to the frame and drawn as their footprints.
      final onFrame = OpeningHardware.footprintOf(design, piece) != null;
      final shapes = geometry.hardwareOf(piece);
      final bores = geometry.boresOf(piece);
      for (final shape in shapes) {
        if (shape.isEmpty) continue;
        final path = view.pathOf(shape);
        if (!concealed && bores.contains(shape)) {
          // A hole through the piece — a keyhole — is drawn solid, as a
          // hole is on a drawing.
          canvas.drawPath(path, Cad.fill(ink.heavy));
          continue;
        }
        if (concealed) {
          canvas.drawPath(
            Cad.dashed(path, dash: 6, gap: 4),
            Cad.stroke(ink.hidden, Cad.hairline),
          );
        } else {
          canvas.drawPath(path, Cad.fill(ink.sheet));
          canvas.drawPath(
            path,
            onFrame
                ? Cad.stroke(ink.medium, Cad.hairline)
                : Cad.stroke(ink.heavy, Cad.glazingBar),
          );
        }
      }
      // A cross at the exact point, because that is where it goes — on the
      // piece. A pull is set in from the point it is placed by, onto the
      // middle of its stile, and a cross off to its side would mark nothing.
      if (onFrame || !shapes.any((s) => s.contains(piece.at))) continue;
      final at = view.toScreen(piece.at);
      final scale = math.max(design.widthMm, design.heightMm);
      final tick = view.lengthToScreen(math.max(scale * 0.006, 8));
      final paint = Cad.stroke(
          concealed ? ink.hidden : ink.medium, Cad.hairline);
      canvas.drawLine(at - Offset(tick, 0), at + Offset(tick, 0), paint);
      canvas.drawLine(at - Offset(0, tick), at + Offset(0, tick), paint);
    }
  }

  // ------------------------------------------------------------- dimensions

  /// Every chain of dimensions, where [DimensionLayout] puts it — the same
  /// answer the figures are tapped by.
  void _chains(Canvas canvas, Size size, DesignTree tree) {
    final layout = DimensionLayout.of(design, view, canvas: size);
    final paint = Cad.stroke(ink.dimension, Cad.annotation);
    for (final placed in layout.figures) {
      // Witness lines, standing off the geometry so they never touch it.
      canvas
        ..drawLine(placed.witnessFrom.$1, placed.witnessFrom.$2, paint)
        ..drawLine(placed.witnessTo.$1, placed.witnessTo.$2, paint);
      // The dimension line runs a little past each witness line, as a
      // building drawing's does, so a chain reads as one continuous line.
      final along = placed.to - placed.from;
      final unit = along / math.max(along.distance, 1e-9);
      canvas.drawLine(
        placed.from - unit * _runPast,
        placed.to + unit * _runPast,
        paint,
      );
      // Where the figure stands beyond a run too short to hold it, the line
      // is carried on to it.
      if (placed.leader case (final from, final to)) {
        canvas.drawLine(from, to, paint);
      }
      _tick(canvas, placed.from);
      _tick(canvas, placed.to);
      _dimensionLabel(
        canvas,
        placed.text,
        placed.figure,
        horizontal: !placed.turned,
      );
    }
    for (final name in layout.names) {
      Cad.write(
        canvas,
        name.text,
        name.at,
        colour: ink.dimension.withValues(alpha: 0.75),
        paper: ink.sheet,
        size: Cad.smallTextSize - 0.5,
        weight: FontWeight.w600,
        spacing: 1.1,
        turned: name.turned,
      );
    }
    _sectionSizes(
      canvas,
      tree.sections,
      Measurements.of(design),
      DimensionLayout.places,
    );
  }

  /// Every section's own size, written in it.
  ///
  /// The chains give the story along each edge; this gives the figure for
  /// each pane, including the ones no chain can reach — a section in a
  /// column of its own, or one bounded by a bar that stops part way.
  ///
  /// Down the tree, like every other pass: a branch is labelled by its
  /// panes, not by a figure of its own written across them. Asking the tree
  /// is asking the design; working it out here would be a second opinion
  /// about the same thing.
  void _sectionSizes(
    Canvas canvas,
    List<TreeSection> branches,
    List<Measure> sizes,
    int places,
  ) {
    for (final branch in branches) {
      if (!branch.isLeaf) {
        _sectionSizes(canvas, branch.panes, sizes, places);
        continue;
      }
      final section = design.sectionById(branch.sectionId);
      if (section == null) continue;

      // A width and a height describe a rectangle. On a triangle they would
      // be the box around it, which is not the pane and not what anybody
      // would cut — so a section that is not a rectangle is left to the
      // dimensions and the inspector rather than being labelled wrongly.
      final at = CadDimensions.sectionSizeAt(design, view, section);
      if (at == null) continue;

      Cad.write(
        canvas,
        Measurements.sizeOf(design, section, sizes, places),
        at,
        colour: ink.dimension,
        paper: ink.sheet,
        size: Cad.smallTextSize,
        weight: FontWeight.w600,
      );
    }
  }

  /// How far a dimension line runs past the witness lines at its ends.
  static const double _runPast = 3;

  /// The forty-five degree slash that building drawings use instead of an
  /// arrowhead: a step heavier than the dimension line, so where each
  /// measurement starts and stops is plain at a glance.
  void _tick(Canvas canvas, Offset at) {
    const reach = 3.5;
    canvas.drawLine(
      at + const Offset(-reach, reach),
      at + const Offset(reach, -reach),
      Cad.stroke(ink.dimension, Cad.glazingBar),
    );
  }

  /// A figure, written where it goes — above its line for a chain, on it
  /// for a measurement the user drew — masked by the paper round its
  /// letters rather than a box, and turned to read up the page on a line
  /// running down it.
  void _dimensionLabel(
    Canvas canvas,
    String text,
    Offset at, {
    required bool horizontal,
  }) {
    Cad.write(
      canvas,
      text,
      at,
      colour: ink.dimension,
      paper: ink.sheet,
      weight: FontWeight.w600,
      turned: !horizontal,
    );
  }

  /// The dimensions the user drew themselves, where they put them.
  void _userDimensions(Canvas canvas) {
    for (final dimension in design.dimensions) {
      final line = Segment(dimension.a, dimension.b);
      if (line.length < 1e-6) continue;
      final off = line.unit.perpendicular * dimension.offsetMm;
      final from = view.toScreen(dimension.a + off);
      final to = view.toScreen(dimension.b + off);
      final paint = Cad.stroke(ink.dimension, Cad.annotation);

      canvas.drawLine(view.toScreen(dimension.a), from, paint);
      canvas.drawLine(view.toScreen(dimension.b), to, paint);
      canvas.drawLine(from, to, paint);
      _tick(canvas, from);
      _tick(canvas, to);

      // A dimension the user drew measures the sketch, which has a scale
      // only once the design's sizes are given; one they typed is theirs.
      final text = dimension.isStated
          ? Units.label(dimension.valueMm)
          : Measurements.complete(design)
              ? '${Units.label(dimension.valueMm)} ~'
              : '? ${Units.symbol}';
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
      // The same size on the sheet as the drawing gives it, so the two views
      // agree about how big the note is and it shrinks with the zoom.
      final size = view.letteringFor(note.sizeMm);
      if (size < 1) continue;
      final painter =
          Cad.label(
            note.text,
            colour: ink.legible(Color(note.colour)),
            size: size,
          );
      final at = view.toScreen(note.at);
      canvas.drawRect(
        Rect.fromLTWH(
          at.dx - 3,
          at.dy - painter.height / 2 - 2,
          painter.width + 6,
          painter.height + 4,
        ),
        Cad.fill(ink.sheet),
      );
      painter.paint(canvas, Offset(at.dx, at.dy - painter.height / 2));
      canvas.drawCircle(at, 2.2, Cad.fill(ink.heavy));
    }

    for (final arrow in design.arrows) {
      final from = view.toScreen(arrow.from);
      final to = view.toScreen(arrow.to);
      final paint = Cad.stroke(
        ink.legible(Color(arrow.colour)),
        Cad.annotation,
      );
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
        ink.selection.withValues(alpha: chosen ? 1 : 0.55),
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
              ..color = ink.selection.withValues(alpha: 0.4),
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
      canvas.drawRect(box, Cad.fill(ink.sheet));
      canvas.drawRect(box, Cad.stroke(ink.grip, 1.6));
    }
  }

  void _snap(Canvas canvas) {
    final at = snapAt;
    if (at == null) return;
    final on = view.toScreen(at);
    final paint = Cad.stroke(ink.snap, 1.6);
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
      old.ink != ink ||
      old.snapAt != snapAt ||
      old.grips.length != grips.length ||
      !setEquals(old.highlighted, highlighted);
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
