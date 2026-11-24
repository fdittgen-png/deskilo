// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4416 — sends the errors the trace records to the installation, as the
// person allowed (the Privacy switch, on by default). Best effort by design:
// one report at a time, at most the installation's hourly budget, and a report
// that cannot go is dropped — never queued, never sent again, never a loop.
// What fails here is written as a warning, which is never reported itself.
import 'dart:async';

import 'trace_logger.dart';
import 'trace_report.dart';

/// The trace area this reporter writes its own (warning) lines under.
const traceReportArea = 'trace-report';

class TraceReporter {
  TraceReporter({
    required Stream<TraceEntry> entries,
    required this.report,
    required this.sink,
    required this.perHour,
    required this.now,
    required this.warn,
  }) {
    _subscription = entries.listen(_onEntry);
  }

  /// The report for an entry, or null when it is not to be sent.
  final Future<TraceReport?> Function(TraceEntry entry) report;
  final TraceReportSink sink;

  /// The installation's hourly budget for this person (0 sends nothing).
  final int Function() perHour;
  final DateTime Function() now;

  /// Where a dropped report is noted: a warning, never an error.
  final void Function(String message, Object error, StackTrace stack) warn;

  late final StreamSubscription<TraceEntry> _subscription;
  final List<DateTime> _sent = [];
  bool _busy = false;

  /// Completes when the report in flight, if any, has settled (for tests).
  Future<void> get idle => _inFlight ?? Future.value();
  Future<void>? _inFlight;

  void _onEntry(TraceEntry entry) {
    // A warning (this reporter's own included) is never sent, and an error
    // that arrives while one is on its way is dropped, not queued.
    if (entry.level != TraceLevel.error || _busy) return;
    final at = now();
    _sent.removeWhere((t) => at.difference(t) >= const Duration(hours: 1));
    if (_sent.length >= perHour()) return;
    _busy = true;
    _inFlight = _send(entry, at).whenComplete(() => _busy = false);
  }

  Future<void> _send(TraceEntry entry, DateTime at) async {
    try {
      final built = await report(entry);
      if (built == null) return;
      _sent.add(at);
      await sink.submit(built);
    } on Object catch (e, st) {
      // A report that cannot go is dropped: noted as a warning, never sent.
      warn('an error report was not sent', e, st);
    }
  }

  Future<void> dispose() => _subscription.cancel();
}
