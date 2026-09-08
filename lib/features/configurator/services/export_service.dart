import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../domain/configuration/product_configuration.dart';
import '../../../domain/manufacturing/bom_line.dart';
import '../../../domain/manufacturing/cutting_list_line.dart';

/// File exports for the configurator summary (spec §62): BOM and cutting
/// list as CSV (opens in any spreadsheet app), and the full configuration
/// as JSON (spec §36 — "Allow saving the complete configuration as JSON",
/// the same seam a future DXF/CNC/ERP integration would read from).
class ExportService {
  const ExportService();

  Future<void> shareBom(ProductConfiguration config, List<BomLine> bom) async {
    final buffer = StringBuffer('Part Number,Description,Quantity,Unit,Unit Price,Total Price\n');
    for (final line in bom) {
      buffer.writeln(
        '"${line.partNumber}","${line.description}",${line.quantity.toStringAsFixed(2)},"${line.unit}",${line.unitPrice.toStringAsFixed(2)},${line.totalPrice.toStringAsFixed(2)}',
      );
    }
    await _shareText(buffer.toString(), '${_slug(config.name)}_bom.csv');
  }

  Future<void> shareCuttingList(ProductConfiguration config, List<CuttingListLine> cuttingList) async {
    final buffer = StringBuffer('Component,Length (mm),Quantity,Material\n');
    for (final line in cuttingList) {
      buffer.writeln('"${line.component}",${line.lengthMm.toStringAsFixed(0)},${line.quantity},"${line.material}"');
    }
    await _shareText(buffer.toString(), '${_slug(config.name)}_cutting_list.csv');
  }

  Future<void> shareConfigurationJson(ProductConfiguration config) async {
    final json = const JsonEncoder.withIndent('  ').convert(config.toJson());
    await _shareText(json, '${_slug(config.name)}_configuration.json');
  }

  Future<void> _shareText(String content, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: filename));
  }

  String _slug(String input) {
    final cleaned = input.trim().isEmpty ? 'configuration' : input.trim();
    return cleaned.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }
}
