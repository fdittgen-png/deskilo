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

/// #1456 — the onboarding recipes as the record writes them, 2026-09-29:
/// recipe → (trips, the boundaries it acts through, the extra pinned
/// counts). Every recipe also carries the common rows below.
const _recipes = <String, (int, List<String>, Map<String, int>)>{
  'returning_entry': (10, [], {}),
  'first_signup': (2, ['sign_up'], {'waits_email': 1, 'required_confirmations': 1}),
  'invitation_join': (9, ['join'], {'waits_human': 1, 'fields_entered': 0}),
  'owner_first_booking': (14, ['create', 'book'], {}),
  'byo_signin': (11, ['verify', 'sign_in'], {'waits_human': 1}),
  'pending_leave_return': (8, ['request', 'withdraw'], {'back_corrections': 2}),
  'wizard_keyboard_back_edit':
      (5, ['create'], {'back_corrections': 1, 'user_edits': 1}),
};

Map<String, Map<String, int>> get _all => {
      ..._measured,
      for (final MapEntry(key: r, value: (trips, acts, extra)) in _recipes.entries)
        r: {
          'success': 1,
          'trips': trips,
          'route_flashes': 0,
          'loading_episodes': 1,
          'fields_reentered': 0,
          'duplicate_confirmations': 0,
          'entry_frames': 1,
          for (final a in acts) ...{
            '${a}_ack_frames': 1,
            '${a}_ack_semantic_frames': 1,
            '${a}_done_frames': 2,
          },
          ...extra,
          'samples': 9,
          'wall_p50_ms': 500,
          'wall_p95_ms': 1500,
        },
    };

const _conditions = ['sha', 'build_mode', 'host', 'dataset', 'backend'];
const _unheld = [
  'cold_start_device',
  'frame_timing_device',
  'transition_ms_device',
  'api_p95',
  'server_ms',
  'onboarding_frame_timing_device',
  'onboarding_wait_durations',
  'screen_reader_device',
  'onboarding_participants',
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
  _all.forEach((journey, metrics) {
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

  group('#1456 onboarding recipes', () {
    test('every recipe is gated, by name', () {
      final r = run(_record());
      expect(r.code, 0, reason: r.out);
      for (final recipe in _recipes.keys) {
        expect(r.out, contains('$recipe.success 1'), reason: r.out);
        expect(r.out, contains('$recipe.wall_p50_ms'), reason: r.out);
      }
    });

    test('a run that did not assert its authorized result is red, '
        'whatever its numbers', () {
      final r = run(_record(override: {'owner_first_booking.success': 0}));
      expect(r.code, 1, reason: r.out);
      expect(r.out, contains('owner_first_booking.success is 0'));
    });

    test('one extra request on a fixed recipe is red', () {
      final r = run(_record(override: {'returning_entry.trips': 11}));
      expect(r.code, 1, reason: r.out);
      expect(r.out, contains('returning_entry.trips is 11, outside [1, 10]'));
    });

    test('friction the app imposed is red: re-entry, a duplicate '
        'confirmation, a flash, a second loading screen', () {
      for (final metric in const [
        'wizard_keyboard_back_edit.fields_reentered',
        'first_signup.duplicate_confirmations',
        'returning_entry.route_flashes',
      ]) {
        final r = run(_record(override: {metric: 1}));
        expect(r.code, 1, reason: '$metric passed:\n${r.out}');
      }
      final loading = run(_record(override: {'returning_entry.loading_episodes': 2}));
      expect(loading.code, 1, reason: loading.out);
    });

    test('a dwell the app added before completion is red', () {
      final r = run(_record(override: {'first_signup.sign_up_done_frames': 40}));
      expect(r.code, 1, reason: r.out);
      expect(r.out, contains('first_signup.sign_up_done_frames is 40'));
    });

    test('an acknowledgement that was not measured is red, not skipped', () {
      final r = run(_record(dropMetric: 'byo_signin.verify_ack_semantic_frames'));
      expect(r.code, 1, reason: r.out);
      expect(r.out, contains('byo_signin.verify_ack_semantic_frames was NOT MEASURED'));
    });

    test('a wait folded away is red: the e-mail must still be counted', () {
      final r = run(_record(override: {'first_signup.waits_email': 0}));
      expect(r.code, 1, reason: r.out);
    });
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
