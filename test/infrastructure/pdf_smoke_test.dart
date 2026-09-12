import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/design_document.dart';
import 'package:proframe/domain/geometry/point2.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/measurement.dart';
import 'package:proframe/domain/panel.dart';
import 'package:proframe/domain/panel_divider.dart';
import 'package:proframe/domain/panel_note.dart';
import 'package:proframe/domain/product/finish.dart';
import 'package:proframe/domain/product/opening.dart';
import 'package:proframe/domain/product/product_basics.dart';
import 'package:proframe/infrastructure/export/pdf_design_sheet.dart';

void main() {
  // The PDF embeds fonts from the asset bundle, which needs the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generates a real PDF', () async {
    final outline = Polygon.rectangle(width: 1200, height: 1500);
    final design = DesignDocument.blank(
      id: 'p1',
      category: ProductCategory.window,
      material: FrameMaterial.pvc,
      name: 'Kitchen window',
      now: DateTime.utc(2026, 9, 12),
    ).copyWith(
      outline: outline,
      finish: StockFinishes.anthracite,
      overallWidth: const Measurement.confirmed(1200),
      overallHeight: const Measurement.confirmed(1500),
      designNote: 'Customer wants obscure glass in the opening half.',
      dividers: const [
        PanelDivider(
          id: 'v1',
          start: Point2(500, 0),
          end: Point2(500, 1500),
          spansFullFrame: true,
        ),
      ],
      panels: [
        Panel.fixed(
          id: 'left',
          boundary: Polygon.rectangle(width: 500, height: 1500),
          notes: const [PanelNote(id: 'n1', text: 'توري')],
        ).copyWith(hasMesh: true),
        Panel.opening(
          id: 'right',
          boundary: Polygon.rectangle(
            width: 700,
            height: 1500,
            topLeft: const Point2(500, 0),
          ),
          opening: const OpeningSpec(
            hingeSide: HingeSide.right,
            direction: OpeningDirection.outward,
            isConfirmed: true,
          ),
          notes: const [PanelNote(id: 'n2', text: 'Frosted glass')],
        ),
      ],
    );

    final bytes = await PdfDesignSheet.build(design);

    expect(bytes.length, greaterThan(1000));
    // A real PDF starts with %PDF.
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');

    await File('/tmp/sample_design_sheet.pdf').writeAsBytes(bytes);
    // ignore: avoid_print
    print('WROTE ${bytes.length} bytes');
  });
}
