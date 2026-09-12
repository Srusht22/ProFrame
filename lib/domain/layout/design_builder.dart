import '../design_document.dart';
import '../geometry/point2.dart';
import '../geometry/polygon.dart';
import '../measurement.dart';
import '../panel.dart';
import '../panel_divider.dart';
import '../product/opening.dart';
import '../recognition/stroke_intent.dart';
import 'note_resolver.dart';
import 'panel_splitter.dart';

/// Supplies ids for panels and dividers. Injected so tests are deterministic.
typedef IdFactory = String Function(String prefix);

/// Applies a recognised [StrokeIntent] to a design.
///
/// The whole drawing-to-model step lives here, in pure Dart, so it can be
/// tested without a canvas (spec section 9). The canvas classifies a stroke and
/// hands the intent here; it never edits the document itself.
///
/// **Coordinates.** A drawing starts in provisional millimetres: whatever the
/// user drew is taken at face value so proportions are exact, and every
/// dimension derived from it is an *estimate* until a real measurement arrives
/// (spec section 2). Confirming the overall width or height rescales the whole
/// design about its top-left corner, which keeps the proportions the user drew
/// while making the numbers real.
abstract final class DesignBuilder {
  /// Returns the design with [intent] applied, or the design unchanged when
  /// the intent was discarded or cannot be applied.
  static DesignDocument apply(
    DesignDocument design,
    StrokeIntent intent,
    IdFactory nextId,
  ) =>
      switch (intent) {
        DiscardedIntent() => design,
        FrameIntent(:final outline) => _setFrame(design, outline, nextId),
        VerticalDividerIntent(:final atX, :final panelId) =>
          _divide(design, panelId, at: atX, vertical: true, ids: nextId),
        HorizontalDividerIntent(:final atY, :final panelId) =>
          _divide(design, panelId, at: atY, vertical: false, ids: nextId),
        ChevronIntent(:final panelId, :final hingeSide) =>
          _markOpening(design, panelId, hingeSide),
      };

  /// The frame, plus the single panel it starts as.
  ///
  /// One panel, not zero: a frame with nothing drawn in it is one pane of
  /// glass, and the user can immediately mark it CH or Z.
  static DesignDocument _setFrame(
    DesignDocument design,
    Polygon outline,
    IdFactory nextId,
  ) =>
      design.copyWith(
        outline: outline,
        panels: [Panel.fixed(id: nextId('panel'), boundary: outline)],
        dividers: const [],
        // Proportions, not dimensions. These read as unconfirmed everywhere
        // they are shown until the user enters real numbers.
        overallWidth: Measurement.estimated(outline.width),
        overallHeight: Measurement.estimated(outline.height),
      );

  static DesignDocument _divide(
    DesignDocument design,
    String panelId, {
    required double at,
    required bool vertical,
    required IdFactory ids,
  }) {
    final panel = design.panelById(panelId);
    if (panel == null) return design;

    final List<Panel> halves;
    try {
      if (vertical) {
        final (left, right) = PanelSplitter.splitVertical(
          panel,
          at,
          leftId: ids('panel'),
          rightId: ids('panel'),
        );
        halves = [left, right];
      } else {
        final (top, bottom) = PanelSplitter.splitHorizontal(
          panel,
          at,
          topId: ids('panel'),
          bottomId: ids('panel'),
        );
        halves = [top, bottom];
      }
    } on ArgumentError {
      // The classifier already refuses a divider with no room, so this is the
      // belt to that braces. Leaving the design untouched is right either way.
      return design;
    }

    // Notes go where they were written, and the move is recorded rather than
    // being silent (spec section 8B).
    final resolved = NoteResolver.afterSplit(panel, halves);

    final box = panel.boundary;
    final divider = PanelDivider(
      id: ids('divider'),
      start: vertical ? Point2(at, box.top) : Point2(box.left, at),
      end: vertical ? Point2(at, box.bottom) : Point2(box.right, at),
      // Full only when it crosses the whole frame; a divider inside one panel
      // of several is a partial one, and stays that way (spec section 4).
      spansFullFrame: vertical
          ? _spansFully(design, box.top, box.bottom, vertical: true)
          : _spansFully(design, box.left, box.right, vertical: false),
    );

    return design.copyWith(
      panels: [
        for (final existing in design.panels)
          if (existing.id == panelId) ...resolved.panels else existing,
      ],
      dividers: [...design.dividers, divider],
    );
  }

  static bool _spansFully(
    DesignDocument design,
    double low,
    double high, {
    required bool vertical,
  }) {
    final outline = design.outline;
    if (outline == null) return false;
    final frameLow = vertical ? outline.top : outline.left;
    final frameHigh = vertical ? outline.bottom : outline.right;
    return (low - frameLow).abs() < 1 && (high - frameHigh).abs() < 1;
  }

  /// A chevron makes a panel open, hinged on the side it points to.
  ///
  /// The direction is *not* confirmed by the mark: a chevron says which edge
  /// the hinges are on, not whether the leaf swings in or out, so the panel is
  /// left asking that question rather than having it answered for the user
  /// (spec section 3C).
  static DesignDocument _markOpening(
    DesignDocument design,
    String panelId,
    HingeSide hingeSide,
  ) {
    final panel = design.panelById(panelId);
    if (panel == null) return design;

    return design.withPanel(
      panel.asOpening(
        OpeningSpec(
          hingeSide: hingeSide,
          direction: panel.opening?.direction ?? OpeningDirection.inward,
          isConfirmed: false,
        ),
      ),
    );
  }

  /// Rescales the whole design so the frame becomes [widthMm] wide, keeping
  /// every proportion the user drew.
  ///
  /// This is how a sketch becomes real dimensions. Panels and dividers scale
  /// with the frame, so a divider drawn a third of the way across stays a
  /// third of the way across (spec Phase 2, item 3).
  static DesignDocument setOverallWidth(DesignDocument design, double widthMm) {
    final outline = design.outline;
    if (outline == null || outline.width <= 0) {
      return design.copyWith(overallWidth: Measurement.confirmed(widthMm));
    }
    return _scaled(design, widthMm / outline.width, 1)
        .copyWith(overallWidth: Measurement.confirmed(widthMm));
  }

  /// Rescales the design so the frame becomes [heightMm] tall.
  static DesignDocument setOverallHeight(DesignDocument design, double heightMm) {
    final outline = design.outline;
    if (outline == null || outline.height <= 0) {
      return design.copyWith(overallHeight: Measurement.confirmed(heightMm));
    }
    return _scaled(design, 1, heightMm / outline.height)
        .copyWith(overallHeight: Measurement.confirmed(heightMm));
  }

  /// Scales outline, panels and dividers about the outline's top-left corner.
  static DesignDocument _scaled(
    DesignDocument design,
    double scaleX,
    double scaleY,
  ) {
    final outline = design.outline;
    if (outline == null) return design;
    final originX = outline.left;
    final originY = outline.top;

    Point2 scalePoint(Point2 p) => Point2(
          originX + (p.x - originX) * scaleX,
          originY + (p.y - originY) * scaleY,
        );

    Polygon scalePolygon(Polygon polygon) =>
        Polygon([for (final v in polygon.vertices) scalePoint(v)]);

    return design.copyWith(
      outline: scalePolygon(outline),
      panels: [
        for (final panel in design.panels)
          panel.copyWith(boundary: scalePolygon(panel.boundary)),
      ],
      dividers: [
        for (final divider in design.dividers)
          divider.copyWith(
            start: scalePoint(divider.start),
            end: scalePoint(divider.end),
          ),
      ],
    );
  }
}
