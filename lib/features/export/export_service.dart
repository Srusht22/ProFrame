import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../shared/models/design_document.dart';
import '../../shared/models/materials.dart';
import '../../shared/models/opening_model.dart';
import '../pricing/pricing_engine.dart';
import '../rendering/painters/technical_drawing_painter.dart';
import 'file_saver.dart';

/// Exports the design as an image, a PDF sheet or a project file (§48).
class ExportService {
  const ExportService();

  /// Renders the technical drawing straight from the painter — no widget tree,
  /// no screenshot, so the export is crisp at any size.
  Future<Uint8List> renderDrawingPng(
    OpeningModel model, {
    double width = 1600,
    double height = 1200,
    double pixelRatio = 1,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    TechnicalDrawingPainter(model: model).paint(canvas, Size(width, height));
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (width * pixelRatio).round(),
      (height * pixelRatio).round(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();
    if (data == null) throw const ExportException('The drawing could not be rendered.');
    return data.buffer.asUint8List();
  }

  Future<Uint8List> buildPdf(
    DesignDocument design, {
    PriceBreakdown? price,
  }) async {
    final model = design.model;
    final solved = OpeningSolver.solve(model);
    final drawing = await renderDrawingPng(model, width: 1400, height: 1000, pixelRatio: 2);
    final image = pw.MemoryImage(drawing);
    final document = pw.Document(title: design.name);

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      design.name,
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      '${model.kind.label} · ${model.widthMm.round()} × '
                      '${model.heightMm.round()} mm',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
                pw.Text(
                  AppConstants.appName,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF013E37),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Expanded(
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
                      ),
                      child: pw.Image(image, fit: pw.BoxFit.contain),
                    ),
                  ),
                  pw.SizedBox(width: 14),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _pdfSection('Specification'),
                        _pdfTable([
                          ['Type', model.kind.label],
                          ['Overall size', '${model.widthMm.round()} × ${model.heightMm.round()} mm'],
                          ['Area', '${model.areaM2.toStringAsFixed(2)} m²'],
                          ['Frame', '${model.material.label} · ${model.finish.label}'],
                          ['Frame depth', '${model.material.frameDepthMm.round()} mm'],
                          ['Sections', '${solved.leaves.length}'],
                          ['Opening leaves', '${model.operableCellCount}'],
                          ['Glass area', '${solved.totalGlassAreaM2.toStringAsFixed(2)} m²'],
                        ]),
                        pw.SizedBox(height: 10),
                        _pdfSection('Sections'),
                        _pdfTable([
                          for (final cell in solved.leaves)
                            [
                              'R${cell.rowIndex + 1}.C${cell.columnIndex + 1}',
                              '${cell.aperture.width.round()} × ${cell.aperture.height.round()} mm'
                                  ' · ${cell.spec.operation.label}',
                            ],
                        ]),
                        if (price != null) ...[
                          pw.SizedBox(height: 10),
                          _pdfSection('Estimate'),
                          _pdfTable([
                            ['Materials', '${price.currencySymbol}${price.materialsTotal.toStringAsFixed(2)}'],
                            ['Hardware', '${price.currencySymbol}${price.hardwareTotal.toStringAsFixed(2)}'],
                            ['Labour', '${price.currencySymbol}${price.labourTotal.toStringAsFixed(2)}'],
                            ['Total', '${price.currencySymbol}${price.total.toStringAsFixed(2)}'],
                          ]),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Generated from the drawing on '
              '${design.updatedAt.toIso8601String().split('T').first}. '
              'Dimensions in millimetres.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
    );

    return document.save();
  }

  static pw.Widget _pdfSection(String title) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromInt(0xFF013E37),
          ),
        ),
      );

  static pw.Widget _pdfTable(List<List<String>> rows) => pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
        columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(3)},
        children: rows
            .map((row) => pw.TableRow(
                  children: row
                      .map((cell) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                            child: pw.Text(cell, style: const pw.TextStyle(fontSize: 8.5)),
                          ))
                      .toList(),
                ))
            .toList(),
      );

  Future<void> exportPng(DesignDocument design) async {
    final bytes = await renderDrawingPng(design.model);
    await saveAndShareBytes(
      bytes: bytes,
      fileName: '${_slug(design.name)}.png',
      mimeType: 'image/png',
      subject: design.name,
    );
  }

  Future<void> exportPdf(DesignDocument design, {PriceBreakdown? price}) async {
    final bytes = await buildPdf(design, price: price);
    await Printing.sharePdf(bytes: bytes, filename: '${_slug(design.name)}.pdf');
  }

  /// The whole design — ink, model, scale and history — in one file that can
  /// be opened again later or sent to a colleague.
  Future<void> exportProjectFile(DesignDocument design) async {
    final json = const JsonEncoder.withIndent('  ').convert(design.toJson());
    await saveAndShareBytes(
      bytes: Uint8List.fromList(utf8.encode(json)),
      fileName: '${_slug(design.name)}.${AppConstants.projectFileExtension}',
      mimeType: 'application/json',
      subject: design.name,
    );
  }

  static DesignDocument importProjectFile(String json) {
    try {
      return DesignDocument.fromJson(Map<String, dynamic>.from(jsonDecode(json) as Map));
    } catch (error) {
      throw ExportException('That file is not a ProFrame design.', cause: error);
    }
  }

  static String _slug(String name) {
    final cleaned = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final trimmed = cleaned.replaceAll(RegExp(r'^-+|-+$'), '');
    return trimmed.isEmpty ? 'design' : trimmed;
  }
}
