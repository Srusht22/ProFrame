import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/apply_approved_translations.dart' as apply;

// docs/localization/central_kurdish_translation_review.md is where a
// Sorani speaker corrects the wording, and tool/apply_approved_translations
// .dart is how their corrections reach the application. These hold that
// the review lists every message with the wording the application actually
// shows, that nothing in it is passed off as already approved, and that
// the tool reads a corrected row — and only that — as the user wrote it.

void main() {
  final review = File(apply.reviewPath).readAsStringSync();
  final english = jsonDecode(
    File(apply.englishPath).readAsStringSync(),
  ) as Map<String, Object?>;
  final kurdish = jsonDecode(
    File(apply.kurdishPath).readAsStringSync(),
  ) as Map<String, Object?>;

  /// The table's rows, by key: English, proposed Sorani, confidence and
  /// the approved column, as the reviewer reads them.
  final rows = <String, List<String>>{};
  for (final line in const LineSplitter().convert(review)) {
    if (!line.startsWith('| `')) continue;
    final cells = line
        .substring(1, line.length - 1)
        .split(RegExp(r'(?<!\\)\|'))
        .map((c) => c.trim().replaceAll(r'\|', '|').replaceAll(r'\n', '\n'))
        .toList();
    rows[cells[0].replaceAll('`', '')] = cells;
  }

  test('it is dated and says how to apply what is approved', () {
    expect(review, contains('Phase 34'));
    expect(review, contains('2026-10-11'));
    expect(review, contains('dart run tool/apply_approved_translations.dart'));
  });

  test('every message is in it once, with the wording the app shows', () {
    final keys = [
      for (final k in english.keys)
        if (!k.startsWith('@')) k,
    ];
    expect(rows.keys.toSet(), keys.toSet());
    for (final key in keys) {
      // A cell cannot hold the spaces at its edges; the tool keeps them.
      expect(rows[key]![1], (english[key]! as String).trim(), reason: key);
      // What the application shows is the approved wording once a
      // reviewer has given one and it has been applied, and the proposed
      // wording until then.
      final approved = rows[key]![6];
      expect(
        approved.isEmpty ? rows[key]![3] : approved,
        (kurdish[key]! as String).trim(),
        reason: '$key: run tool/apply_approved_translations.dart',
      );
    }
  });

  test('every row has a confidence', () {
    for (final MapEntry(key: key, value: cells) in rows.entries) {
      expect(['High', 'Medium', 'Low'], contains(cells[4]), reason: key);
    }
  });

  test('the trade terms the factory must confirm are low confidence', () {
    for (final key in [
      'catBendShoulderAluminium',
      'catSystemAluminium',
      'rfSealed',
      'hwLever',
      'inPleated',
    ]) {
      expect(rows[key]![4], 'Low', reason: key);
    }
  });

  test('the tool reads an approved row as it was written', () {
    const table = '''
| Key | English | Context | Proposed Sorani | Confidence | Reason / status | Approved Sorani |
| --- | --- | --- | --- | --- | --- | --- |
| `one` | One | c | یەک | High | r |  |
| `two` | Two {name} | c | دوو {name} | Low | r | دووی {name} \\| تر\\nهێڵ |
''';
    expect(apply.approvedIn(table), {'two': 'دووی {name} | تر\nهێڵ'});
  });
}
