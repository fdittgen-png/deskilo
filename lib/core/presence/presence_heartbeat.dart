// SPDX-License-Identifier: MIT
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../trace/trace_logger.dart';
import 'presence_rules.dart';

/// Seam over [Timer.periodic] so tests drive ticks with a fake clock.
typedef PeriodicTimerFactory = Timer Function(
  Duration interval,
  void Function() onTick,
);

Timer _defaultTimerFactory(Duration interval, void Function() onTick) =>
    Timer.periodic(interval, (_) => onTick());

/// Foreground last-seen heartbeat (#223).
///
/// Runs only while BOTH hold: the user is signed in and the app is
/// foregrounded (resumed). On every transition into that state it fires
/// [touch] immediately, then every [PresenceRules.heartbeatInterval];
/// leaving the state cancels the timer. Touch failures are logged to the
/// trace and never surfaced — presence is strictly best-effort.
///
/// Pure `dart:async` + injected callbacks: no Supabase, no Riverpod, no
/// platform channels (and per the epic's hard rule, no third-party
/// presence service). Wiring lives in presence_providers.dart.
class PresenceHeartbeat {
  PresenceHeartbeat({
    required Future<void> Function() touch,
    PeriodicTimerFactory timerFactory = _defaultTimerFactory,
  })  : _touch = touch,
        _timerFactory = timerFactory;

  final Future<void> Function() _touch;
  final PeriodicTimerFactory _timerFactory;

  bool _signedIn = false;
  // Unknown lifecycle (before the first transition) counts as foreground:
  // the app has just been launched into the foreground.
  bool _foreground = true;
  Timer? _timer;

  /// True while the periodic timer is armed (signed in + foregrounded).
  bool get isRunning => _timer != null;

  void setSignedIn(bool signedIn) {
    _signedIn = signedIn;
    _recompute();
  }

  void setForeground(bool foreground) {
    _foreground = foreground;
    _recompute();
  }

  /// Cancels the timer for good; the owner must not reuse the instance.
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  void _recompute() {
    final shouldRun = _signedIn && _foreground;
    if (shouldRun && _timer == null) {
      unawaited(_touchSafely());
      _timer = _timerFactory(
        PresenceRules.heartbeatInterval,
        () => unawaited(_touchSafely()),
      );
    } else if (!shouldRun && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  Future<void> _touchSafely() async {
    try {
      await _touch();
    } catch (e, st) {
      debugPrint('presence heartbeat failed: $e\n$st');
      // Best-effort by design: the next tick simply retries.
      TraceLogger.instance.warn('presence', 'last-seen heartbeat failed',
          error: e, stackTrace: st);
    }
  }
}
