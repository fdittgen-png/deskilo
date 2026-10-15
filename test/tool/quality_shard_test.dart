// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2600 C2 — the selection is a walk of the tree, not a list in the
// workflow; the shards partition it exactly; coverage merges as a union;
// and the producer commands write what the aggregate reads.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/quality_rows/lcov_merge.dart';
import '../../tool/quality_rows/selection.dart';
import '../../tool/quality_rows/shards.dart';
import '../../tool/test_inventory/inventory.dart';

String _event(Map<String, Object?> e) => jsonEncode(e);

String _stream(List<String> files) {
  final lines = <String>[
    _event({'type': 'start', 'protocolVersion': '0.1.1'}),
  ];
  for (var i = 0; i < files.length; i++) {
    lines
      ..add(
        _event({
          'type': 'suite',
          'suite': {'id': i, 'platform': 'vm', 'path': '/repo/${files[i]}'},
        }),
      )
      ..add(
        _event({
          'type': 'testStart',
          'test': {
            'id': i + 1,
            'name': 'case',
            'suiteID': i,
            'groupIDs': <int>[],
          },
        }),
      )
      ..add(
        _event({
          'type': 'testDone',
          'testID': i + 1,
          'result': 'success',
          'hidden': false,
          'skipped': false,
        }),
      );
  }
  lines.add(_event({'type': 'done', 'success': true}));
  return '${lines.join('\n')}\n';
}

ProcessResult _dart(List<String> args) =>
    Process.runSync('dart', ['run', 'tool/quality_shard.dart', ...args]);

void main() {
  group('selection', () {
    test('the required set is exactly what a bare flutter test selects, and '
        'the root-suite family of the inventory agrees', () {
      final walked = requiredTestFiles();
      final inventory = [
        for (final f in testFiles())
          if (familyOf(f.path.replaceFirst(RegExp(r'^\./'), ''))?.name ==
              'root suite')
            f.path.replaceFirst(RegExp(r'^\./'), ''),
      ]..sort();
      expect(walked, isNotEmpty);
      expect(walked, inventory);
    });

    test('every required file of the real tree is in exactly one shard and '
        'the plan has no problem', () {
      final files = requiredTestFiles();
      final specs = defaultShards(files);
      final plan = ShardPlan(
        candidate: 'c',
        runId: '1',
        runAttempt: '1',
        shards: specs,
      );
      expect(plan.problems(required: files.toSet()), isEmpty);
      expect(specs.fold(0, (n, s) => n + s.files.length), files.length);
      expect(
        specs.every((s) => s.files.isNotEmpty),
        isTrue,
        reason: 'an empty shard is not declared, so it would fail closed',
      );
      expect(unsafeNames(files), isEmpty);
    });

    test('files land in the shard the rule names, including a directory that '
        'does not exist yet', () {
      expect(shardOf('test/lint/a_test.dart'), gateShard);
      expect(shardOf('test/brand_new_root/a_test.dart'), gateShard);
      expect(shardOf('test/helpers/x_test.dart'), gateShard);
      expect(shardOf('test/features/money/a_test.dart'), moneyShard);
      expect(shardOf('test/features/workspace/domain/a_test.dart'), moneyShard);
      expect(shardOf('test/features/money_extra/a_test.dart'), restShard);
      expect(shardOf('test/features/mcp/a_test.dart'), restShard);
      expect(shardOf('test/features/a_test.dart'), restShard);
    });

    test('a walk of a temporary tree finds nested, unclassified and helper '
        'tests and ignores non-tests', () {
      final root = Directory.systemTemp.createTempSync('select');
      addTearDown(() => root.deleteSync(recursive: true));
      for (final p in [
        'test/lint/a_test.dart',
        'test/new_area/deep/b_test.dart',
        'test/helpers/not_a_suite.dart',
        'test/features/money/c_test.dart',
        'lib/ignored_test.dart',
      ]) {
        File('${root.path}/$p')
          ..createSync(recursive: true)
          ..writeAsStringSync('');
      }
      expect(requiredTestFiles(root: root.path), [
        'test/features/money/c_test.dart',
        'test/lint/a_test.dart',
        'test/new_area/deep/b_test.dart',
      ]);
    });

    test('names a shell would reinterpret are refused', () {
      expect(
        unsafeNames([
          'test/a b_test.dart',
          'test/\$x_test.dart',
          'test/ok_test.dart',
        ]),
        ['test/a b_test.dart', 'test/\$x_test.dart'],
      );
    });
  });

  group('lcov merge', () {
    const a =
        'SF:lib/a.dart\nDA:1,1\nDA:2,0\nLF:2\nLH:1\nend_of_record\n'
        'SF:lib/b.dart\nDA:5,2\nLF:1\nLH:1\nend_of_record\n';
    const b =
        'SF:./lib/a.dart\nDA:1,0\nDA:2,3\nDA:3,0\nLF:3\nLH:1\nend_of_record\n';

    test('a line covered by any run is covered; counts add; LF/LH are '
        'recomputed; output is sorted', () {
      expect(
        mergeLcov([b, a]),
        'SF:lib/a.dart\nDA:1,1\nDA:2,3\nDA:3,0\nLF:3\nLH:2\nend_of_record\n'
        'SF:lib/b.dart\nDA:5,2\nLF:1\nLH:1\nend_of_record\n',
      );
      expect(mergeLcov([a, b]), mergeLcov([b, a]));
    });

    test('path spellings are one file', () {
      final m = mergeLcov([
        'SF:/work/repo/lib/a.dart\nDA:1,1\nend_of_record\n',
        'SF:lib\\a.dart\nDA:1,1\nend_of_record\n',
        'SF:./lib/a.dart\nDA:1,1\nend_of_record\n',
      ], root: '/work/repo');
      expect(m, 'SF:lib/a.dart\nDA:1,3\nLF:1\nLH:1\nend_of_record\n');
    });

    test('malformed or empty input is no evidence', () {
      expect(() => mergeLcov([]), throwsA(isA<LcovFormatException>()));
      expect(() => mergeLcov(['']), throwsA(isA<LcovFormatException>()));
      expect(
        () => mergeLcov(['SF:lib/a.dart\nDA:1,1\n']),
        throwsA(isA<LcovFormatException>()),
        reason: 'cut before end_of_record',
      );
      expect(
        () => mergeLcov(['SF:lib/a.dart\nSF:lib/b.dart\nend_of_record\n']),
        throwsA(isA<LcovFormatException>()),
      );
      expect(
        () => mergeLcov(['DA:1,1\nend_of_record\n']),
        throwsA(isA<LcovFormatException>()),
      );
      expect(
        () => mergeLcov(['SF:lib/a.dart\nDA:x,1\nend_of_record\n']),
        throwsA(isA<LcovFormatException>()),
      );
      expect(
        () => mergeLcov([a, 'SF:lib/a.dart\nDA:1,1\n']),
        throwsA(isA<LcovFormatException>()),
      );
    });
  });

  group('the producer commands and the aggregate agree', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('shardcli'));
    tearDown(() => dir.deleteSync(recursive: true));

    const lcov = 'SF:lib/a.dart\nDA:1,1\nLF:1\nLH:1\nend_of_record\n';

    ProcessResult envelope(
      String id, {
      int exit = 0,
      bool lcovFile = true,
      String? stream,
    }) {
      final files = _dart(['select', '--shard', id]).stdout
          .toString()
          .trim()
          .split('\n');
      final d = Directory('${dir.path}/testshard-$id')
        ..createSync(recursive: true);
      File('${d.path}/tests.jsonl').writeAsStringSync(stream ?? _stream(files));
      if (lcovFile) File('${d.path}/lcov.info').writeAsStringSync(lcov);
      return _dart([
        'envelope',
        '--shard',
        id,
        '--exit-code',
        '$exit',
        '--stream',
        '${d.path}/tests.jsonl',
        if (lcovFile) ...['--lcov', '${d.path}/lcov.info'],
        '--candidate',
        'abc',
        '--run-id',
        '9',
        '--run-attempt',
        '1',
        '--profile',
        'p',
        '--sdk',
        's',
        '--out',
        '${d.path}/envelope.json',
      ]);
    }

    ProcessResult plan() => _dart([
      'plan',
      '--candidate',
      'abc',
      '--run-id',
      '9',
      '--run-attempt',
      '1',
      '--out',
      '${dir.path}/plan.json',
    ]);

    ProcessResult rows() => Process.runSync('dart', [
      'run',
      'tool/quality_rows.dart',
      '--plan',
      '${dir.path}/plan.json',
      '--shards',
      dir.path,
      '--manifest',
      '.github/quality-manifest.psv',
      '--out',
      '${dir.path}/tests.psv',
    ]);

    ProcessResult mergeCov() => _dart([
      'merge-lcov',
      '--plan',
      '${dir.path}/plan.json',
      '--shards',
      dir.path,
      '--out',
      '${dir.path}/merged.info',
    ]);

    test('three complete shards: the plan reads them, the rows are green for '
        'the suite, and the LCOV merges', () {
      for (final id in [gateShard, moneyShard, restShard]) {
        final r = envelope(id);
        expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      }
      expect(plan().exitCode, 0);
      final r = rows();
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      expect(
        File('${dir.path}/tests.psv').readAsStringSync(),
        startsWith('Tests|success|'),
      );
      final m = mergeCov();
      expect(m.exitCode, 0, reason: '${m.stdout}${m.stderr}');
      expect(
        File('${dir.path}/merged.info').readAsStringSync(),
        contains('SF:lib/a.dart'),
      );
    });

    test(
      'a shard that never wrote its artifact fails the rows and the merge',
      () {
        envelope(gateShard);
        envelope(moneyShard);
        expect(plan().exitCode, 0);
        expect(rows().exitCode, 1);
        final m = mergeCov();
        expect(m.exitCode, 1);
        expect(m.stderr, contains('[rest]'));
      },
    );

    test('a shard with no LCOV fails the merge although its tests passed', () {
      envelope(gateShard);
      envelope(moneyShard);
      envelope(restShard, lcovFile: false);
      expect(plan().exitCode, 0);
      expect(mergeCov().exitCode, 1);
    });

    test('a stream edited after the envelope was written fails the shard', () {
      for (final id in [gateShard, moneyShard, restShard]) {
        envelope(id);
      }
      File('${dir.path}/testshard-rest/tests.jsonl').writeAsStringSync('\n');
      expect(plan().exitCode, 0);
      expect(rows().exitCode, 1);
    });

    test('a candidate other than the plan\'s fails every shard', () {
      for (final id in [gateShard, moneyShard, restShard]) {
        envelope(id);
      }
      final r = _dart([
        'plan',
        '--candidate',
        'other',
        '--run-id',
        '9',
        '--run-attempt',
        '1',
        '--out',
        '${dir.path}/plan.json',
      ]);
      expect(r.exitCode, 0);
      expect(rows().exitCode, 1);
    });

    test('usage errors exit 2', () {
      expect(_dart([]).exitCode, 2);
      expect(_dart(['select']).exitCode, 2);
      expect(_dart(['envelope', '--shard', 'gate']).exitCode, 2);
      expect(_dart(['select', '--shard', 'nope']).exitCode, 1);
    });
  });
}
