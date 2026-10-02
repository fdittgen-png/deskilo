// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1864 B — where the one suite run spends its time, read from the JSON
// stream that run already writes (report/tests.jsonl). No second run.
//
// The stream's `time` is milliseconds since the run started, and files
// run in parallel, so per-file durations overlap: their sum is NOT the
// run's length. This reports each file's load (compiling and starting
// it, the hidden "loading" test) apart from its test bodies, the run's
// own wall clock, and the overlap factor — never a sum dressed as a
// total.
//
// It also writes a bounded copy of the stream with only the timing
// events and their identities: no print output, no error text, no
// stack trace, so nothing a test logged travels with the artefact.

import 'dart:convert';

/// One test file's time in a run.
class FileTiming {
  FileTiming(this.path);

  final String path;
  int? loadStart;
  int? loadEnd;
  int body = 0;
  int tests = 0;
  int failed = 0;
  int skipped = 0;
  int? firstEvent;
  int? lastEvent;

  int get load =>
      loadStart == null || loadEnd == null ? 0 : loadEnd! - loadStart!;

  /// From the file's first event to its last: what it occupied a worker.
  int get span =>
      firstEvent == null || lastEvent == null ? 0 : lastEvent! - firstEvent!;
}

/// How the run ended, from the stream alone.
enum RunEnd { passed, failed, truncated, empty }

/// The timings of one run.
class RunTimings {
  RunTimings({
    required this.files,
    required this.end,
    required this.wall,
    required this.problems,
    required this.kept,
  });

  final List<FileTiming> files;
  final RunEnd end;

  /// The run's own length: the `done` event's time, or the last event
  /// seen when the stream was cut short.
  final int wall;
  final List<String> problems;

  /// The bounded event lines (identities and times only).
  final List<String> kept;

  int get loadTotal => files.fold(0, (n, f) => n + f.load);
  int get bodyTotal => files.fold(0, (n, f) => n + f.body);
  int get spanTotal => files.fold(0, (n, f) => n + f.span);

  /// How many files ran at once on average: the summed spans over the
  /// wall clock. Above 1, adding the per-file times would overstate it.
  double get overlap => wall == 0 ? 0 : spanTotal / wall;
}

String _relative(String path) {
  final i = path.indexOf('/test/');
  if (i >= 0) return path.substring(i + 1);
  for (final root in ['integration_test/', 'tool/', 'packages/']) {
    final j = path.indexOf('/$root');
    if (j >= 0) return path.substring(j + 1);
  }
  return path;
}

/// Reads a `flutter test --file-reporter json:` stream.
RunTimings readTimings(String jsonLines) {
  final files = <String, FileTiming>{};
  final suitePath = <int, String>{};
  final testFile = <int, String>{};
  final testStart = <int, int>{};
  final loading = <int>{};
  final problems = <String>[];
  final kept = <String>[];
  var done = false;
  var success = false;
  var wall = 0;
  var lineNo = 0;

  for (final line in const LineSplitter().convert(jsonLines)) {
    if (line.trim().isEmpty) continue;
    lineNo++;
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      problems.add('line $lineNo is not JSON');
      continue;
    }
    if (decoded is! Map<String, dynamic>) {
      problems.add('line $lineNo is not an event object');
      continue;
    }
    final e = decoded;
    final time = e['time'] is int ? e['time'] as int : null;
    if (time != null && time > wall) wall = time;
    FileTiming? touch(String? path) {
      if (path == null || time == null) return null;
      final f = files.putIfAbsent(path, () => FileTiming(path));
      f.firstEvent ??= time;
      if (f.lastEvent == null || time > f.lastEvent!) f.lastEvent = time;
      return f;
    }

    switch (e['type']) {
      case 'suite':
        final suite = e['suite'] as Map<String, dynamic>;
        final path = _relative('${suite['path']}');
        suitePath[suite['id'] as int] = path;
        touch(path);
        kept.add(
          jsonEncode({
            'type': 'suite',
            'id': suite['id'],
            'path': path,
            'time': time,
          }),
        );
      case 'testStart':
        final test = e['test'] as Map<String, dynamic>;
        final id = test['id'] as int;
        final path = suitePath[test['suiteID']];
        if (path == null) {
          problems.add('a test started in an unknown suite');
          continue;
        }
        testFile[id] = path;
        if (time != null) testStart[id] = time;
        final name = '${test['name']}';
        // The runner reports compiling and starting a file as a hidden
        // test named "loading <path>".
        if (name.startsWith('loading ')) loading.add(id);
        final f = touch(path);
        if (loading.contains(id)) f?.loadStart = time;
        kept.add(
          jsonEncode({
            'type': 'testStart',
            'id': id,
            'suite': test['suiteID'],
            'name': name,
            'time': time,
          }),
        );
      case 'testDone':
        final id = e['testID'] as int;
        final path = testFile[id];
        if (path == null) {
          problems.add('a test finished that never started');
          continue;
        }
        final f = touch(path)!;
        final start = testStart[id];
        if (loading.contains(id)) {
          f.loadEnd = time;
        } else if (e['hidden'] != true) {
          if (start != null && time != null) f.body += time - start;
          f.tests++;
          if (e['skipped'] == true) f.skipped++;
          if (e['result'] != 'success') f.failed++;
        }
        kept.add(
          jsonEncode({
            'type': 'testDone',
            'id': id,
            'result': e['result'],
            'skipped': e['skipped'],
            'hidden': e['hidden'],
            'time': time,
          }),
        );
      case 'done':
        done = true;
        success = e['success'] == true;
        kept.add(
          jsonEncode({'type': 'done', 'success': e['success'], 'time': time}),
        );
      default:
        // print, error, group, start, allSuites, debug: identities only
        // for start; text-bearing events are not kept.
        if (e['type'] == 'start' || e['type'] == 'allSuites') {
          kept.add(jsonEncode({'type': e['type'], 'time': time}));
        }
    }
  }

  final real = files.values.where((f) => f.tests > 0 || f.load > 0).toList();
  final end = real.isEmpty
      ? RunEnd.empty
      : !done
      ? RunEnd.truncated
      : success && real.every((f) => f.failed == 0)
      ? RunEnd.passed
      : RunEnd.failed;
  if (!done) {
    problems.add('the stream never reached "done": the run was cut short');
  }
  return RunTimings(
    files: real,
    end: end,
    wall: wall,
    problems: problems,
    kept: kept,
  );
}

String _s(int ms) => (ms / 1000).toStringAsFixed(1);

/// The hotspot view: what this run is, how it ended, and the slowest
/// files by load and by test bodies.
String renderTimings(
  RunTimings run, {
  required String candidate,
  required String profile,
  required String runtime,
  int top = 15,
}) {
  final b = StringBuffer()
    ..writeln('# Test timings')
    ..writeln()
    ..writeln(
      '| candidate | profile | runtime | ended | wall clock | files | overlap |',
    )
    ..writeln('|---|---|---|---|---:|---:|---:|')
    ..writeln(
      '| `$candidate` | $profile | $runtime | ${run.end.name} | '
      '${_s(run.wall)} s | ${run.files.length} | '
      '${run.overlap.toStringAsFixed(1)}× |',
    )
    ..writeln()
    ..writeln(
      'Per-file times overlap: files run in parallel, so they add up '
      'to about ${run.overlap.toStringAsFixed(1)}× the wall clock. Read '
      'them as shares, not as a total. One run on one runner; compare '
      'only like with like (same profile, runtime and runner class).',
    )
    ..writeln()
    ..writeln(
      'Summed over files: load (compile and start) '
      '${_s(run.loadTotal)} s, test bodies ${_s(run.bodyTotal)} s.',
    );
  if (run.problems.isNotEmpty) {
    b
      ..writeln()
      ..writeln('**The stream is incomplete:** ${run.problems.join('; ')}.');
  }
  void table(String title, int Function(FileTiming) key) {
    final rows = [...run.files]..sort((a, c) => key(c).compareTo(key(a)));
    b
      ..writeln()
      ..writeln('## $title')
      ..writeln()
      ..writeln('| file | load s | bodies s | tests | failed | skipped |')
      ..writeln('|---|---:|---:|---:|---:|---:|');
    for (final f in rows.take(top)) {
      b.writeln(
        '| `${f.path}` | ${_s(f.load)} | ${_s(f.body)} | ${f.tests} | '
        '${f.failed} | ${f.skipped} |',
      );
    }
  }

  table('Slowest to load', (f) => f.load);
  table('Slowest test bodies', (f) => f.body);
  return b.toString();
}
