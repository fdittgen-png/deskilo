// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3755 -- the workflow audit says what is new. `scripts/workflow_audit_summary.py`
// compares the scanner's findings with the stored baseline: the same counts are
// unchanged, a count above its baseline is new, below it resolved, a baseline of
// another scanner version is shown and not compared, and a missing baseline says
// so. The committed baseline is valid and names the pinned scanner.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _script = 'scripts/workflow_audit_summary.py';

Map<String, Object?> _finding(
  String rule,
  String severity,
  String confidence,
) => {
  'ident': rule,
  'determinations': {'severity': severity, 'confidence': confidence},
};

/// Runs the summary over [findings] and [baseline] and returns the report text.
String _summary(
  Directory dir,
  List<Map<String, Object?>> findings, {
  Map<String, Object?>? baseline,
  String scanner = 'zizmor 9.9.9',
  List<String> flags = const [],
}) {
  File('${dir.path}/findings.json').writeAsStringSync(jsonEncode(findings));
  File('${dir.path}/version.txt').writeAsStringSync('$scanner\n');
  File('${dir.path}/revision.txt').writeAsStringSync('abc123\n');
  File('${dir.path}/working-tree.txt').writeAsStringSync('');
  final baselineFile = File('${dir.path}/baseline.json');
  if (baseline != null) baselineFile.writeAsStringSync(jsonEncode(baseline));
  final run = Process.runSync('python3', [
    '-I',
    _script,
    dir.path,
    baselineFile.path,
    ...flags,
  ]);
  expect(run.exitCode, 0, reason: '${run.stderr}');
  return File('${dir.path}/summary.md').readAsStringSync();
}

Map<String, Object?> _baseline(
  List<(String, String, String, int)> counts, {
  String scanner = 'zizmor 9.9.9',
}) => {
  'scanner': scanner,
  'revision': 'old456',
  'counts': [
    for (final (r, s, c, n) in counts)
      {'rule': r, 'severity': s, 'confidence': c, 'count': n},
  ],
};

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('audit-summary-'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('the same findings as the baseline: no new, none resolved', () {
    final text = _summary(dir, [
      _finding('artipacked', 'Medium', 'Low'),
      _finding('artipacked', 'Medium', 'Low'),
    ], baseline: _baseline([('artipacked', 'Medium', 'Low', 2)]));
    expect(text, contains('**New findings: 0**, resolved: 0'));
    expect(text, contains('| 2 | 2 | = |'));
  });

  test('a finding above its baseline is new, one below it is resolved, and a '
      'rule that appears is new', () {
    final text = _summary(
      dir,
      [
        _finding('artipacked', 'Medium', 'Low'),
        _finding('artipacked', 'Medium', 'Low'),
        _finding('artipacked', 'Medium', 'Low'),
        _finding('excessive-permissions', 'High', 'High'),
      ],
      baseline: _baseline([
        ('artipacked', 'Medium', 'Low', 2),
        ('github-env', 'High', 'Low', 1),
      ]),
    );
    expect(text, contains('**New findings: 2**, resolved: 1'));
    expect(text, contains('artipacked Medium/Low +1'));
    expect(text, contains('excessive-permissions High/High +1'));
    expect(text, contains('| 0 | 1 | resolved 1 |'));
    expect(text, contains('findings do not block merging'));
  });

  test('a baseline of another scanner is shown, not compared; no baseline '
      'says so', () {
    final other = _summary(
      dir,
      [_finding('artipacked', 'Medium', 'Low')],
      baseline: _baseline([
        ('artipacked', 'Medium', 'Low', 0),
      ], scanner: 'zizmor 1.0.0'),
    );
    expect(other, contains('no difference is computed'));
    expect(other, isNot(contains('**New findings')));
    final none = Directory.systemTemp.createTempSync('audit-none-');
    addTearDown(() => none.deleteSync(recursive: true));
    expect(
      _summary(none, [_finding('artipacked', 'Medium', 'Low')]),
      contains('Baseline: none stored'),
    );
  });

  test('--write-baseline records the current counts, and the next run reads '
      'them back as unchanged', () {
    final findings = [
      _finding('self-repository', 'Low', 'High'),
      _finding('self-repository', 'Low', 'High'),
    ];
    _summary(dir, findings, flags: const ['--write-baseline']);
    final stored =
        jsonDecode(File('${dir.path}/baseline.json').readAsStringSync()) as Map;
    expect(stored['scanner'], 'zizmor 9.9.9');
    expect((stored['counts'] as List).single, {
      'rule': 'self-repository',
      'severity': 'Low',
      'confidence': 'High',
      'count': 2,
    });
    expect(
      _summary(dir, findings),
      contains('**New findings: 0**, resolved: 0'),
    );
  });

  test('the committed baseline is valid and names the pinned scanner', () {
    final baseline = jsonDecode(
      File('.github/workflow-audit-baseline.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final installer = File('scripts/install_zizmor.sh').readAsStringSync();
    final pinned = RegExp(
      r'^version=(\S+)',
      multiLine: true,
    ).firstMatch(installer)![1];
    expect(baseline['scanner'], 'zizmor $pinned');
    expect(baseline['revision'], matches(RegExp(r'^[0-9a-f]{40}$')));
    final counts = (baseline['counts']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(counts, isNotEmpty);
    for (final c in counts) {
      expect(
        c['count'],
        isA<int>().having((n) => n, 'positive', greaterThan(0)),
      );
    }
  });
}
