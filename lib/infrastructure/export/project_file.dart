import 'dart:convert';

import '../../core/errors/app_exception.dart';
import '../../domain/design_document.dart';

/// The native, editable project format.
///
/// This is the one export that is **not** a picture: it carries the whole
/// structured design, so a project sent to a colleague reopens fully editable
/// rather than as something to look at. A PDF or a PNG is a view of a design;
/// only this is the design (spec section 11B).
abstract final class ProjectFile {
  /// File extension, without the dot.
  static const String extension = 'proframe';

  /// Marks the file as ours, so a wrong file is refused with a sentence
  /// instead of a parser error.
  static const String magic = 'proframe.project';

  /// The envelope version, separate from the design's own schema version.
  static const int formatVersion = 1;

  static String fileNameFor(DesignDocument design) {
    final safe = design.name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
    return '${safe.isEmpty ? 'design' : safe}.$extension';
  }

  /// Writes [design] out.
  static String encode(DesignDocument design) => const JsonEncoder.withIndent(
        '  ',
      ).convert({
        'format': magic,
        'formatVersion': formatVersion,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'design': design.toJson(),
      });

  /// Reads a project file.
  ///
  /// Validates before trusting: a file that is not ours, or is from a newer
  /// build, is refused in plain language. A missing profile system is *not*
  /// silently substituted — the design records which system it wants, and
  /// [DesignDocument.profileSystem] reports the fallback rather than hiding it
  /// (spec section 11B).
  static DesignDocument decode(String contents) {
    final Object? parsed;
    try {
      parsed = jsonDecode(contents);
    } on FormatException {
      throw const DesignDataException(
        'That file is not a ProFrame project.',
      );
    }

    if (parsed is! Map) {
      throw const DesignDataException('That file is not a ProFrame project.');
    }
    if (parsed['format'] != magic) {
      throw const DesignDataException(
        'That file is not a ProFrame project. Look for a file ending '
        '".$extension".',
      );
    }

    final version = parsed['formatVersion'];
    if (version is! int) {
      throw const DesignDataException(
        'This project file has no version number, so it cannot be opened '
        'safely.',
      );
    }
    if (version > formatVersion) {
      throw DesignDataException(
        'This project was exported by a newer version of ProFrame '
        '(format $version; this build reads up to $formatVersion). Update the '
        'app to open it.',
      );
    }

    return DesignDocument.fromJson(parsed['design']);
  }
}
