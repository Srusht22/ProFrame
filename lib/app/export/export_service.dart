import 'dart:convert';
import 'dart:typed_data';

import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/errors/app_exception.dart';
import '../../core/i18n/strings.dart';
import '../../domain/design_document.dart';
import '../../infrastructure/export/pdf_design_sheet.dart';
import '../../infrastructure/export/project_file.dart';
import 'elevation_painter.dart';

/// What came out of an export.
class ExportResult {
  final String fileName;
  final int byteCount;

  const ExportResult({required this.fileName, required this.byteCount});
}

/// Produces and hands over the three export formats (spec section 11).
///
/// Every one is generated from the current [DesignDocument] at the moment the
/// user asks, so an export can never be of stale geometry.
///
/// **These are not equivalent.** The PDF and the PNG are views of a design;
/// only the `.proframe` file is the design. A mesh or a picture does not carry
/// the parameters, and the app never suggests otherwise.
class ExportService {
  /// Hands a file to the platform. Injected so tests can capture it instead of
  /// opening a share sheet.
  final Future<void> Function(Uint8List bytes, String fileName, String mimeType)
      deliver;

  /// The language and digits every export is written in — the same ones the
  /// user is reading the app in.
  final AppStrings strings;

  const ExportService({
    this.deliver = _shareFile,
    this.strings = const AppStrings(),
  });

  /// The PDF design sheet.
  Future<ExportResult> exportPdf(DesignDocument design) async {
    final bytes = await PdfDesignSheet.build(design, strings: strings);
    final name = PdfDesignSheet.fileNameFor(design);
    await deliver(bytes, name, 'application/pdf');
    return ExportResult(fileName: name, byteCount: bytes.length);
  }

  /// The front-view drawing, with dimensions and notes optionally hidden.
  Future<ExportResult> exportPng(
    DesignDocument design, {
    ElevationOptions options = const ElevationOptions(),
  }) async {
    final bytes = await renderElevationPng(
      design,
      options: options,
      strings: strings,
    );
    final name = '${_safeName(design.name)}.png';
    await deliver(bytes, name, 'image/png');
    return ExportResult(fileName: name, byteCount: bytes.length);
  }

  /// The editable project itself.
  Future<ExportResult> exportProject(DesignDocument design) async {
    final bytes = Uint8List.fromList(utf8.encode(ProjectFile.encode(design)));
    final name = ProjectFile.fileNameFor(design);
    await deliver(bytes, name, 'application/json');
    return ExportResult(fileName: name, byteCount: bytes.length);
  }

  /// Reads a project file back.
  ///
  /// Throws [DesignDataException] with something a user can read when the file
  /// is not ours, is damaged, or is from a newer build.
  static DesignDocument importProject(String contents) =>
      ProjectFile.decode(contents);

  /// Opens the platform's print dialogue for the design sheet.
  ///
  /// Separate from [exportPdf] because printing and sharing are different
  /// intentions, and a factory more often wants the sheet on paper.
  Future<void> printPdf(DesignDocument design) async {
    await Printing.layoutPdf(
      onLayout: (_) => PdfDesignSheet.build(design, strings: strings),
      name: PdfDesignSheet.fileNameFor(design),
    );
  }

  static String _safeName(String name) {
    final safe = name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
    return safe.isEmpty ? 'design' : safe;
  }

  /// The real hand-over: the platform share sheet, which on the web is a
  /// download.
  ///
  /// `share_plus` is used rather than writing to a path because the three
  /// agreed platforms disagree about what a path even is — Android scoped
  /// storage, the iOS sandbox, and a browser with no filesystem at all.
  static Future<void> _shareFile(
    Uint8List bytes,
    String fileName,
    String mimeType,
  ) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, name: fileName, mimeType: mimeType)],
        fileNameOverrides: [fileName],
      ),
    );
  }
}
