import '../design_document.dart';
import '../panel_note.dart';
import '../product/opening.dart';

/// A rectangle in elevation space, in millimetres.
class ElevationRect {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const ElevationRect(this.left, this.top, this.right, this.bottom);

  double get width => right - left;
  double get height => bottom - top;
  double get centreX => (left + right) / 2;
  double get centreY => (top + bottom) / 2;

  @override
  String toString() => 'ElevationRect($left, $top, $right, $bottom)';
}

/// One panel as it appears in the front view.
class ElevationPanel {
  final String panelId;

  /// 1-based, so a note can say "panel 2" and match the drawing.
  final int number;

  final ElevationRect rect;

  /// "CH" or "Z".
  final String code;

  /// How it opens, or null for a fixed panel.
  final OpeningSpec? opening;

  final bool hasMesh;
  final bool isEmpty;

  /// The notes on this panel, in the order they were added.
  final List<PanelNote> notes;

  const ElevationPanel({
    required this.panelId,
    required this.number,
    required this.rect,
    required this.code,
    required this.notes,
    this.opening,
    this.hasMesh = false,
    this.isEmpty = false,
  });

  /// Whether this panel carries a mark that is not its CH/Z code. The words
  /// for them are written where they are shown, in the user's language.
  bool get hasBadges => hasMesh || isEmpty;
}

/// One divider in the front view.
class ElevationDivider {
  final ElevationRect rect;
  final bool vertical;

  const ElevationDivider({required this.rect, required this.vertical});
}

/// A dimension to write on the drawing.
class ElevationDimension {
  final double fromMm;
  final double toMm;
  final double valueMm;

  /// False when the value is only scaled from the sketch.
  final bool confirmed;

  /// Where it goes: below the frame, or beside it.
  final bool horizontal;

  /// How far out from the frame, as a multiple of the standard offset. Lets
  /// panel widths sit inside the overall dimension.
  final int tier;

  const ElevationDimension({
    required this.fromMm,
    required this.toMm,
    required this.valueMm,
    required this.confirmed,
    required this.horizontal,
    this.tier = 1,
  });
}

/// The front view of a design, as plain numbers.
///
/// Pure domain data with no Flutter and no PDF in it, so the on-screen export
/// preview, the PNG and the PDF all draw the *same* drawing rather than three
/// that drift apart (spec section 11: exports must reflect the current design
/// state).
class FrontElevation {
  final ElevationRect outline;

  /// The outline's actual corners, which are not a rectangle when the design
  /// has a sloping top.
  final List<(double x, double y)> outlineCorners;

  final List<ElevationPanel> panels;
  final List<ElevationDivider> dividers;
  final List<ElevationDimension> dimensions;

  /// Frame face width, for drawing the profile as a double line.
  final double frameFaceMm;

  const FrontElevation({
    required this.outline,
    required this.outlineCorners,
    required this.panels,
    required this.dividers,
    required this.dimensions,
    required this.frameFaceMm,
  });

  static const FrontElevation empty = FrontElevation(
    outline: ElevationRect(0, 0, 0, 0),
    outlineCorners: [],
    panels: [],
    dividers: [],
    dimensions: [],
    frameFaceMm: 0,
  );

  bool get isEmpty => panels.isEmpty && outlineCorners.isEmpty;

  /// Every note in the design that belongs to a panel, numbered for the export
  /// legend: "1.1" is the first note on panel 1.
  List<({String reference, String panelCode, String text})> get numberedNotes => [
        for (final panel in panels)
          for (var i = 0; i < panel.notes.length; i++)
            if (!panel.notes[i].isEmpty)
              (
                reference: '${panel.number}.${i + 1}',
                panelCode: panel.code,
                text: panel.notes[i].text.trim(),
              ),
      ];

  /// Builds the front view of [design].
  static FrontElevation of(DesignDocument design) {
    final polygon = design.outline;
    if (polygon == null) return empty;

    final rect = ElevationRect(
      polygon.left,
      polygon.top,
      polygon.right,
      polygon.bottom,
    );
    final profile = design.profileSystem;
    final half = profile.dividerFaceMm / 2;

    final panels = <ElevationPanel>[];
    for (var i = 0; i < design.panels.length; i++) {
      final panel = design.panels[i];
      panels.add(
        ElevationPanel(
          panelId: panel.id,
          number: i + 1,
          rect: ElevationRect(
            panel.boundary.left,
            panel.boundary.top,
            panel.boundary.right,
            panel.boundary.bottom,
          ),
          code: panel.behaviour.code,
          opening: panel.opening,
          hasMesh: panel.hasMesh,
          isEmpty: panel.isEmpty,
          notes: panel.notes.where((n) => !n.isEmpty).toList(),
        ),
      );
    }

    final dividers = [
      for (final divider in design.dividers)
        ElevationDivider(
          vertical: divider.isVertical,
          rect: divider.isVertical
              ? ElevationRect(
                  divider.start.x - half,
                  divider.start.y < divider.end.y
                      ? divider.start.y
                      : divider.end.y,
                  divider.start.x + half,
                  divider.start.y < divider.end.y
                      ? divider.end.y
                      : divider.start.y,
                )
              : ElevationRect(
                  divider.start.x < divider.end.x
                      ? divider.start.x
                      : divider.end.x,
                  divider.start.y - half,
                  divider.start.x < divider.end.x
                      ? divider.end.x
                      : divider.start.x,
                  divider.start.y + half,
                ),
        ),
    ];

    // Panel widths on the inner tier, the overall size outside them, so the
    // drawing reads the way the paper sketches do.
    final widthConfirmed = design.overallWidth?.isConfirmed ?? false;
    final bottomRow = design.panels
        .where((p) => (p.boundary.bottom - polygon.bottom).abs() < 1)
        .toList()
      ..sort((a, b) => a.boundary.left.compareTo(b.boundary.left));

    final dimensions = <ElevationDimension>[
      if (bottomRow.length > 1)
        for (final panel in bottomRow)
          ElevationDimension(
            fromMm: panel.boundary.left,
            toMm: panel.boundary.right,
            valueMm: panel.boundary.width,
            confirmed: widthConfirmed,
            horizontal: true,
          ),
      ElevationDimension(
        fromMm: rect.left,
        toMm: rect.right,
        valueMm: rect.width,
        confirmed: widthConfirmed,
        horizontal: true,
        tier: 2,
      ),
      ElevationDimension(
        fromMm: rect.top,
        toMm: rect.bottom,
        valueMm: rect.height,
        confirmed: design.overallHeight?.isConfirmed ?? false,
        horizontal: false,
      ),
    ];

    return FrontElevation(
      outline: rect,
      outlineCorners: [for (final v in polygon.vertices) (v.x, v.y)],
      panels: panels,
      dividers: dividers,
      dimensions: dimensions,
      frameFaceMm: profile.frameFaceMm,
    );
  }
}

