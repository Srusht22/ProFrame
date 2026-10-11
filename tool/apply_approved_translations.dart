// Puts the Central Kurdish wording a reviewer approved into the application.
//
//     dart run tool/apply_approved_translations.dart
//     dart run tool/generate_domain_words.dart
//     flutter gen-l10n
//
// It reads docs/localization/central_kurdish_translation_review.md, takes
// every row whose **Approved Sorani** column is filled in, and writes that
// wording into lib/app/l10n/app_ckb.arb under the row's key. Nothing else
// is touched: a row left empty keeps the proposed wording, English is never
// changed, and no key is added or removed. A row naming a key the ARB does
// not have, or an approved wording that drops or adds a `{placeholder}`, is
// refused and reported, and nothing is written until every approved row is
// sound. Then the two generators above bring the code up to date, and
// `flutter test test/app/the_words_are_one_set_test.dart` confirms it.
//
// A figure placeholder — `{amount}`, `{size}`, `{rate}` and the like — is
// kept as one left-to-right run in the Kurdish with invisible marks the
// reviewer need not type; they are put back.
//
// Write `\n` in a cell for a line break and `\|` for a vertical bar. A
// message that begins or ends with a space keeps it: a table cannot show
// one, so it is put back.

import 'dart:convert';
import 'dart:io';

const reviewPath = 'docs/localization/central_kurdish_translation_review.md';
const kurdishPath = 'lib/app/l10n/app_ckb.arb';
const englishPath = 'lib/app/l10n/app_en.arb';

void main() {
  final review = File(reviewPath).readAsStringSync();
  final kurdish = Map<String, Object?>.of(
    jsonDecode(File(kurdishPath).readAsStringSync()) as Map<String, Object?>,
  );
  final english =
      jsonDecode(File(englishPath).readAsStringSync()) as Map<String, Object?>;

  final approved = approvedIn(review);
  final problems = <String>[];
  var changed = 0;
  for (final MapEntry(key: key, value: wording) in approved.entries) {
    final was = english[key];
    if (was is! String || key.startsWith('@')) {
      problems.add('$key: no such message in $englishPath');
      continue;
    }
    if (!_samePlaceholders(was, wording)) {
      problems.add(
        '$key: the approved wording must keep exactly the placeholders '
        '${_placeholders(was).toList()..sort()}',
      );
      continue;
    }
    // A table cell loses the spaces at its edges; a message that begins or
    // ends with one (a separator, a clause added after a date) keeps them.
    final kept = markFigures(_edgesOf(kurdish[key] as String? ?? was, wording));
    if (kurdish[key] != kept) {
      kurdish[key] = kept;
      changed++;
    }
  }
  if (problems.isNotEmpty) {
    stderr.writeln('Nothing was written:\n  ${problems.join('\n  ')}');
    exitCode = 1;
    return;
  }
  File(kurdishPath).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(kurdish)}\n',
  );
  stdout.writeln(
    '${approved.length} approved, $changed changed in $kurdishPath. '
    'Now run tool/generate_domain_words.dart and flutter gen-l10n.',
  );
}

/// Every row of [review] with an approved wording, by key.
Map<String, String> approvedIn(String review) {
  final out = <String, String>{};
  for (final line in const LineSplitter().convert(review)) {
    if (!line.startsWith('| `')) continue;
    final cells = _cells(line);
    // key | English | context | proposed | confidence | status | approved
    if (cells.length < 7) continue;
    final key = cells[0].replaceAll('`', '').trim();
    final wording = cells[6].trim();
    if (key.isEmpty || wording.isEmpty) continue;
    out[key] = wording.replaceAll(r'\n', '\n');
  }
  return out;
}

/// The cells of a Markdown table row, `\|` read as a bar inside a cell.
List<String> _cells(String row) {
  final cells = <String>[];
  final cell = StringBuffer();
  for (var i = 1; i < row.length; i++) {
    final c = row[i];
    if (c == r'\' && i + 1 < row.length && row[i + 1] == '|') {
      cell.write('|');
      i++;
    } else if (c == '|') {
      cells.add(cell.toString().trim());
      cell.clear();
    } else {
      cell.write(c);
    }
  }
  return cells;
}

/// The placeholders that stand for a figure — an amount, a size, a rate —
/// and are kept left to right inside a Kurdish sentence, with the
/// an invisible left-to-right mark (U+200E) either side, so a figure is never
/// read backwards or split from its unit. A reviewer need not type them:
/// they are put back here.
const figurePlaceholders = {
  'amount',
  'bar',
  'due',
  'each',
  'frame',
  'joint',
  'length',
  'measured',
  'rate',
  'size',
  'stated',
  'subtotal',
  'total',
  'discount',
  'percent',
  'zoom',
};

/// [message] with every figure placeholder marked, once; an exchange
/// rate, `1 {from} = {rate} {to}`, marked as a whole.
String markFigures(String message) {
  // A left-to-right mark either side: what the bidirectional algorithm
  // needs to keep the figure one run, and not one of the bidi controls that
  // source code is warned against carrying.
  const mark = '\u200E';
  final bare = message.replaceAll(mark, '');
  const rate = '1 {from} = {rate} {to}';
  if (bare.contains(rate)) return bare.replaceAll(rate, '$mark$rate$mark');
  return bare.replaceAllMapped(
    RegExp(r'\{(\w+)\}'),
    (m) => figurePlaceholders.contains(m.group(1))
        ? '$mark${m.group(0)}$mark'
        : m.group(0)!,
  );
}

/// [wording] with the leading and trailing spaces of [was].
String _edgesOf(String was, String wording) {
  final lead = RegExp(r'^\s*').firstMatch(was)!.group(0)!;
  final trail = RegExp(r'\s*$').firstMatch(was)!.group(0)!;
  return '$lead${wording.trim()}$trail';
}

Set<String> _placeholders(String message) => {
  for (final m in RegExp(r'\{(\w+)(?:,|\})').allMatches(message)) m.group(1)!,
};

bool _samePlaceholders(String a, String b) {
  final x = _placeholders(a);
  final y = _placeholders(b);
  return x.length == y.length && x.containsAll(y);
}
