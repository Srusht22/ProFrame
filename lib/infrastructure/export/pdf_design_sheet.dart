import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/design_document.dart';
import '../../domain/product/opening.dart';
import '../../domain/rendering/front_elevation.dart';
import 'export_fonts.dart';

/// Builds the PDF design sheet (spec section 11C).
///
/// Everything on the page comes from the design document. Nothing is invented:
/// if a dimension was never entered it says so, and if the profile is a
/// generic preview the sheet says that too, in a box the reader cannot miss.
///
/// The drawing is **fitted to the page, not printed to scale**, and is labelled
/// that way — claiming a scale that is not implemented would be exactly the
/// false claim the spec warns about (section 11C).
abstract final class PdfDesignSheet {
  /// Brand colours, matched to the app.
  static const PdfColor _deepGreen = PdfColor.fromInt(0xFF013E37);
  static const PdfColor _cream = PdfColor.fromInt(0xFFFFEFB3);
  static const PdfColor _ink = PdfColor.fromInt(0xFF1C1F1D);
  static const PdfColor _muted = PdfColor.fromInt(0xFF5A5F5B);
  static const PdfColor _rule = PdfColor.fromInt(0xFFD6D2C4);
  static const PdfColor _glass = PdfColor.fromInt(0xFFDCE9EB);
  static const PdfColor _caution = PdfColor.fromInt(0xFF6B4E00);
  static const PdfColor _cautionBox = PdfColor.fromInt(0xFFFDF3D6);

  static String fileNameFor(DesignDocument design) {
    final safe = design.name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
    return '${safe.isEmpty ? 'design' : safe}.pdf';
  }

  /// Renders the sheet.
  static Future<Uint8List> build(DesignDocument design) async {
    // Embedded Unicode fonts, so an Arabic or Kurdish note is readable rather
    // than a row of boxes (spec section 8B).
    await ExportFonts.load();

    final facts = DesignFacts.of(design);
    final elevation = FrontElevation.of(design);
    final document = pw.Document(
      title: design.name,
      theme: ExportFonts.theme,
    );

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _header(facts),
            pw.SizedBox(height: 12),
            if (!facts.sizeConfirmed || facts.outstanding.isNotEmpty)
              _warning(
                'Preview — measurements incomplete',
                [
                  ...facts.outstanding,
                  'Do not manufacture from this sheet.',
                ],
              ),
            pw.SizedBox(height: 8),
            pw.Expanded(
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(flex: 3, child: _drawingBlock(elevation)),
                  pw.SizedBox(width: 16),
                  pw.Expanded(flex: 2, child: _detailsBlock(facts, elevation)),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            if (facts.profileIsGeneric)
              _warning('Generic preview profile', [facts.profileAssumptions]),
            pw.SizedBox(height: 6),
            _footer(facts),
          ],
        ),
      ),
    );

    return document.save();
  }

  // -- blocks ---------------------------------------------------------------

  static pw.Widget _header(DesignFacts facts) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        color: _deepGreen,
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    facts.projectName,
                    style: pw.TextStyle(
                      color: _cream,
                      fontSize: 17,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '${facts.category} · ${facts.material} · ${facts.finish}',
                    style: const pw.TextStyle(color: _cream, fontSize: 10),
                  ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  facts.size,
                  style: pw.TextStyle(
                    color: _cream,
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  facts.sizeConfirmed ? 'Confirmed' : 'Not confirmed',
                  style: const pw.TextStyle(color: _cream, fontSize: 9),
                ),
              ],
            ),
          ],
        ),
      );

  static pw.Widget _drawingBlock(FrontElevation elevation) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('Front view'),
          pw.Expanded(
            child: pw.Container(
              width: double.infinity,
              decoration: pw.BoxDecoration(border: pw.Border.all(color: _rule)),
              padding: const pw.EdgeInsets.all(10),
              child: elevation.isEmpty
                  ? pw.Center(
                      child: pw.Text(
                        'Nothing has been drawn yet.',
                        style: const pw.TextStyle(color: _muted, fontSize: 10),
                      ),
                    )
                  : pw.CustomPaint(
                      painter: (canvas, size) =>
                          _paintElevation(canvas, size, elevation),
                    ),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Not to scale — fitted to the page.',
            style: const pw.TextStyle(color: _muted, fontSize: 8),
          ),
        ],
      );

  static pw.Widget _detailsBlock(
    DesignFacts facts,
    FrontElevation elevation,
  ) {
    final notes = elevation.numberedNotes;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Specification'),
        _row('Product', facts.category),
        _row('Material', facts.material),
        _row('Colour', facts.finish),
        _row('Profile', facts.profile +
            (facts.profileIsGeneric ? ' (generic preview)' : '')),
        _row('Overall size', facts.size),
        _row('Measured as', facts.dimensionReference),
        _row('Drawing viewed from', facts.viewedFrom),
        pw.SizedBox(height: 3),
        pw.Text(
          facts.dimensionReferenceDetail,
          style: const pw.TextStyle(color: _muted, fontSize: 7.5),
        ),

        pw.SizedBox(height: 10),
        _sectionTitle('Legend'),
        _legendRow('CH', 'Fixed — does not open', facts.fixedCount),
        _legendRow('Z', 'Opening sash or door leaf', facts.openingCount),

        if (elevation.panels.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          _sectionTitle('Panels'),
          for (final panel in elevation.panels)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Text(
                '${panel.number}. ${panel.code} · '
                '${panel.rect.width.round()} × ${panel.rect.height.round()} mm'
                '${panel.badges.isEmpty ? '' : ' · ${panel.badges.join(', ')}'}'
                '${panel.opening == null ? '' : ' · ${panel.opening!.mechanism.label}'
                    '${panel.opening!.mechanism.needsHingeSide ? ', ${panel.opening!.hingeSide.label.toLowerCase()}' : ''}'}',
                style: const pw.TextStyle(fontSize: 8, color: _ink),
              ),
            ),
        ],

        if (facts.designNote.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          _sectionTitle('Design notes'),
          pw.Text(
            facts.designNote,
            style: const pw.TextStyle(fontSize: 8.5, color: _ink),
          ),
        ],

        if (notes.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          _sectionTitle('Section notes'),
          for (final note in notes)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: '${note.reference}  ',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: _deepGreen,
                      ),
                    ),
                    pw.TextSpan(
                      text: note.text,
                      style: const pw.TextStyle(fontSize: 8, color: _ink),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  static pw.Widget _footer(DesignFacts facts) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.only(top: 5),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: _rule)),
        ),
        child: pw.Text(
          'Visual design sheet. Not manufacturing data: fabrication requires '
          'validated profile data, fabrication rules and factory review. '
          'Generated ${DateTime.now().toUtc().toIso8601String().substring(0, 16)} UTC.',
          style: const pw.TextStyle(color: _muted, fontSize: 7.5),
        ),
      );

  // -- pieces ---------------------------------------------------------------

  static pw.Widget _sectionTitle(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text(
          text.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 8,
            letterSpacing: 0.8,
            fontWeight: pw.FontWeight.bold,
            color: _deepGreen,
          ),
        ),
      );

  static pw.Widget _row(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 84,
              child: pw.Text(
                label,
                style: const pw.TextStyle(fontSize: 8, color: _muted),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 8,
                  color: _ink,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );

  static pw.Widget _legendRow(String code, String meaning, int count) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Row(
          children: [
            pw.Container(
              width: 22,
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.symmetric(vertical: 1),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: _ink)),
              child: pw.Text(
                code,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
            ),
            pw.SizedBox(width: 6),
            pw.Expanded(
              child: pw.Text(
                meaning,
                style: const pw.TextStyle(fontSize: 8, color: _ink),
              ),
            ),
            pw.Text(
              '$count',
              style: const pw.TextStyle(fontSize: 8, color: _muted),
            ),
          ],
        ),
      );

  static pw.Widget _warning(String title, List<String> lines) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(7),
        decoration: pw.BoxDecoration(
          color: _cautionBox,
          border: pw.Border.all(color: _caution, width: 0.7),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _caution,
              ),
            ),
            for (final line in lines)
              pw.Text(
                line,
                style: const pw.TextStyle(fontSize: 7.5, color: _caution),
              ),
          ],
        ),
      );

  // -- the drawing ----------------------------------------------------------

  /// Draws the elevation into [size], fitted with room for the dimension
  /// lines. The geometry comes from [FrontElevation], the same source the
  /// on-screen export preview uses, so the two cannot disagree.
  static void _paintElevation(
    PdfGraphics canvas,
    PdfPoint size,
    FrontElevation elevation,
  ) {
    final outline = elevation.outline;
    if (outline.width <= 0 || outline.height <= 0) return;

    // Room outside the frame for two tiers of dimensions below and one beside.
    const leftGutter = 40.0;
    const bottomGutter = 34.0;
    final usableWidth = size.x - leftGutter - 6;
    final usableHeight = size.y - bottomGutter - 6;
    final scale = [
      usableWidth / outline.width,
      usableHeight / outline.height,
    ].reduce((a, b) => a < b ? a : b);

    final drawnWidth = outline.width * scale;
    final drawnHeight = outline.height * scale;
    final originX = leftGutter + (usableWidth - drawnWidth) / 2;
    // PDF's y axis runs up the page; the model's runs down.
    final originY = size.y - 6 - (usableHeight - drawnHeight) / 2;

    double px(double mm) => originX + (mm - outline.left) * scale;
    double py(double mm) => originY - (mm - outline.top) * scale;

    // Built once: each of these resolves a font object, and the loops below
    // would otherwise repeat the work for every string drawn. The embedded
    // faces are used here too, so a label on the drawing renders the same
    // characters as the text beside it.
    final fontContext = pw.Context(document: PdfDocument());
    final regular = ExportFonts.regular.getFont(fontContext);
    final bold = ExportFonts.bold.getFont(fontContext);

    // Glass behind everything.
    for (final panel in elevation.panels) {
      if (panel.isEmpty) continue;
      canvas
        ..setFillColor(_glass)
        ..drawRect(
          px(panel.rect.left),
          py(panel.rect.bottom),
          (panel.rect.width) * scale,
          (panel.rect.height) * scale,
        )
        ..fillPath();
    }

    // The outline, as drawn — which is not a rectangle when the top slopes.
    canvas
      ..setStrokeColor(_ink)
      ..setLineWidth(1.4);
    final corners = elevation.outlineCorners;
    for (var i = 0; i < corners.length; i++) {
      final from = corners[i];
      final to = corners[(i + 1) % corners.length];
      canvas.drawLine(px(from.$1), py(from.$2), px(to.$1), py(to.$2));
    }
    canvas.strokePath();

    // Dividers.
    canvas
      ..setFillColor(_ink)
      ..setLineWidth(1);
    for (final divider in elevation.dividers) {
      canvas
        ..drawRect(
          px(divider.rect.left),
          py(divider.rect.bottom),
          divider.rect.width * scale,
          divider.rect.height * scale,
        )
        ..fillPath();
    }

    // Panel marks: the CH/Z code, the opening symbol, the note references.
    for (final panel in elevation.panels) {
      final opening = panel.opening;
      if (opening != null) {
        _paintOpeningGlyph(canvas, panel, opening, px, py);
      }

      canvas.setFillColor(_ink);
      canvas.drawString(
        bold,
        9,
        panel.code,
        px(panel.rect.centreX) - 6,
        py(panel.rect.centreY) - 3,
      );

      // Note references, so the legend below matches the drawing.
      for (var i = 0; i < panel.notes.length; i++) {
        canvas.drawString(
          regular,
          7,
          '${panel.number}.${i + 1}',
          px(panel.rect.right) - 20,
          py(panel.rect.top) - 10 - i * 9,
        );
      }
    }

    // Dimensions.
    canvas
      ..setStrokeColor(_muted)
      ..setLineWidth(0.5);
    for (final dimension in elevation.dimensions) {
      final label = dimension.confirmed
          ? '${dimension.valueMm.round()}'
          : '(${dimension.valueMm.round()})';
      if (dimension.horizontal) {
        final y = py(outline.bottom) - 12.0 * dimension.tier;
        canvas
          ..drawLine(px(dimension.fromMm), y, px(dimension.toMm), y)
          ..strokePath();
        canvas
          ..setFillColor(_muted)
          ..drawString(
            regular,
            7,
            label,
            (px(dimension.fromMm) + px(dimension.toMm)) / 2 - 10,
            y + 2,
          );
      } else {
        final x = px(outline.left) - 16;
        canvas
          ..drawLine(x, py(dimension.fromMm), x, py(dimension.toMm))
          ..strokePath();
        canvas
          ..setFillColor(_muted)
          ..drawString(
            regular,
            7,
            label,
            x - 22,
            (py(dimension.fromMm) + py(dimension.toMm)) / 2,
          );
      }
    }
  }

  /// The standard dashed opening symbol, converging on the hinge edge.
  static void _paintOpeningGlyph(
    PdfGraphics canvas,
    ElevationPanel panel,
    OpeningSpec opening,
    double Function(double) px,
    double Function(double) py,
  ) {
    final rect = panel.rect;
    const inset = 6.0;
    canvas
      ..setStrokeColor(_deepGreen)
      ..setLineWidth(0.8)
      ..setLineDashPattern(const [3, 2]);

    final left = px(rect.left) + inset;
    final right = px(rect.right) - inset;
    final top = py(rect.top) - inset;
    final bottom = py(rect.bottom) + inset;
    final midY = (top + bottom) / 2;
    final midX = (left + right) / 2;

    switch (opening.mechanism) {
      case OpeningMechanism.hinged:
        switch (opening.hingeSide) {
          case HingeSide.left:
            canvas
              ..drawLine(right, top, left, midY)
              ..drawLine(right, bottom, left, midY);
          case HingeSide.right:
            canvas
              ..drawLine(left, top, right, midY)
              ..drawLine(left, bottom, right, midY);
          case HingeSide.top:
            canvas
              ..drawLine(left, bottom, midX, top)
              ..drawLine(right, bottom, midX, top);
          case HingeSide.bottom:
            canvas
              ..drawLine(left, top, midX, bottom)
              ..drawLine(right, top, midX, bottom);
        }
      case OpeningMechanism.tilt:
        // Bottom-hung, so the apex is on the bottom edge.
        canvas
          ..drawLine(left, top, midX, bottom)
          ..drawLine(right, top, midX, bottom);
      case OpeningMechanism.slidingLeft:
      case OpeningMechanism.slidingRight:
        // An arrow along the middle, pointing the way it travels.
        canvas.drawLine(left, midY, right, midY);
        final towardsLeft = opening.mechanism == OpeningMechanism.slidingLeft;
        final tip = towardsLeft ? left : right;
        final barb = towardsLeft ? 8.0 : -8.0;
        canvas
          ..drawLine(tip, midY, tip + barb, midY + 5)
          ..drawLine(tip, midY, tip + barb, midY - 5);
    }

    canvas
      ..strokePath()
      ..setLineDashPattern();
  }
}
