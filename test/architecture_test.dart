import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Structural rules that are easy to state and easy to break by accident.
///
/// The specification requires geometry services that are testable
/// independently of widgets (spec section 9). That only stays true if nothing
/// in the domain layer reaches for Flutter, so it is asserted rather than
/// trusted.
void main() {
  List<File> dartFilesIn(String directory) => Directory(directory)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('the domain layer does not depend on Flutter', () {
    final offenders = <String>[];

    for (final file in dartFilesIn('lib/domain')) {
      final flutterImports = file
          .readAsLinesSync()
          .where((line) => line.startsWith('import '))
          .where((line) => line.contains('package:flutter'));
      for (final line in flutterImports) {
        offenders.add('${file.path}: $line');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'The domain layer must be plain Dart so geometry can be tested '
          'without a widget tree. Move anything that needs Flutter into '
          'lib/core or lib/app.\n${offenders.join('\n')}',
    );
  });

  test('the domain layer does not depend on the UI layer', () {
    final offenders = <String>[];

    for (final file in dartFilesIn('lib/domain')) {
      final appImports = file
          .readAsLinesSync()
          .where((line) => line.startsWith('import '))
          .where((line) => line.contains('/app/') || line.contains("'../app"));
      for (final line in appImports) {
        offenders.add('${file.path}: $line');
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('no widget declares its own brand colour', () {
    // Spec section 7: colours come from the tokens, not from literals
    // scattered through the widgets.
    final offenders = <String>[];
    final brandLiteral = RegExp(r'0xFF(FFEFB3|013E37)', caseSensitive: false);

    for (final file in [...dartFilesIn('lib/app'), ...dartFilesIn('lib/domain')]) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (brandLiteral.hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Use AppColors instead of a colour literal.\n'
          '${offenders.join('\n')}',
    );
  });

  test('main.dart is wiring only', () {
    // Spec section 9 explicitly forbids putting the application in main.dart.
    final lines = File('lib/main.dart').readAsLinesSync();

    expect(
      lines.length,
      lessThan(40),
      reason: 'main.dart has grown past wiring; move the code into lib/app.',
    );
    expect(
      lines.where((l) => l.contains('class ') && l.contains('Widget')),
      isEmpty,
      reason: 'Widgets belong in lib/app, not in main.dart.',
    );
  });
}
