// SPDX-License-Identifier: AGPL-3.0-or-later
// Ordered, failure-isolated writes and finalization of a recording.
part of 'recorder_controller.dart';

extension _RecorderPersistence on RecorderController {
  void _enqueue(Future<void> Function(RecordingWriter) write) {
    final writer = _writer;
    if (writer == null || _writeFailed) return;
    if (_queued >= limits.maxQueuedWrites) {
      _writeFailed = true;
      TraceLogger.instance.warn(
        'recorder',
        'write queue full; recording stopped',
      );
      _end(RecordingEndReason.storageFailed);
      return;
    }
    _queued++;
    _chain = _chain.then((_) async {
      // After one failed write, nothing more goes to that recording: a
      // later line after a missing one would read as a sound file.
      if (identical(writer, _failedWriter)) {
        if (identical(writer, _writer)) _queued--;
        return;
      }
      try {
        await write(writer);
      } catch (e, st) {
        TraceLogger.instance.warn(
          'recorder',
          'write failed (${e.runtimeType}); recording stopped',
          stackTrace: st,
        );
        _failedWriter = writer;
        if (identical(writer, _writer)) {
          _writeFailed = true;
          if (_live) {
            _end(RecordingEndReason.storageFailed);
          } else if (_state == RecorderState.ended) {
            // Stopped, but the end never reached the disk: partial.
            _endReason = RecordingEndReason.storageFailed;
            _emit();
          }
        }
      }
      if (identical(writer, _writer)) _queued--;
    });
  }

  void _end(RecordingEndReason reason) {
    if (!_live) return;
    final last = _segments.removeLast();
    _segments.add(last.endMs == null ? last.closedAt(_elapsed()) : last);
    final closed = _segments.last;
    _endReason = reason;
    _state = RecorderState.ended;
    if (!_writeFailed) {
      _enqueue((w) => w.segment(closed));
      final completeness = completenessOf(reason, _steps);
      _enqueue((w) => w.end(reason, completeness));
    }
    _emit();
  }

  Future<void> _drain() async {
    try {
      await _chain;
    } catch (e, st) {
      TraceLogger.instance.warn(
        'recorder',
        'drain failed (${e.runtimeType})',
        stackTrace: st,
      );
    }
  }

  void _guard(void Function() body) {
    try {
      body();
    } catch (e, st) {
      // The recorder failing is never the task failing.
      TraceLogger.instance.warn(
        'recorder',
        'observation failed (${e.runtimeType}); recording stopped',
        stackTrace: st,
      );
      _writeFailed = true;
      try {
        _end(RecordingEndReason.storageFailed);
      } catch (e, st) {
        TraceLogger.instance.warn(
          'recorder',
          'could not end the recording (${e.runtimeType})',
          stackTrace: st,
        );
        _state = RecorderState.ended;
      }
    }
  }
}
