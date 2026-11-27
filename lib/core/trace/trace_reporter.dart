// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4416 — sends the errors the trace records to the installation, as the
// person allowed (the Privacy switch, on by default). Best effort by design,
// and bounded everywhere: one report at a time, a short waiting line, at most
// the installation's hourly budget, the same fault once an hour. A report that
// cannot go is dropped — never sent again, never a loop — and every drop is
// counted and said in the local trace, so an empty list at the installation is
// never read as "nothing failed". What this reporter writes itself is filed
// under its own area, which is never reported whatever its level.
import 'dart:async';
import 'dart:collection';

import 'trace_logger.dart';
import 'trace_report.dart';

/// The trace area this reporter writes its own lines under.
const traceReportArea = 'trace-report';

/// How many errors may wait while one report is on its way.
const _queueCap = 8;

/// Why a report did not reach the installation's table.
enum _Drop {
  /// The same fault was already reported within the hour.
  repeated,

  /// The hourly budget is used up.
  overBudget,

  /// Too many errors arrived while one report was on its way.
  queueFull,

  /// The installation could not be reached, or refused the caller.
  notSent,

  /// The installation answered, and did not store it.
  notStored,
}

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

  /// Where a dropped report is noted, in the local trace under
  /// [traceReportArea]: never reported itself.
  final void Function(String message, [Object? error, StackTrace? stack]) warn;

  late final StreamSubscription<TraceEntry> _subscription;
  final Queue<TraceEntry> _waiting = Queue();

  /// When each report of the running hour was handed to the installation.
  final List<DateTime> _sent = [];

  /// The faults of the running hour, by what tells two of them apart.
  final Map<String, DateTime> _seen = {};

  /// How many reports were dropped, by reason. A count, never a report.
  final Map<_Drop, int> _dropped = {};
  bool _busy = false;
  bool _disposed = false;

  /// Completes when the reports waiting, if any, have settled (for tests).
  Future<void> get idle => _inFlight ?? Future.value();
  Future<void>? _inFlight;

  void _onEntry(TraceEntry entry) {
    // Only an error is sent, and never one of this reporter's own lines: a
    // failing door must not report its own failure through the same door.
    if (_disposed ||
        entry.level != TraceLevel.error ||
        entry.area == traceReportArea) {
      return;
    }
    final at = now();
    _forgetBefore(at);
    final fault = _faultOf(entry);
    if (_seen.containsKey(fault)) return _drop(_Drop.repeated);
    if (_sent.length + _waiting.length >= perHour()) {
      return _drop(_Drop.overBudget);
    }
    if (_waiting.length >= _queueCap) {
      return _drop(_Drop.queueFull);
    }
    _seen[fault] = at;
    _waiting.add(entry);
    if (!_busy) {
      _busy = true;
      _inFlight = _drain().whenComplete(() => _busy = false);
    }
  }

  Future<void> _drain() async {
    final before = Map.of(_dropped);
    while (_waiting.isNotEmpty && !_disposed) {
      await _send(_waiting.removeFirst());
    }
    _noteDrops(before);
  }

  Future<void> _send(TraceEntry entry) async {
    try {
      final built = await report(entry);
      // Switched off, signed out or another account while the report was
      // built: what was allowed then is not allowed now.
      if (built == null || _disposed) return;
      _sent.add(now());
      final answer = await sink.submit(built);
      if (answer != TraceReportAnswer.stored) {
        _count(_Drop.notStored);
        warn('an error report was not stored: ${answer.name}');
      }
    } on Object catch (e, st) {
      // A report that cannot go is dropped: noted locally, never sent again.
      _count(_Drop.notSent);
      warn('an error report was not sent', e, st);
    }
  }

  void _forgetBefore(DateTime at) {
    bool old(DateTime t) => at.difference(t) >= const Duration(hours: 1);
    _sent.removeWhere(old);
    _seen.removeWhere((_, t) => old(t));
  }

  /// What tells one fault from another without quoting anybody's data: where
  /// it was recorded, its kind, its code and its stack. Never its sentence.
  String _faultOf(TraceEntry e) =>
      '${e.area}|${e.errorType}|${e.errorCode}|${e.stack}';

  void _count(_Drop why) => _dropped[why] = (_dropped[why] ?? 0) + 1;

  void _drop(_Drop why) {
    _count(why);
    // While nothing is on its way there is no drain to say it afterwards.
    if (!_busy) _noteDrops({..._dropped, why: _dropped[why]! - 1});
  }

  /// One local line for what was dropped since [before], so the count is on
  /// the device even when the installation saw nothing.
  void _noteDrops(Map<_Drop, int> before) {
    final parts = [
      for (final why in const [
        _Drop.repeated,
        _Drop.overBudget,
        _Drop.queueFull,
      ])
        if ((_dropped[why] ?? 0) - (before[why] ?? 0) case final n when n > 0)
          '$n ${why.name}',
    ];
    if (parts.isNotEmpty) {
      warn('error reports dropped: ${parts.join(', ')}');
    }
  }

  Future<void> dispose() {
    // What waited under the old permission is not sent under a new one.
    _disposed = true;
    _waiting.clear();
    return _subscription.cancel();
  }
}
