// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1456 — the journey gate's own red controls.
//
// `scripts/perf_gate.sh` turns `tool/bench/journeys_bench_test.dart`'s
// record into a verdict, and the hole it must not have is the one
// `coverage_gate.sh` had (#1446 R2): a check that passes because the
// thing it checks was never measured. So these drive the real script
// over fixtures and assert that EVERY way the evidence can be missing
// is red — a dropped metric, a dropped condition, a dropped "this is
// not measured" declaration, an empty record — alongside the ordinary
// case of a number over budget.
//
// The benchmark itself is not run here: it is a nightly job, not a
// pull-request one (docs/ci/CI_BASELINE.md). What runs here is the
// decision made from its record, which costs milliseconds.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The 2026-09-20 reading at the `large` scale, as the record writes it.
const _measured = <String, Map<String, int>>{
  'reserve_first_usable': {
    'trips': 7,
    'elements': 1737,
    'frames': 17,
    'samples': 9,
    'wall_p50_ms': 376,
    'wall_p95_ms': 1883,
  },
  'reserve_transition': {
    'trips': 1,
    'elements': 2844,
    'frames': 6,
    'samples': 9,
    'wall_p50_ms': 134,
    'wall_p95_ms': 293,
  },
  'booking_commit': {
    'sheet_trips': 0,
    'trips': 4,
    'elements': 1842,
    'sheet_frames': 4,
    'frames': 5,
    'retry_attempts_max': 3,
    'retry_budget_ms': 700,
    'samples': 9,
    'wall_p50_ms': 107,
    'wall_p95_ms': 246,
  },
};

const _conditions = ['sha', 'build_mode', 'host', 'dataset', 'backend'];
const _unheld = [
  'cold_start_device',
  'frame_timing_device',
  'transition_ms_device',
  'api_p95',
  'server_ms',
];

/// A complete record, minus what [dropMetric] / [dropCondition] /
/// [dropUnheld] remove, with [override] applied as `journey.metric`.
String _record({
  String? dropMetric,
  String? dropCondition,
  String? dropUnheld,
  Map<String, int> override = const {},
}) {
  final lines = <String>[
    for (final key in [..._conditions, 'samples'])
      if (key != dropCondition) 'condition|$key|something',
    for (final id in _unheld)
      if (id != dropUnheld) 'unheld|$id|not measured here, and why',
  ];
  _measured.forEach((journey, metrics) {
    metrics.forEach((metric, value) {
      if ('$journey.$metric' == dropMetric) return;
      lines.add('measure|$journey|$metric|'
          '${override['$journey.$metric'] ?? value}');
    });
  });
  return '${lines.join('\n')}\n';
}

late Directory _dir;
late String _script;

({int code, String out}) run(String record) {
  final file = File('${_dir.path}/perf.psv')..writeAsStringSync(record);
  final r = Process.runSync('bash', [_script, file.path]);
  return (code: r.exitCode, out: '${r.stdout}${r.stderr}');
}

void main() {
  setUpAll(() => _script = File('scripts/perf_gate.sh').absolute.path);
  setUp(() => _dir = Directory.systemTemp.createTempSync('perf-gate'));
  tearDown(() => _dir.deleteSync(recursive: true));

  test('the measured record is green, and names every journey', () {
    final r = run(_record());
    expect(r.code, 0, reason: r.out);
    for (final journey in _measured.keys) {
      expect(r.out, contains('$journey.trips'), reason: r.out);
    }
    // The wall clock is printed as what it is, never as a budget.
    expect(r.out, contains('reported, NOT a budget'));
  });

  test('a metric that was not measured is red, not skipped', () {
    // The coverage-gate hole, in this shape: the benchmark died after
    // the first journey, so the rest were never taken.
    for (final metric in const [
      'reserve_first_usable.trips',
      'booking_commit.retry_budget_ms',
      'reserve_transition.elements',
    ]) {
      final r = run(_record(dropMetric: metric));
      expect(r.code, 1, reason: 'missing $metric passed:\n${r.out}');
      expect(r.out, contains('$metric was NOT MEASURED'), reason: r.out);
    }
  });

  test('a wall clock that was not taken is red, and is not a zero reading',
      () {
    final r = run(_record(dropMetric: 'booking_commit.wall_p95_ms'));
    expect(r.code, 1, reason: r.out);
    expect(r.out, contains('booking_commit.wall_p95_ms is missing or zero'));
  });

  test('an injected regression is caught by the trip count', () {
    // What the benchmark's own N+1 control produces: one backend call
    // per seat on the way to the first usable screen. Nothing on screen
    // changes, so only this number moves.
    final r = run(_record(override: {'reserve_first_usable.trips': 807}));
    expect(r.code, 1, reason: r.out);
    expect(r.out, contains('reserve_first_usable.trips is 807'));

    // And the local half of a booking asking the backend anything at all.
    final sheet = run(_record(override: {'booking_commit.sheet_trips': 1}));
    expect(sheet.code, 1, reason: sheet.out);
    expect(sheet.out, contains('booking_commit.sheet_trips is 1'));
  });

  test('a value that is not a number is malformed, not in range', () {
    // Without the numeric check, `[ "n/a" -lt 3 ]` errors and reads as
    // "in range" — an absent measurement wearing a value.
    final r = run(_record().replaceAll(
        'measure|reserve_first_usable|trips|7',
        'measure|reserve_first_usable|trips|n/a'));
    expect(r.code, 1, reason: r.out);
    expect(r.out, contains("reads 'n/a', which is not a number"));
  });

  test('too few samples is not a measurement', () {
    final r = run(_record(override: {'reserve_transition.samples': 1}));
    expect(r.code, 1, reason: r.out);
    expect(r.out, contains('reserve_transition.samples is 1'));
  });

  test('a record that forgets its conditions cannot be compared', () {
    for (final key in _conditions) {
      final r = run(_record(dropCondition: key));
      expect(r.code, 1, reason: 'missing $key passed:\n${r.out}');
      expect(r.out, contains('does not say its $key'), reason: r.out);
    }
  });

  test('dropping an honest "not measured" is a failure of its own', () {
    // The whole point: a record may not quietly stop saying that cold
    // start on a device, frame timing or API p95 were never taken.
    for (final id in _unheld) {
      final r = run(_record(dropUnheld: id));
      expect(r.code, 1, reason: 'dropping $id passed:\n${r.out}');
      expect(r.out, contains("no longer declares '$id' unmeasured"),
          reason: r.out);
    }
  });

  test('an empty or measure-less record is a reporting failure', () {
    expect(run('').code, 1);
    expect(run('').out, contains('is empty'));

    final conditionsOnly = run('condition|sha|abc\n');
    expect(conditionsOnly.code, 1);
    expect(conditionsOnly.out, contains('measured nothing'));

    final missing = Process.runSync('bash', [_script, '${_dir.path}/none.psv']);
    expect(missing.exitCode, 1);
    expect('${missing.stdout}${missing.stderr}', contains('not found'));
  });
}
