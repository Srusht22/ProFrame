import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/geometry/polygon.dart';
import '../../domain/model/design.dart';
import '../../domain/text/words.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import 'cad_layers.dart';
import 'cad_painter.dart';
import 'cad_style.dart';
import 'view_transform.dart';

/// A small picture of a saved design, for finding it again among many.
///
/// **It is the design, drawn.** A design that has been read is drawn by the
/// same `CadPainter` as the technical drawing — the frame, the bars, the
/// panes and the openings exactly as they are in the document — with the
/// figures, the grid and the handles left off, because at this size they
/// are noise. A design not read yet is its own sketch, the user's strokes
/// as they drew them. Nothing here is ever a picture of a door or a window
/// in general: a design with nothing drawn in it says so, with
/// [PreviewPlaceholder], and no geometry is made up to fill the space.
class DesignPreview extends StatelessWidget {
  final Design design;

  const DesignPreview({super.key, required this.design});

  /// True when the design has anything to draw: a frame read from its
  /// sheet, or at least one stroke that goes somewhere. A tap that left a
  /// dot, or a stroke with no length, draws nothing, so it does not count.
  static bool shows(Design design) =>
      design.frame != null ||
      design.sketch.strokes.any(
        (stroke) => !stroke.isEmpty && stroke.pathLength > 0,
      );

  @override
  Widget build(BuildContext context) {
    if (!shows(design)) {
      return const PreviewPlaceholder.nothingDrawn();
    }
    return Semantics(
      image: true,
      label: context.l10n.drawingOf(design.shownNameIn(context.words)),
      child: CustomPaint(
        painter: DesignPreviewPainter(
          design,
          palette: context.palette,
          words: context.words,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Where there is no drawing of a design to show: the empty sheet, a mark
/// that says why, and the reason in words — never a picture standing in
/// for the design, and never any geometry of its own.
///
/// [nothingDrawn] is a design kept with nothing drawn in it yet;
/// [unavailable] is one that could not be read, which must not look like
/// an empty design.
class PreviewPlaceholder extends StatelessWidget {
  final IconData icon;

  /// What it says, in English; shown in the language in scope.
  final String label;

  const PreviewPlaceholder.nothingDrawn({super.key})
    : icon = Icons.edit_outlined,
      label = nothingDrawnLabel;

  const PreviewPlaceholder.unavailable({super.key})
    : icon = Icons.visibility_off_outlined,
      label = unavailableLabel;

  String _said(AppLocalizations l) =>
      label == nothingDrawnLabel ? l.nothingDrawnYet : l.previewUnavailable;

  static const nothingDrawnLabel = 'Nothing drawn yet';
  static const unavailableLabel = 'Preview unavailable';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ColoredBox(
      color: p.cad.sheet,
      child: LayoutBuilder(
        builder: (context, room) {
          // The mark only where there is room for it beside the words.
          final withMark = room.maxHeight >= 88 && room.maxWidth >= 80;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (withMark) ...[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: p.primary.withValues(alpha: 0.07),
                      ),
                      child: Icon(icon, size: 18, color: p.muted),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    _said(context.l10n),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: p.muted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Paints [design] fitted to the space it is given.
class DesignPreviewPainter extends CustomPainter {
  final Design design;

  /// The colours of the appearance in effect.
  final Palette palette;

  /// The language its words — IN, OUT — are written in.
  final Words words;

  const DesignPreviewPainter(
    this.design, {
    this.palette = Palette.light,
    this.words = const EnglishWords(),
  });

  /// The drawing's layers for a preview: the design itself, and nothing
  /// that is there to work on it with.
  static const layers = CadLayers(
    grid: false,
    dimensions: false,
    annotations: false,
    grips: false,
    snap: false,
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Cad.fill(palette.cad.sheet));
    if (design.frame != null) {
      final view = ViewTransform.fit(design.bounds, size, marginFraction: 0.12);
      CadPainter(
        design: design,
        view: view,
        layers: layers,
        ink: palette.cad,
        words: words,
      ).paint(canvas, size);
      return;
    }
    _sketch(canvas, size);
  }

  /// The strokes the user drew, where nothing has been read from them yet.
  void _sketch(Canvas canvas, Size size) {
    final strokes = [
      for (final stroke in design.sketch.strokes)
        if (!stroke.isEmpty && stroke.pathLength > 0) stroke,
    ];
    if (strokes.isEmpty) return;
    var left = double.infinity;
    var top = double.infinity;
    var right = -double.infinity;
    var bottom = -double.infinity;
    for (final stroke in strokes) {
      for (final point in stroke.points) {
        left = math.min(left, point.x);
        top = math.min(top, point.y);
        right = math.max(right, point.x);
        bottom = math.max(bottom, point.y);
      }
    }
    final view = ViewTransform.fit(
      Polygon.rect(left, top, right, bottom),
      size,
      marginFraction: 0.12,
    );
    final ink = Cad.stroke(palette.drawnInk, 1.3, round: true);
    for (final stroke in strokes) {
      final path = Path();
      final first = view.toScreen(stroke.start);
      path.moveTo(first.dx, first.dy);
      for (final point in stroke.points.skip(1)) {
        final at = view.toScreen(point);
        path.lineTo(at.dx, at.dy);
      }
      canvas.drawPath(path, ink);
    }
  }

  @override
  bool shouldRepaint(DesignPreviewPainter old) =>
      old.design.id != design.id ||
      old.design.updatedAt != design.updatedAt ||
      old.palette != palette ||
      old.words != words;
}
