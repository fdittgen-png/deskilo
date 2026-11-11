// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3684 -- how the map asks the public geocoder: one address at a time,
// with a pause after each request before the next one goes out, and a
// found place remembered on the device so it is never asked again.
import 'dart:async';

import '../../../core/trace/trace_logger.dart';
import '../domain/directory_location.dart';
import '../domain/directory_location_memory.dart';

class DirectoryLookups {
  DirectoryLookups(this._geocoder, this._memory, {this.pause = courtesyPause});

  final DirectoryGeocoder _geocoder;
  final DirectoryLocationMemory _memory;

  /// The wait between two requests: [courtesyPause]. A test that is not
  /// about the pacing passes none, so no timer outlives it.
  final Duration pause;

  /// The public geocoder's courtesy rate: at most one request about every
  /// second, as the free public services ask of their users. Not a
  /// business value; a deployment with its own geocoder keeps it too.
  static const courtesyPause = Duration(seconds: 1);

  /// How many found addresses the device keeps; the oldest goes first.
  /// Bounds the stored preference, not what the map shows.
  static const rememberedLimit = 256;

  Future<Map<String, DirectoryLocation>>? _known;

  /// The end of the queue: completes with whether that turn sent a
  /// request, so the next one knows whether to pause first.
  Future<bool> _tail = Future.value(false);

  Future<Map<String, DirectoryLocation>> _remembered() =>
      _known ??= _memory.read().catchError((Object e, StackTrace st) {
        TraceLogger.instance.warn(
          'directory',
          'remembered map places unavailable, asking again',
          error: e.runtimeType,
          stackTrace: st,
        );
        return <String, DirectoryLocation>{};
      });

  /// Where [address] is. A remembered place answers at once; otherwise
  /// the lookup waits its turn. [wanted] is asked before the request goes
  /// out: a map that closed meanwhile sends nothing.
  Future<DirectoryLocation?> locate(
    String address, {
    bool Function()? wanted,
  }) async {
    final key = directoryAddressKey(address);
    if (key.isEmpty) return null;
    final known = await _remembered();
    if (known[key] case final place?) return place;
    final before = _tail;
    final turn = Completer<bool>();
    _tail = turn.future;
    var sent = false;
    try {
      final paused = await before;
      // An earlier turn may have found the same address.
      if (known[key] case final place?) return place;
      if (wanted?.call() == false) return null;
      if (paused && pause > Duration.zero) await Future<void>.delayed(pause);
      if (wanted?.call() == false) return null;
      sent = true;
      final found = await _geocoder.locate(address.trim());
      if (found != null) _remember(known, key, found);
      return found;
    } finally {
      turn.complete(sent);
    }
  }

  void _remember(
    Map<String, DirectoryLocation> known,
    String key,
    DirectoryLocation place,
  ) {
    known
      ..remove(key)
      ..[key] = place;
    while (known.length > rememberedLimit) {
      known.remove(known.keys.first);
    }
    unawaited(
      _memory.write({...known}).catchError((Object e, StackTrace st) {
        TraceLogger.instance.warn(
          'directory',
          'found map place not remembered',
          error: e.runtimeType,
          stackTrace: st,
        );
      }),
    );
  }
}
