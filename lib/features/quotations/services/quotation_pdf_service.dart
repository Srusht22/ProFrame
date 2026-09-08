import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../domain/entities/customer.dart';
import '../../../domain/entities/project.dart';
import '../../../domain/entities/quotation.dart';

const _pdfDarkGreen = PdfColor.fromInt(0xFF013E37);
const _pdfCream = PdfColor.fromInt(0xFFFFEFB3);
const _pdfCreamDeep = PdfColor.fromInt(0xFFF5DD86);
const _pdfCreamSoft = PdfColor.fromInt(0xFFFFF8E4);
const _pdfMuted = PdfColor.fromInt(0xFF6B7A76);
const _pdfBorder = PdfColor.fromInt(0xFFE3E1D7);

/// Builds a premium, brand-colored PDF quotation. Loads Noto Sans + Noto
/// Sans Arabic via `PdfGoogleFonts` (cached after first fetch) so the same
/// document renders English, Arabic and Kurdish Sorani correctly — spec
/// §24. A factory without outbound network access on first run can swap
/// this loader for bundled local TTFs (see README → Localization).
class QuotationPdfService {
  const QuotationPdfService();

  Future<Uint8List> build({
    required Quotation quotation,
    required Customer customer,
    required Project project,
    required CompanyProfile company,
  }) async {
    final latinFont = await PdfGoogleFonts.notoSansRegular();
    final latinBold = await PdfGoogleFonts.notoSansBold();
    final arabicFont = await PdfGoogleFonts.notoSansArabicRegular();

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: latinFont, bold: latinBold, fontFallback: [arabicFont]),
    );

    final dateFormat = DateFormat('dd MMM yyyy');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 48),
        header: (context) => _header(company, quotation, dateFormat),
        footer: (context) => _footer(company, context),
        build: (context) => [
          pw.SizedBox(height: 12),
          _partiesSection(customer, project),
          pw.SizedBox(height: 18),
          _itemsTable(quotation),
          pw.SizedBox(height: 16),
          pw.Align(alignment: pw.Alignment.centerRight, child: _totalsBlock(quotation)),
          pw.SizedBox(height: 20),
          if (quotation.notes != null && quotation.notes!.isNotEmpty) ...[
            pw.Text('Notes', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: _pdfDarkGreen)),
            pw.SizedBox(height: 4),
            pw.Text(quotation.notes!, style: const pw.TextStyle(fontSize: 9.5)),
            pw.SizedBox(height: 16),
          ],
          pw.Text('Terms & Conditions',
              style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: _pdfDarkGreen)),
          pw.SizedBox(height: 4),
          pw.Text(quotation.termsAndConditions, style: const pw.TextStyle(fontSize: 9, color: _pdfMuted)),
          pw.SizedBox(height: 28),
          _signatureBlock(),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _header(CompanyProfile company, Quotation quotation, DateFormat dateFormat) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(company.name,
                    style: const pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _pdfDarkGreen)),
                if (company.address.isNotEmpty)
                  pw.Text(company.address, style: const pw.TextStyle(fontSize: 8.5, color: _pdfMuted)),
                pw.Text(
                  [company.phone, company.email, company.website].where((s) => s.isNotEmpty).join('  ·  '),
                  style: const pw.TextStyle(fontSize: 8.5, color: _pdfMuted),
                ),
              ],
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: pw.BoxDecoration(color: _pdfDarkGreen, borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('QUOTATION', style: const pw.TextStyle(color: _pdfCream, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text(quotation.quoteNumber, style: const pw.TextStyle(color: PdfColors.white, fontSize: 9.5)),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(height: 3, color: _pdfCreamDeep),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _labelValue('Date', dateFormat.format(quotation.issueDate)),
            _labelValue('Valid until', dateFormat.format(quotation.expiryDate)),
            _labelValue('Status', quotation.status.label),
          ],
        ),
      ],
    );
  }

  pw.Widget _labelValue(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label.toUpperCase(), style: const pw.TextStyle(fontSize: 7.5, color: _pdfMuted)),
        pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  pw.Widget _partiesSection(Customer customer, Project project) {
    pw.Widget card(String title, List<String> lines) {
      return pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _pdfBorder), borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(title, style: const pw.TextStyle(fontSize: 8.5, color: _pdfDarkGreen, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              for (final line in lines.where((l) => l.isNotEmpty))
                pw.Padding(padding: const pw.EdgeInsets.only(top: 1.5), child: pw.Text(line, style: const pw.TextStyle(fontSize: 9.5))),
            ],
          ),
        ),
      );
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        card('BILL TO', [
          customer.fullName,
          customer.company ?? '',
          customer.phone,
          customer.email ?? '',
          [customer.address, customer.city, customer.country].where((s) => (s ?? '').isNotEmpty).join(', '),
        ]),
        pw.SizedBox(width: 10),
        card('PROJECT', [project.name, project.projectNumber, project.location ?? '', project.type.label]),
      ],
    );
  }

  pw.Widget _itemsTable(Quotation quotation) {
    final headers = ['#', 'Item', 'Dimensions', 'Qty', 'Unit price', 'Line total'];
    return pw.Table(
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _pdfBorder, width: 0.6),
        bottom: pw.BorderSide(color: _pdfBorder, width: 0.6),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(0.4),
        1: pw.FlexColumnWidth(2.6),
        2: pw.FlexColumnWidth(1.6),
        3: pw.FlexColumnWidth(0.7),
        4: pw.FlexColumnWidth(1.1),
        5: pw.FlexColumnWidth(1.1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _pdfDarkGreen),
          children: [
            for (final h in headers)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 5),
                child: pw.Text(h,
                    style: const pw.TextStyle(color: _pdfCream, fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
              ),
          ],
        ),
        for (var i = 0; i < quotation.items.length; i++) _itemRow(i + 1, quotation.items[i]),
      ],
    );
  }

  pw.TableRow _itemRow(int index, QuoteItem item) {
    pw.Widget cell(String text, {bool bold = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 5),
          child: pw.Text(text, style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : null)),
        );

    return pw.TableRow(
      children: [
        cell('$index'),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 5),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              _elevationDiagram(item.widthMm, item.heightMm),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(item.configurationName, style: const pw.TextStyle(fontSize: 9.5)),
                    pw.Text(item.productTypeLabel, style: const pw.TextStyle(fontSize: 8, color: _pdfMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        cell(item.dimensionsLabel),
        cell('${item.quantity}'),
        cell('${item.currencySymbol}${item.unitPrice.toStringAsFixed(2)}'),
        cell('${item.currencySymbol}${item.lineTotal.toStringAsFixed(2)}', bold: true),
      ],
    );
  }

  /// A tiny proportioned rectangle standing in for the 2D elevation preview
  /// (spec §24) — drawn directly with PDF primitives from the item's real
  /// width/height so it is never a stock image.
  pw.Widget _elevationDiagram(double widthMm, double heightMm) {
    const maxDim = 34.0;
    final ratio = heightMm > 0 && widthMm > 0 ? widthMm / heightMm : 1.0;
    final w = ratio >= 1 ? maxDim : maxDim * ratio;
    final h = ratio >= 1 ? maxDim / ratio : maxDim;
    return pw.Container(
      width: maxDim + 6,
      height: maxDim + 6,
      alignment: pw.Alignment.center,
      child: pw.Container(
        width: w,
        height: h,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _pdfDarkGreen, width: 1.2),
          color: _pdfCreamSoft,
        ),
      ),
    );
  }

  pw.Widget _totalsBlock(Quotation quotation) {
    pw.Widget row(String label, double amount, {bool bold = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
        child: pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.SizedBox(
              width: 110,
              child: pw.Text(label, style: pw.TextStyle(fontSize: bold ? 10.5 : 9.5, fontWeight: bold ? pw.FontWeight.bold : null)),
            ),
            pw.SizedBox(
              width: 80,
              child: pw.Text(
                '\$${amount.toStringAsFixed(2)}',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: bold ? 12 : 9.5,
                  fontWeight: bold ? pw.FontWeight.bold : null,
                  color: bold ? _pdfDarkGreen : null,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          row('Items subtotal', quotation.itemsSubtotal),
          if (quotation.globalDiscountAmount > 0) row('Discount', -quotation.globalDiscountAmount),
          if (quotation.installationTotal > 0) row('Installation', quotation.installationTotal),
          if (quotation.deliveryCost > 0) row('Delivery', quotation.deliveryCost),
          if (quotation.taxAmount > 0) row('Tax (${quotation.taxPercent.toStringAsFixed(1)}%)', quotation.taxAmount),
          pw.Divider(color: _pdfBorder, height: 12),
          row('Grand total', quotation.grandTotal, bold: true),
        ],
      ),
    );
  }

  pw.Widget _signatureBlock() {
    pw.Widget block(String label) {
      return pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(height: 1, color: _pdfBorder),
            pw.SizedBox(height: 4),
            pw.Text(label, style: const pw.TextStyle(fontSize: 8.5, color: _pdfMuted)),
          ],
        ),
      );
    }

    return pw.Row(children: [block('Prepared by / Company signature'), pw.SizedBox(width: 40), block('Accepted by / Customer signature')]);
  }

  pw.Widget _footer(CompanyProfile company, pw.Context context) {
    return pw.Column(
      children: [
        pw.Divider(color: _pdfBorder, height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(company.quotationFooter, style: const pw.TextStyle(fontSize: 7.5, color: _pdfMuted)),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 7.5, color: _pdfMuted)),
          ],
        ),
      ],
    );
  }
}
