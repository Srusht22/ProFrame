import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// `lib/` holds what the architecture in CLAUDE.md says it holds, and nothing
// else.
//
// This guards the working copy rather than any one function, and it exists
// because of a real morning lost to it. The application used to have a
// localisation layer under `lib/core/localization/`, part of it written by
// hand and part of it **generated** by `flutter gen-l10n`. Rebuilding the
// application took the layer out — but git only removes what git tracks, and
// generated files were never tracked. They stayed on disk, in a folder
// nothing references, referring to packages the pubspec no longer has, and
// the editor reported a dozen errors in a project whose own `flutter
// analyze` was clean. There is nothing to find in the code, because the
// fault is not in the code: it is a folder that should not be there.
//
// So `flutter test` says so plainly, with the path and what to do about it.
// ---------------------------------------------------------------------------

/// The layers, exactly as the architecture names them.
const layers = {'app', 'domain', 'infrastructure'};

/// The one file that is allowed to sit above them.
const entryPoint = 'main.dart';

void main() {
  test('lib/ holds the three layers and main.dart, and nothing else', () {
    final lib = Directory('lib');
    expect(lib.existsSync(), isTrue);

    final strays = <String>[];
    for (final entry in lib.listSync()) {
      final name = entry.uri.pathSegments
          .where((part) => part.isNotEmpty)
          .last;
      if (entry is Directory && layers.contains(name)) continue;
      if (entry is File && name == entryPoint) continue;
      strays.add(entry.path);
    }

    expect(
      strays,
      isEmpty,
      reason: 'Something is in lib/ that the architecture does not name:\n'
          '  ${strays.join('\n  ')}\n\n'
          'If you did not put it there, it is left over from an earlier '
          'version of the application — most likely generated files that '
          'git never tracked, so removing the layer never removed them. '
          'Delete it: they are built from nothing that is still here, and '
          'the editor will report errors in them for as long as they exist.\n\n'
          'lib/ holds app/, domain/, infrastructure/ and main.dart.',
    );
  });

  // Since Phase 34 the application is localised again — English and Central
  // Kurdish — so `flutter gen-l10n` output and the .arb files it reads are
  // expected, but in one place only, lib/app/l10n/, and every one of them
  // tracked by git. What went wrong before was never that the files existed:
  // it was generated files git did not track, left behind in a folder
  // nothing read. Tracked, they leave with the code that uses them; and
  // test/app/the_words_are_one_set_test.dart holds that they are current.
  test('translation files are only in lib/app/l10n, and all tracked', () {
    final found = <String>[];
    for (final entry in Directory('lib').listSync(recursive: true)) {
      if (entry is! File) continue;
      final name = entry.uri.pathSegments.last;
      if (name.startsWith('app_localizations') || name.endsWith('.arb')) {
        found.add(entry.path.replaceAll(r'\', '/'));
      }
    }
    expect(found, isNotEmpty, reason: 'the application is localised');

    final elsewhere = [
      for (final path in found)
        if (!path.startsWith('lib/app/l10n/')) path,
    ];
    expect(elsewhere, isEmpty,
        reason: 'Translation files outside lib/app/l10n/:\n'
            '  ${elsewhere.join('\n  ')}\n\n'
            'The application reads its words from lib/app/l10n/ only. A '
            'file of this kind anywhere else is left over: delete it.');

    final tracked = Process.runSync('git', ['ls-files', 'lib/app/l10n']);
    expect(tracked.exitCode, 0, reason: '${tracked.stderr}');
    final known = (tracked.stdout as String)
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toSet();
    final untracked = [
      for (final path in found)
        if (!known.contains(path)) path,
    ];
    expect(untracked, isEmpty,
        reason: 'Translation files git does not track:\n'
            '  ${untracked.join('\n  ')}\n\n'
            'Generated or not, they are part of the application: add them '
            '(`git add lib/app/l10n`), or delete them if nothing uses them.');
  });
}
