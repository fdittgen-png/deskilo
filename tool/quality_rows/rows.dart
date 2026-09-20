// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1446 C1 — one test pass, many rows.
//
// The quality report used to run the whole suite once and then FIVE
// subsets of it again, so that each discipline could have its own row.
// This reads the JSON stream of the one run (`flutter test --file-reporter
// json:…`) and derives the rows from test identities instead.
//
// A row is only as trustworthy as the stream: a run that died half-way,
// loaded nothing, or reported something this reader does not understand
// must not become a green row. So the reader keeps a list of CONTRACT
// violations beside the results, and the CLI fails on any of them.
import 'dart:convert';

/// One expected row of the report and where its evidence comes from.
class Discipline {
  const Discipline({
    required this.name,
    required this.job,
    required this.kind,
    required this.conditional,
    required this.paths,
    required this.evidence,
  });

  final String name;

  /// `code` or `database` — which job writes the row.
  final String job;

  /// `tests`: derived from the JSON stream over [paths]. `step`: its own
  /// workflow step reports the outcome.
  final String kind;

  /// A `skipped` outcome is acceptable — the row depends on an earlier
  /// row of the same job (the database rows after the replay).
  final bool conditional;

  /// Test files or directories, repository-relative.
  final List<String> paths;
  final String evidence;

  bool covers(String path) => paths.any(
      (p) => path == p || (p.endsWith('/') ? path.startsWith(p) : path.startsWith('$p/')));
}

/// `name|job|kind|conditional|paths|evidence`, one per line; `#` comments.
List<Discipline> parseManifest(String text) => [
      for (final raw in const LineSplitter().convert(text))
        if (raw.trim().isNotEmpty && !raw.trim().startsWith('#'))
          _discipline(raw),
    ];

Discipline _discipline(String line) {
  final f = line.split('|');
  if (f.length != 6) {
    throw FormatException('manifest line needs 6 fields: $line');
  }
  return Discipline(
    name: f[0].trim(),
    job: f[1].trim(),
    kind: f[2].trim(),
    conditional: f[3].trim() == 'conditional',
    paths: [for (final p in f[4].split(',')) if (p.trim().isNotEmpty) p.trim()],
    evidence: f[5].trim(),
  );
}

/// What the stream said about one test file.
class SuiteResult {
  SuiteResult(this.path);
  final String path;
  int passed = 0;
  int failed = 0;
  int skipped = 0;
  bool loadError = false;
  int get ran => passed + failed;
}

/// The whole run, as read.
class RunResult {
  RunResult({
    required this.suites,
    required this.completed,
    required this.success,
    required this.violations,
  });

  final Map<String, SuiteResult> suites;

  /// The `done` event arrived — the run finished on its own terms.
  final bool completed;

  /// What `done` said; false when it never arrived.
  final bool success;

  /// Reasons this stream cannot be trusted to make rows.
  final List<String> violations;

  int get testsRun => suites.values.fold(0, (n, s) => n + s.ran);
  int get testsFailed => suites.values.fold(0, (n, s) => n + s.failed);
}

/// Reads the package:test JSON reporter stream (one object per line).
RunResult readRun(String jsonLines) {
  final suites = <String, SuiteResult>{};
  final suitePath = <int, String>{};
  final testSuite = <int, String>{};
  final testName = <int, String>{};
  final violations = <String>[];
  var completed = false;
  var success = false;
  var lines = 0;

  for (final line in const LineSplitter().convert(jsonLines)) {
    if (line.trim().isEmpty) continue;
    lines++;
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      violations.add('line $lines is not JSON: ${line.length > 60 ? '${line.substring(0, 60)}…' : line}');
      continue;
    }
    if (decoded is! Map<String, dynamic>) {
      violations.add('line $lines is not an event object');
      continue;
    }
    final event = decoded;
    switch (event['type']) {
      case 'suite':
        final suite = event['suite'] as Map<String, dynamic>;
        final path = _relative('${suite['path']}');
        suitePath[suite['id'] as int] = path;
        suites.putIfAbsent(path, () => SuiteResult(path));
      case 'testStart':
        final test = event['test'] as Map<String, dynamic>;
        final id = test['id'] as int;
        final path = suitePath[test['suiteID'] as int];
        if (path == null) {
          violations.add('test ${test['name']} started in an unknown suite');
          continue;
        }
        testSuite[id] = path;
        testName[id] = '${test['name']}';
      case 'testDone':
        final id = event['testID'] as int;
        final path = testSuite[id];
        if (path == null) {
          violations.add('test $id finished without having started');
          continue;
        }
        final suite = suites[path]!;
        if (event['hidden'] == true) continue;
        final name = testName[id] ?? '';
        if (name.startsWith('loading ')) {
          if (event['result'] != 'success') suite.loadError = true;
          continue;
        }
        switch (event['result']) {
          case 'success':
            if (event['skipped'] == true) {
              suite.skipped++;
            } else {
              suite.passed++;
            }
          case 'failure' || 'error':
            suite.failed++;
          default:
            violations.add('test "$name" ended with an unknown result "${event['result']}"');
        }
      case 'error':
        // An error outside any test (a bad group, a setUpAll) is a real
        // problem the counts cannot show. Inside a test it is counted by
        // its testDone.
        if (event['testID'] == null) {
          violations.add('error outside a test: ${_firstLine('${event['error']}')}');
        }
      case 'done':
        completed = true;
        success = event['success'] == true;
      case 'start' || 'allSuites' || 'group' || 'print' || 'debug':
        break;
      default:
        violations.add('unknown event type "${event['type']}"');
    }
  }

  if (lines == 0) violations.add('the stream is empty');
  if (!completed) violations.add('the stream never reached "done": the run was cut short');
  if (suites.isEmpty) violations.add('no test suite was loaded');
  return RunResult(
    suites: suites,
    completed: completed,
    success: success,
    violations: violations,
  );
}

/// One report row: `name|outcome|evidence`.
class Row {
  const Row(this.name, this.outcome, this.evidence);
  final String name;
  final String outcome;
  final String evidence;
  String get psv => '$name|$outcome|$evidence';
}

/// The rows of every `tests` discipline of [job], from [run].
///
/// A discipline whose paths ran no test at all is a failure: a moved
/// directory would otherwise report a green row over nothing. A load
/// error in any of its files is a failure. A contract violation makes
/// every row a failure — a row cannot vouch for a stream it cannot read.
List<Row> deriveRows(List<Discipline> manifest, RunResult run, {required String job}) {
  final rows = <Row>[];
  for (final d in manifest) {
    if (d.job != job || d.kind != 'tests') continue;
    final suites = [for (final s in run.suites.values) if (d.covers(s.path)) s];
    final ran = suites.fold(0, (n, s) => n + s.ran);
    final failed = suites.fold(0, (n, s) => n + s.failed);
    final skipped = suites.fold(0, (n, s) => n + s.skipped);
    final loadErrors = suites.where((s) => s.loadError).length;
    final String outcome;
    if (run.violations.isNotEmpty) {
      outcome = 'failure';
    } else if (ran == 0) {
      outcome = 'failure';
    } else if (failed > 0 || loadErrors > 0) {
      outcome = 'failure';
    } else {
      outcome = 'success';
    }
    final counts = ran == 0
        ? 'no test ran under ${d.paths.join(', ')}'
        : '$ran tests${failed > 0 ? ', $failed failed' : ''}'
            '${skipped > 0 ? ', $skipped skipped' : ''}'
            '${loadErrors > 0 ? ', $loadErrors files failed to load' : ''}';
    rows.add(Row(d.name, outcome, '${d.evidence} — $counts'));
  }
  return rows;
}

/// The whole suite as one row: the process exit code is the verdict, the
/// stream must agree with it, and nothing may be unreadable.
Row suiteRow(RunResult run, {required int exitCode}) {
  final ok = exitCode == 0 &&
      run.completed &&
      run.success &&
      run.violations.isEmpty &&
      run.testsRun > 0 &&
      run.testsFailed == 0;
  final detail = [
    '${run.testsRun} tests in ${run.suites.length} files',
    if (run.testsFailed > 0) '${run.testsFailed} failed',
    if (exitCode != 0) 'exit $exitCode',
    ...run.violations.take(2),
  ].join('; ');
  return Row('Tests', ok ? 'success' : 'failure', detail);
}

String _relative(String path) {
  final i = path.indexOf('/test/');
  return i < 0 ? path : path.substring(i + 1);
}

String _firstLine(String s) => const LineSplitter().convert(s).firstOrNull ?? s;
