// SPDX-License-Identifier: 0BSD
//
// Start/pause/resume semantics of the foreground last-seen heartbeat
// (#223), driven through an injected timer factory — no real clock.
import 'dart:async';

import 'package:deskilo/core/presence/presence_heartbeat.dart';
import 'package:deskilo/core/presence/presence_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hand-cranked [Timer]: the test fires ticks itself.
class _FakeTimer implements Timer {
  _FakeTimer(this.onTick);

  final void Function() onTick;
  bool _active = true;

  void fire() {
    if (_active) onTick();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

class _Harness {
  _Harness({this.failing = false}) {
    heartbeat = PresenceHeartbeat(
      touch: () async {
        touches += 1;
        if (failing) throw StateError('touch failing (test)');
      },
      timerFactory: (interval, onTick) {
        intervals.add(interval);
        final timer = _FakeTimer(onTick);
        timers.add(timer);
        return timer;
      },
    );
  }

  final bool failing;
  late final PresenceHeartbeat heartbeat;
  int touches = 0;
  final List<Duration> intervals = [];
  final List<_FakeTimer> timers = [];

  _FakeTimer get lastTimer => timers.last;
}

void main() {
  test('signed in + foregrounded: touches immediately and arms the '
      'pinned interval', () async {
    final h = _Harness();
    h.heartbeat.setSignedIn(true);
    await Future<void>.delayed(Duration.zero);

    expect(h.touches, 1);
    expect(h.heartbeat.isRunning, isTrue);
    expect(h.intervals, [PresenceRules.heartbeatInterval]);
  });

  test('each tick touches again', () async {
    final h = _Harness();
    h.heartbeat.setSignedIn(true);
    h.lastTimer.fire();
    h.lastTimer.fire();
    await Future<void>.delayed(Duration.zero);

    expect(h.touches, 3);
  });

  test('backgrounding cancels the timer; no further touches', () async {
    final h = _Harness();
    h.heartbeat.setSignedIn(true);
    h.heartbeat.setForeground(false);
    await Future<void>.delayed(Duration.zero);

    expect(h.heartbeat.isRunning, isFalse);
    expect(h.lastTimer.isActive, isFalse);
    expect(h.touches, 1);
  });

  test('resuming touches immediately again and re-arms a fresh timer',
      () async {
    final h = _Harness();
    h.heartbeat.setSignedIn(true);
    h.heartbeat.setForeground(false);
    h.heartbeat.setForeground(true);
    await Future<void>.delayed(Duration.zero);

    expect(h.touches, 2);
    expect(h.timers, hasLength(2));
    expect(h.heartbeat.isRunning, isTrue);
  });

  test('signing out stops the heartbeat; foreground flips alone never '
      'restart it', () async {
    final h = _Harness();
    h.heartbeat.setSignedIn(true);
    h.heartbeat.setSignedIn(false);
    h.heartbeat.setForeground(false);
    h.heartbeat.setForeground(true);
    await Future<void>.delayed(Duration.zero);

    expect(h.heartbeat.isRunning, isFalse);
    expect(h.touches, 1);
  });

  test('signed out from the start: backgrounded/foregrounded, it never '
      'touches at all', () async {
    final h = _Harness();
    h.heartbeat.setForeground(false);
    h.heartbeat.setForeground(true);
    await Future<void>.delayed(Duration.zero);

    expect(h.touches, 0);
    expect(h.timers, isEmpty);
  });

  test('touch failures are swallowed and the timer keeps running',
      () async {
    final h = _Harness(failing: true);
    h.heartbeat.setSignedIn(true);
    h.lastTimer.fire();
    await Future<void>.delayed(Duration.zero);

    expect(h.touches, 2);
    expect(h.heartbeat.isRunning, isTrue);
  });

  test('dispose cancels the timer', () async {
    final h = _Harness();
    h.heartbeat.setSignedIn(true);
    h.heartbeat.dispose();

    expect(h.heartbeat.isRunning, isFalse);
    expect(h.lastTimer.isActive, isFalse);
  });
}
