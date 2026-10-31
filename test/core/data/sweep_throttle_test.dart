// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3099 (PERF-2) — the timeout sweep before every events read ran on every
// reload of every client. Counted: reads within the workspace's interval
// share one sweep; a read past it sweeps again; a failed sweep is retried
// by the next read; concurrent reads share the one in flight.
import 'dart:async';

import 'package:deskilo/core/data/sweep_throttle.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:flutter_test/flutter_test.dart';

class _Clock implements Clock {
  DateTime instant = DateTime.utc(2026, 10, 31, 9);
  @override
  DateTime now() => instant;
}

void main() {
  late _Clock clock;
  late SweepThrottle throttle;
  var sweeps = 0;
  Future<void> sweep() async => sweeps++;

  setUp(() {
    clock = _Clock();
    sweeps = 0;
    throttle = SweepThrottle(
      clock: clock,
      interval: () => const Duration(seconds: 60),
    );
  });

  test('5 reads within the interval: one sweep', () async {
    for (var i = 0; i < 5; i++) {
      clock.instant = clock.instant.add(const Duration(seconds: 10));
      await throttle.run('ws-a', sweep);
    }
    expect(sweeps, 1);
  });

  test('a read past the interval sweeps again; workspaces are apart', () async {
    await throttle.run('ws-a', sweep);
    await throttle.run('ws-b', sweep);
    clock.instant = clock.instant.add(const Duration(seconds: 60));
    await throttle.run('ws-a', sweep);
    expect(sweeps, 3);
  });

  test('a failed sweep is retried by the next read', () async {
    await expectLater(
      throttle.run('ws-a', () async => throw StateError('offline (test)')),
      throwsStateError,
    );
    await throttle.run('ws-a', sweep);
    expect(sweeps, 1);
  });

  test('concurrent reads share the sweep in flight', () async {
    final gate = Completer<void>();
    var started = 0;
    Future<void> slow() async {
      started++;
      await gate.future;
    }

    final a = throttle.run('ws-a', slow);
    final b = throttle.run('ws-a', slow);
    gate.complete();
    await Future.wait([a, b]);
    expect(started, 1);
  });

  test('an interval of 0 sweeps before every read', () async {
    throttle = SweepThrottle(clock: clock, interval: () => Duration.zero);
    await throttle.run('ws-a', sweep);
    await throttle.run('ws-a', sweep);
    expect(sweeps, 2);
  });
}
