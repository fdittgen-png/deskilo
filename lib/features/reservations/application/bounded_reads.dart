// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2553 C2 -- at most [BoundedReads.limit] reads in flight at once; the
// others wait their turn in order. A finished read hands its place to the
// next waiting one directly, so the bound holds between the two. Closing
// refuses the waiting reads, so nothing is left queued behind a view that
// is gone.
//
// C3: paused (the app is hidden), no read starts; the ones asked meanwhile
// wait in order and start on resume, at most [limit] at once. The reads in
// flight finish on their own.
import 'dart:async';
import 'dart:collection';

/// The reads were closed before this one could start.
class BoundedReadsClosed implements Exception {
  const BoundedReadsClosed();

  @override
  String toString() => 'BoundedReadsClosed';
}

class BoundedReads {
  BoundedReads(int limit) : limit = limit < 1 ? 1 : limit;

  final int limit;
  int _running = 0;
  bool _closed = false;
  bool _paused = false;
  final Queue<Completer<void>> _waiting = Queue();

  /// Reads in flight now.
  int get running => _running;

  /// Runs [read] once a place is free.
  Future<T> run<T>(Future<T> Function() read) async {
    if (_closed) throw const BoundedReadsClosed();
    if (!_paused && _running < limit) {
      _running++;
    } else {
      final turn = Completer<void>();
      _waiting.add(turn);
      // The finishing read handed its place over: _running is unchanged.
      await turn.future;
      if (_closed) throw const BoundedReadsClosed();
    }
    try {
      return await read();
    } finally {
      if (_waiting.isNotEmpty && !_closed && !_paused) {
        _waiting.removeFirst().complete();
      } else {
        _running--;
      }
    }
  }

  /// Reads asked now wait until [resume]; the ones in flight go on.
  void pause() => _paused = true;

  /// Starts the reads that waited, at most [limit] at once.
  void resume() {
    if (!_paused) return;
    _paused = false;
    while (!_closed && _waiting.isNotEmpty && _running < limit) {
      _running++;
      _waiting.removeFirst().complete();
    }
  }

  /// Reads waiting for a place or for [resume].
  int get waiting => _waiting.length;

  /// Refuses every waiting read; the ones in flight finish on their own.
  void close() {
    _closed = true;
    while (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
    }
  }
}
