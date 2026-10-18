// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2604 — a lint test takes its file list from `lint_sources.dart`.
//
// `lint_sources.dart` exists because eight lint tests each hand-rolled the
// same directory walk and the copies diverged. The walk is one; this is the
// ratchet that keeps it one while the remaining hand-written walks are
// moved over, a few at a time. A lint test that calls `Directory(` itself
// and is not listed fails; a listed file that no longer does fails too, so
// the list can only shrink and a finished migration cannot be un-finished.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// The lint files that still build a `Directory(...)` themselves, each to be
/// moved to [handWrittenDartFiles], [sqlFiles] or [markdownFiles]. RATCHET:
/// remove a name when its file stops; never add one.
const _stillWalkingByHand = <String>{};

final _directoryCall = RegExp(r'\bDirectory\(');

bool _callsDirectory(File file) => file
    .readAsLinesSync()
    .map((l) => l.trim())
    .where((l) => !l.startsWith('//'))
    .any(_directoryCall.hasMatch);

void main() {
  test('only the listed lint files build their own Directory walk', () {
    final calling = {
      for (final f in Directory('test/lint').listSync().whereType<File>())
        if (f.path.endsWith('.dart') &&
            !f.path.endsWith('/lint_sources.dart') &&
            !f.path.endsWith('/lint_sources_test.dart') &&
            _callsDirectory(f))
          f.uri.pathSegments.last,
    };
    expect(
      calling.difference(_stillWalkingByHand),
      isEmpty,
      reason:
          'take the file list from lint_sources.dart '
          '(handWrittenDartFiles / sqlFiles / markdownFiles)',
    );
    expect(
      _stillWalkingByHand.difference(calling),
      isEmpty,
      reason:
          'these no longer walk by hand: delete them from the list '
          '(the ratchet only falls)',
    );
  });

  group('the shared walks', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('lint-sources');
      for (final n in ['0002_b.sql', '0001_a.sql', 'note.md', 'x.txt']) {
        File('${dir.path}/$n').writeAsStringSync('-');
      }
      Directory('${dir.path}/sub').createSync();
      File('${dir.path}/sub/0003_c.sql').writeAsStringSync('-');
      File('${dir.path}/sub/deep.md').writeAsStringSync('-');
    });
    tearDown(() => dir.deleteSync(recursive: true));

    String name(File f) => f.uri.pathSegments.last;

    test('sqlFiles lists the .sql files in path order, flat by default', () {
      expect(sqlFiles(dir.path).map(name), ['0001_a.sql', '0002_b.sql']);
      expect(sqlFiles(dir.path, recursive: true).map(name), [
        '0001_a.sql',
        '0002_b.sql',
        '0003_c.sql',
      ]);
    });

    test('markdownFiles descends by default and ignores other kinds', () {
      expect(markdownFiles(dir.path).map(name), ['note.md', 'deep.md']);
      expect(markdownFiles(dir.path, recursive: false).map(name), ['note.md']);
    });
  });
}
