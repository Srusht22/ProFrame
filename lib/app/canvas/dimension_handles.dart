import 'package:flutter/material.dart';

import '../../domain/dimensions/dimension_chain.dart';
import '../../domain/dimensions/frame_sides.dart';
import '../../domain/dimensions/measurements.dart';
import '../../domain/geometry/polygon.dart';
import '../../domain/geometry/segment.dart';
import '../../domain/model/design.dart';
import '../../domain/model/elements.dart';
import '../../domain/text/words.dart';
import 'cad_layers.dart';
import 'cad_style.dart';
import 'dimension_layout.dart';
import 'view_transform.dart';

/// What a figure on the drawing measures, and so what typing over it means.
enum DimensionOf {
  /// The whole design, across.
  overallWidth,

  /// The whole design, down.
  overallHeight,

  /// One section's daylight, across.
  sectionWidth,

  /// One section's daylight, down.
  sectionHeight,

  /// A measurement the user drew themselves.
  drawn,

  /// One side of a frame that is not a rectangle; [DimensionHandle.elementId]
  /// is its `FrameSide.key`.
  side,
}

/// One figure on the drawing, and the geometry it stands for.
///
/// A dimension on a technical drawing is not a caption. It is the figure
/// for a real piece of the design, so it can be typed over, and typing over
/// it moves that piece — never the label alone.
class DimensionHandle {
  /// Where it is on screen, generously enough to be tapped.
  final Rect rect;

  final DimensionOf of;

  /// The section or dimension it names, when it names one.
  final String? elementId;

  /// What it reads now, in millimetres.
  final double valueMm;

  /// What to call it in the editor.
  final String label;

  /// Whether the user has given this size, directly or through the sizes
  /// it follows from. One they have not is written `?`, and its editor
  /// opens empty rather than offering the sketch's guess.
  final bool known;

  const DimensionHandle({
    required this.rect,
    required this.of,
    required this.valueMm,
    required this.label,
    this.elementId,
    this.known = true,
  });
}

/// Where the figures on a technical drawing sit.
///
/// Both the painter and the pointer come here, so what is drawn and what can
/// be tapped are the same thing by construction rather than by two pieces of
/// arithmetic agreeing with each other.
abstract final class CadDimensions {
  /// How far a tappable figure reaches either side of where it is written.
  static const Size labelReach = Size(78, 20);

  /// The same for a section's own `width × height`, which is two figures
  /// written as one line: the width to the left of the cross, the height to
  /// the right of it.
  static const Size sizeReach = Size(112, 20);

  /// Where a section writes its own size, or null when there is no room for
  /// it or no honest figure to write.
  static Offset? sectionSizeAt(
    Design design,
    ViewTransform view,
    SectionElement section,
  ) {
    if (design.hasChildren(section.id)) return null;
    if (!isRectangle(section.outline)) return null;
    if (view.lengthToScreen(section.heightMm) < 26) return null;
    // Only where it fits inside the pane, with room either side: a size
    // spilling over the bars into the next pane would be read as its.
    final written = Cad.label(
      Measurements.sizeOf(design, section, null, DimensionLayout.places),
      size: Cad.smallTextSize,
      weight: FontWeight.w600,
    ).width;
    if (view.lengthToScreen(section.widthMm) < written + 10) return null;

    // Where the user marked this section, their mark has the middle and the
    // size steps aside.
    final marked = design.openingOf(section.id)?.markAt != null;
    return view.toScreen(section.outline.centroid) +
        (marked ? const Offset(0, -19) : Offset.zero);
  }

  /// Where a measurement the user drew writes its figure.
  static Offset? drawnDimensionAt(
    ViewTransform view,
    DimensionElement dimension,
  ) {
    final line = Segment(dimension.a, dimension.b);
    if (line.length < 1e-6) return null;
    final off = line.unit.perpendicular * dimension.offsetMm;
    final from = view.toScreen(dimension.a + off);
    final to = view.toScreen(dimension.b + off);
    return Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
  }

  /// True when a width and a height really do describe this shape.
  ///
  /// Measured by area rather than by angle: a frame drawn by hand is a
  /// degree or two off square, and its panes inherit that, so a test that
  /// demands exact right angles rejects every real drawing. A shape that
  /// fills its own bounding box is one the two figures describe.
  static bool isRectangle(Polygon shape) {
    if (shape.corners.length != 4) return false;
    final box = shape.width * shape.height;
    if (box <= 0) return false;
    return shape.area >= box * 0.97;
  }

  /// Every figure on the drawing that can be typed over, nearest the
  /// pointer first when they overlap.
  /// [canvas], where given, is the sheet the drawing is on, as the painter
  /// is given it — so a row the painter leaves off at this zoom offers
  /// nothing to tap.
  static List<DimensionHandle> of(
    Design design,
    ViewTransform view,
    CadLayers layers, {
    Size? canvas,
    Words words = const EnglishWords(),
  }) {
    final w = words;
    final frame = design.frame;
    if (frame == null || !layers.dimensions) return const [];

    final handles = <DimensionHandle>[];
    final sizes = Measurements.of(design);

    // Every chain's figures, exactly where the painter writes them: the
    // words themselves, with a little room round them to take a finger.
    for (final placed in DimensionLayout.of(
      design,
      view,
      canvas: canvas,
      words: w,
    ).figures) {
      final run = placed.run;
      final across = placed.chain.axis == DimensionAxis.horizontal;
      final overall = run.of == ChainRunOf.overall;
      if (run.sideKey case final key?) {
        handles.add(
          DimensionHandle(
            rect: placed.rect.inflate(3),
            of: DimensionOf.side,
            elementId: key,
            valueMm: run.valueMm,
            label:
                FrameSides.of(design)
                    .where((s) => s.key == key)
                    .firstOrNull
                    ?.labelIn(w) ??
                run.sideLabel ??
                w.dimSide,
            known: placed.known,
          ),
        );
        continue;
      }
      final what = DimensionLayout.noteIn(w, run);
      handles.add(DimensionHandle(
        rect: placed.rect.inflate(3),
        of: overall
            ? (across ? DimensionOf.overallWidth : DimensionOf.overallHeight)
            : (across ? DimensionOf.sectionWidth : DimensionOf.sectionHeight),
        elementId: overall ? null : run.sectionId,
        valueMm: run.valueMm,
        label: overall
            ? (across ? w.dimOverallWidth : w.dimOverallHeight)
            : (across ? w.dimKindWidth(what) : w.dimKindHeight(what)),
        known: placed.known,
      ));
    }

    // A section's own size, written in it: the width left of the cross and
    // the height right of it, so either can be typed over on its own.
    for (final section in design.sections) {
      final at = sectionSizeAt(design, view, section);
      if (at == null) continue;
      final half = sizeReach.width / 2;
      handles.add(DimensionHandle(
        rect: Rect.fromLTWH(
          at.dx - half,
          at.dy - sizeReach.height / 2,
          half,
          sizeReach.height,
        ),
        of: DimensionOf.sectionWidth,
        elementId: section.id,
        valueMm: section.widthMm,
        label: w.dimSectionWidth,
        known: Measurements.knowsSection(
          design,
          section.id,
          MeasureAxis.across,
          sizes,
        ),
      ));
      handles.add(DimensionHandle(
        rect: Rect.fromLTWH(
          at.dx,
          at.dy - sizeReach.height / 2,
          half,
          sizeReach.height,
        ),
        of: DimensionOf.sectionHeight,
        elementId: section.id,
        valueMm: section.heightMm,
        label: w.dimSectionHeight,
        known: Measurements.knowsSection(
          design,
          section.id,
          MeasureAxis.down,
          sizes,
        ),
      ));
    }

    for (final dimension in design.dimensions) {
      final at = drawnDimensionAt(view, dimension);
      if (at == null) continue;
      handles.add(DimensionHandle(
        rect: Rect.fromCenter(
          center: at,
          width: labelReach.width,
          height: labelReach.height,
        ),
        of: DimensionOf.drawn,
        elementId: dimension.id,
        valueMm: dimension.valueMm,
        label: w.dimRealSize,
        known: dimension.isStated || Measurements.complete(design),
      ));
    }

    return handles;
  }

  /// The figure at [point], if there is one. The smallest wins, so a
  /// section's own size is reachable where it overlaps a chain.
  static DimensionHandle? at(List<DimensionHandle> handles, Offset point) {
    DimensionHandle? best;
    for (final handle in handles) {
      if (!handle.rect.contains(point)) continue;
      if (best == null ||
          handle.rect.width * handle.rect.height <
              best.rect.width * best.rect.height) {
        best = handle;
      }
    }
    return best;
  }
}
