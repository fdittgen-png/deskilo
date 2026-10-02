// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1864 B — the timing view reads the one run's stream honestly: load
// apart from bodies, overlap instead of a false sum, and a cut-short,
// failed or empty run named as such. Its bounded copy keeps no text a
// test printed or threw.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/test_timings/timings.dart';

String _stream(List<Map<String, Object?>> events) =>
    events.map(jsonEncode).join('\n');

Map<String, Object?> _suite(int id, String path, int time) => {
  'type': 'suite',
  'suite': {'id': id, 'platform': 'vm', 'path': '/repo/$path'},
  'time': time,
};

Map<String, Object?> _start(int id, int suite, String name, int time) => {
  'type': 'testStart',
  'test': {'id': id, 'name': name, 'suiteID': suite, 'groupIDs': <int>[]},
  'time': time,
};

Map<String, Object?> _done(
  int id,
  int time, {
  String result = 'success',
  bool hidden = false,
  bool skipped = false,
}) => {
  'type': 'testDone',
  'testID': id,
  'result': result,
  'hidden': hidden,
  'skipped': skipped,
  'time': time,
};

/// Two files in parallel: a loads 0–400 then runs 400–1000; b loads
/// 100–300 then runs 300–900 and 900–950.
List<Map<String, Object?>> _twoFiles({
  bool done = true,
  String bResult = 'success',
}) => [
  {'type': 'start', 'time': 0},
  _suite(0, 'test/a_test.dart', 0),
  _suite(1, 'test/b_test.dart', 100),
  _start(1, 0, 'loading /repo/test/a_test.dart', 0),
  _start(2, 1, 'loading /repo/test/b_test.dart', 100),
  _done(2, 300, hidden: true),
  _start(3, 1, 'b one', 300),
  _done(1, 400, hidden: true),
  _start(4, 0, 'a one', 400),
  {'type': 'print', 'testID': 3, 'message': 'SECRET token=abc', 'time': 500},
  {
    'type': 'error',
    'testID': 3,
    'error': 'boom at customer@example.com',
    'stackTrace': 'x',
    'time': 600,
  },
  _done(3, 900, result: bResult),
  _start(5, 1, 'b two', 900),
  _done(5, 950, skipped: true),
  _done(4, 1000),
  // A hidden tearDownAll is setup cost, not a test body.
  _start(6, 0, '(tearDownAll)', 950),
  _done(6, 1000, hidden: true),
  if (done) {'type': 'done', 'success': bResult == 'success', 'time': 1000},
];

void main() {
  test('load and bodies apart, and overlap instead of a sum', () {
    final run = readTimings(_stream(_twoFiles()));
    expect(run.end, RunEnd.passed);
    expect(run.wall, 1000);
    final a = run.files.singleWhere((f) => f.path == 'test/a_test.dart');
    final b = run.files.singleWhere((f) => f.path == 'test/b_test.dart');
    expect((a.load, a.body, a.tests), (400, 600, 1));
    expect((b.load, b.body, b.tests, b.skipped), (200, 650, 2, 1));
    // Spans 1000 + 850 over a wall of 1000: the files overlapped.
    expect(run.overlap, closeTo(1.85, 0.001));
    expect(run.problems, isEmpty);
  });

  test('a failed test makes the run failed', () {
    expect(
      readTimings(_stream(_twoFiles(bResult: 'error'))).end,
      RunEnd.failed,
    );
  });

  test('a stream without done is truncated, and says so', () {
    final run = readTimings(_stream(_twoFiles(done: false)));
    expect(run.end, RunEnd.truncated);
    expect(run.problems.single, contains('cut short'));
    expect(
      renderTimings(run, candidate: 'c', profile: 'p', runtime: 'r'),
      contains('The stream is incomplete'),
    );
  });

  test('no tests at all is empty, never passed', () {
    expect(readTimings('').end, RunEnd.empty);
    expect(
      readTimings(
        _stream([
          {'type': 'done', 'success': true, 'time': 5},
        ]),
      ).end,
      RunEnd.empty,
    );
  });

  test('a line that is not JSON is a problem, not a crash', () {
    final run = readTimings('${_stream(_twoFiles())}\n{oops');
    expect(run.problems, ['line 19 is not JSON']);
  });

  test('the bounded copy keeps identities and times, never text', () {
    final kept = readTimings(_stream(_twoFiles())).kept.join('\n');
    expect(kept, isNot(contains('SECRET')));
    expect(kept, isNot(contains('customer@example.com')));
    expect(kept, contains('"path":"test/a_test.dart"'));
    expect(kept, contains('"type":"done"'));
  });

  test('the view names the candidate, profile and runtime', () {
    final md = renderTimings(
      readTimings(_stream(_twoFiles())),
      candidate: 'abc123',
      profile: 'quality',
      runtime: '3.47.5',
    );
    expect(
      md,
      contains('`abc123` | quality | 3.47.5 | passed | 1.0 s | 2 | 1.9× |'),
    );
    expect(md, contains('| `test/a_test.dart` | 0.4 | 0.6 | 1 | 0 | 0 |'));
  });
}
