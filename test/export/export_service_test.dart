import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/core/errors/app_exception.dart';
import 'package:proframe/features/export/export_service.dart';
import 'package:proframe/features/pricing/pricing_engine.dart';
import 'package:proframe/shared/models/design_document.dart';
import 'package:proframe/shared/models/opening_model.dart';

import '../support/sketch_builders.dart';

void main() {
  const service = ExportService();

  DesignDocument design() =>
      DesignDocument.blank(id: 'd1', kind: OpeningKind.window).copyWith(
        name: 'Balcony window',
        sketch: twoPanelWindowSketch(),
      );

  test('the drawing renders to a real PNG, not a screenshot', () async {
    final bytes = await service.renderDrawingPng(design().model, width: 600, height: 480);

    expect(bytes.length, greaterThan(1000));
    // PNG magic number.
    expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  test('the PDF sheet is produced with the specification and the estimate', () async {
    final price = const PricingEngine().price(design().model);
    final bytes = await service.buildPdf(design(), price: price);

    expect(bytes.length, greaterThan(2000));
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
  });

  test('a project file round-trips the whole design', () {
    final original = design();
    final restored =
        ExportService.importProjectFile(jsonEncode(original.toJson()));

    expect(restored.name, 'Balcony window');
    expect(restored.model.widthMm, original.model.widthMm);
    expect(restored.sketch.strokes.length, original.sketch.strokes.length);
  });

  test('a file that is not a design is rejected with a clear message', () {
    expect(
      () => ExportService.importProjectFile('{"hello":"world"}'),
      throwsA(isA<ExportException>().having(
        (e) => e.message,
        'message',
        contains('not a ProFrame design'),
      )),
    );
  });
}
