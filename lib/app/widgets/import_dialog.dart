import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/design_document.dart';
import '../../infrastructure/export/project_file.dart';
import '../export/export_service.dart';
import 'notice.dart';

/// Opens a `.proframe` file the user picks (spec section 11B).
///
/// Reads the file, validates it, and returns the design — or explains, in a
/// sentence, why it could not. A file that is not ours, is damaged, or comes
/// from a newer build is refused rather than partially loaded.
Future<DesignDocument?> showImportDialog(BuildContext context) async {
  const typeGroup = XTypeGroup(
    label: 'ProFrame project',
    extensions: [ProjectFile.extension, 'json'],
  );

  final XFile? file;
  try {
    file = await openFile(acceptedTypeGroups: const [typeGroup]);
  } on Object catch (error) {
    if (context.mounted) await _explain(context, 'That file could not be opened: $error');
    return null;
  }
  if (file == null) return null;

  final String contents;
  try {
    contents = utf8.decode(await file.readAsBytes());
  } on Object {
    if (context.mounted) {
      await _explain(
        context,
        'That file is not text, so it is not a ProFrame project.',
      );
    }
    return null;
  }

  try {
    return ExportService.importProject(contents);
  } on DesignDataException catch (error) {
    if (context.mounted) await _explain(context, error.message);
    return null;
  }
}

Future<void> _explain(BuildContext context, String message) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('That project could not be opened'),
        content: Notice(tone: NoticeTone.problem, message: message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
