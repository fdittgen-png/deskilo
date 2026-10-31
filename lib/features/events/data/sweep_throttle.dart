// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3099 (PERF-2) — the timeout sweep (`sweep_pending_events`) ran before
// every events read, on every client, on every reload. It now runs at most
// once per workspace per `messaging.inbox_sweep_interval_seconds`; reads in
// between see the feed as of the last sweep. #1909's coalescing stays:
// concurrent reads share the sweep in flight.
import '../../../core/time/clock.dart';

class SweepThrottle {
  SweepThrottle({required this.clock, required this.interval});

  final Clock clock;
  final Duration Function() interval;

  final _inFlight = <String, Future<void>>{};
  final _lastDone = <String, DateTime>{};

  /// Runs [sweep] for [workspaceId] unless one finished less than
  /// [interval] ago. A failed sweep records nothing, so the next read
  /// retries it.
  Future<void> run(String workspaceId, Future<void> Function() sweep) {
    final running = _inFlight[workspaceId];
    if (running != null) return running;
    final last = _lastDone[workspaceId];
    if (last != null && clock.now().difference(last) < interval()) {
      return Future.value();
    }
    final started = () async {
      try {
        await sweep();
        _lastDone[workspaceId] = clock.now();
      } finally {
        _inFlight.remove(workspaceId)?.ignore(); // that is this future: done
      }
    }();
    _inFlight[workspaceId] = started;
    return started;
  }
}
