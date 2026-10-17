// SPDX-License-Identifier: AGPL-3.0-or-later
// Preflight observes content drift without changing the index or unrelated
// edits; failures in discovery or generation cannot report a clean candidate.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/preflight.dart' as cli;
import '../../tool/preflight/git_state.dart';

void main() {
  late Directory root;
  late PreflightGit git;
  File file(String name) {
    final value = File('${root.path}/$name');
    value.parent.createSync(recursive: true);
    return value;
  }

  ProcessResult command(String name, List<String> args, String directory) =>
      runPreflightProcess(name, args, directory);
  void commit() {
    git
      ..text(['add', '--all'])
      ..text([
        '-c',
        'user.name=Fixture',
        '-c',
        'user.email=fixture@example.invalid',
        '-c',
        'commit.gpgsign=false',
        'commit',
        '-m',
        'fixture',
      ]);
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('preflight fixture ');
    git = PreflightGit(root.path, command)..text(['init']);
    file('lib/l10n/_fragments/fixture_en.arb').writeAsStringSync('{}');
    file('generated.g.dart').writeAsStringSync('original');
    file('notes.txt').writeAsStringSync('keep');
    commit();
  });
  tearDown(() => root.deleteSync(recursive: true));

  test(
    'already-dirty generated content is detected, including staged edits',
    () {
      file('generated.g.dart').writeAsStringSync('staged');
      git.text(['add', '--', 'generated.g.dart']);
      file('generated.g.dart').writeAsStringSync('unstaged');
      final index = git.text(['write-tree']);
      final before = git.snapshot();
      file('generated.g.dart').writeAsStringSync('regenerated');
      expect(changedFingerprints(before, git.snapshot()), ['generated.g.dart']);
      expect(git.text(['write-tree']), index);
    },
  );

  test('unchanged dirty files produce no false drift', () {
    file('notes.txt').writeAsStringSync('user edit');
    expect(changedFingerprints(git.snapshot(), git.snapshot()), isEmpty);
  });

  test('dirty to clean is still a generator content change', () {
    file('generated.g.dart').writeAsStringSync('stale');
    final before = git.snapshot();
    file('generated.g.dart').writeAsStringSync('original');
    expect(changedFingerprints(before, git.snapshot()), ['generated.g.dart']);
  });

  test('creation, deletion and both sides of rename are visible', () {
    final before = git.snapshot();
    file('generated.g.dart').renameSync('${root.path}/moved.g.dart');
    file('new.g.dart').writeAsStringSync('new');
    expect(changedFingerprints(before, git.snapshot()), [
      'generated.g.dart',
      'moved.g.dart',
      'new.g.dart',
    ]);
  });

  test('deleted authoritative input still selects its generators', () {
    file('lib/l10n/_fragments/fixture_en.arb').deleteSync();
    expect(
      git.changedPaths('HEAD'),
      contains('lib/l10n/_fragments/fixture_en.arb'),
    );
    var calls = 0;
    ProcessResult execute(String name, List<String> args, String dir) {
      if (name == 'git') return command(name, args, dir);
      calls++;
      return ProcessResult(0, 0, '', '');
    }

    expect(
      cli.run(
        ['--base', 'HEAD'],
        workingDirectory: root.path,
        execute: execute,
      ),
      0,
    );
    expect(calls, 2);
  });

  test(
    'whitespace and arrow-like paths are not trimmed or parsed as renames',
    () {
      const unusual = ' leading -> trailing .g.dart';
      file(unusual).writeAsStringSync('one');
      expect(git.changedPaths('HEAD'), contains(unusual));
      final before = git.snapshot();
      file(unusual).writeAsStringSync('two');
      expect(changedFingerprints(before, git.snapshot()), [unusual]);
    },
  );

  test('newline in a filename remains one path', () {
    const unusual = 'line\nbreak.g.dart';
    file(unusual).writeAsStringSync('one');
    expect(git.changedPaths('HEAD'), contains(unusual));
    final before = git.snapshot();
    file(unusual).deleteSync();
    expect(changedFingerprints(before, git.snapshot()), [unusual]);
  }, skip: Platform.isWindows);

  test('symlink fingerprint does not read the target', () {
    final link = Link('${root.path}/output-link')
      ..createSync('missing-first-target');
    final before = git.snapshot();
    link
      ..deleteSync()
      ..createSync('missing-second-target');
    expect(changedFingerprints(before, git.snapshot()), ['output-link']);
  }, skip: Platform.isWindows);

  test('executable mode drift is detected', () {
    if (Platform.isWindows) return;
    git.text(['config', 'core.filemode', 'true']);
    final before = git.snapshot();
    final result = Process.runSync('chmod', [
      '+x',
      '${root.path}/generated.g.dart',
    ]);
    expect(result.exitCode, 0);
    expect(changedFingerprints(before, git.snapshot()), ['generated.g.dart']);
  });

  test('--list invokes no generator and preserves existing edits', () {
    file('lib/l10n/_fragments/fixture_en.arb').writeAsStringSync('{"a":"b"}');
    file('notes.txt').writeAsStringSync('user edit');
    final before = git.snapshot();
    final index = git.text(['write-tree']);
    ProcessResult execute(String name, List<String> args, String dir) {
      expect(name, 'git', reason: 'list mode must not execute a generator');
      return command(name, args, dir);
    }

    expect(
      cli.run(
        ['--base', 'HEAD', '--list'],
        workingDirectory: root.path,
        execute: execute,
      ),
      0,
    );
    expect(git.snapshot(), before);
    expect(git.text(['write-tree']), index);
  });

  test('real CLI integration reports already-dirty regeneration and preserves notes', () {
    file('lib/l10n/_fragments/fixture_en.arb').writeAsStringSync('{"a":"b"}');
    file('generated.g.dart').writeAsStringSync('old dirty');
    file('notes.txt').writeAsStringSync('user edit');
    ProcessResult execute(String name, List<String> args, String dir) {
      if (name == 'git') return command(name, args, dir);
      file('generated.g.dart').writeAsStringSync('new dirty');
      return ProcessResult(0, 0, '', '');
    }

    expect(
      cli.run(
        ['--base', 'HEAD'],
        workingDirectory: root.path,
        execute: execute,
      ),
      1,
    );
    expect(file('notes.txt').readAsStringSync(), 'user edit');
  });

  test('failing generator exits 2 and does not run its successor', () {
    file('lib/l10n/_fragments/fixture_en.arb').writeAsStringSync('{"a":"b"}');
    var calls = 0;
    ProcessResult execute(String name, List<String> args, String dir) {
      if (name == 'git') return command(name, args, dir);
      calls++;
      return ProcessResult(0, 7, '', 'fixture generator failed');
    }

    expect(
      cli.run(
        ['--base', 'HEAD'],
        workingDirectory: root.path,
        execute: execute,
      ),
      2,
    );
    expect(calls, 1);
  });

  test('failed Git discovery cannot mean no changed files', () {
    ProcessResult execute(String name, List<String> args, String dir) {
      if (args.contains('diff')) {
        return ProcessResult(0, 128, '', 'fixture failure');
      }
      return command(name, args, dir);
    }

    expect(
      cli.run(
        ['--base', 'HEAD', '--list'],
        workingDirectory: root.path,
        execute: execute,
      ),
      2,
    );
  });

  test('missing executable becomes an explicit failure', () {
    ProcessResult execute(String name, List<String> args, String dir) =>
        throw ProcessException(name, args, 'fixture missing executable', 127);
    expect(
      cli.run(['--list'], workingDirectory: root.path, execute: execute),
      2,
    );
  });

  test('invalid base and malformed arguments fail without mutation', () {
    final before = git.snapshot();
    for (final args in [
      ['--base', 'unknown-ref'],
      ['--base'],
      ['--unknown'],
      ['--base', '--help'],
      ['--list', '--list'],
    ]) {
      expect(cli.run(args, workingDirectory: root.path), 2, reason: '$args');
    }
    expect(git.snapshot(), before);
  });
}
