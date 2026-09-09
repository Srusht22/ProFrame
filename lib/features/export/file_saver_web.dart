// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

/// On the web there is no share sheet and no file system, so the export is
/// delivered as a normal browser download.
Future<String> saveAndShareBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  String? subject,
}) async {
  final blob = html.Blob(<Object>[bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return fileName;
}
