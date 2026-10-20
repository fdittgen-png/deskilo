// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2578 — the query coordinator. A page of cards asks the server for the
// same figure many times over: the dashboard's series, its card, its
// grouped table and the compared period all contain the current period.
// The coordinator stands in front of any [KpiBatchReader] and makes the
// server compute each distinct figure once:
//
//  * requests that arrive in the same turn of the event loop leave in ONE
//    batch (a caller's own requests are never split from each other, so
//    its total, groups and history still come from one snapshot);
//  * a figure already in flight is awaited, not asked again;
//  * nothing is kept once the answer is delivered — the providers above
//    own caching and invalidation, so a revoked right or a changed
//    connection leaves nothing behind here.
//
// A refusal or a transport failure reaches every caller waiting on the
// batch that carried it, exactly as it did when each asked on its own.
import 'dart:async';

import '../domain/bi_batch.dart';

/// The most requests one outgoing batch carries: the server's default
/// bound (`bi.batch_max_requests`, 0508). Callers are packed whole.
const _batchMax = 60;

class BiQueryCoordinator implements KpiBatchReader {
  BiQueryCoordinator(this._inner);

  final KpiBatchReader _inner;

  final _waiting = <_Call>[];
  final _inflight = <String, Completer<BiBatchEntry>>{};
  Timer? _flush;

  /// How many batches have left for the server (observability, tests).
  int batchesSent = 0;

  @override
  Future<List<BiBatchEntry>> read(
    String workspaceId,
    List<BiBatchRequest> requests,
  ) {
    if (requests.isEmpty) return Future.value(const []);
    final call = _Call(workspaceId, requests);
    _waiting.add(call);
    _flush ??= Timer(Duration.zero, _send);
    return call.done.future;
  }

  void _send() {
    _flush = null;
    final calls = [..._waiting];
    _waiting.clear();
    // A caller's requests stay together (one snapshot); callers are packed
    // into batches of at most [_batchMax] figures not already
    // asked.
    calls.sort((a, b) => a.workspaceId.compareTo(b.workspaceId));
    var batch = _Batch();
    for (final c in calls) {
      final fresh = {
        for (final r in c.requests)
          if (!_inflight.containsKey(_key(c.workspaceId, r))) r.identity,
      };
      final extra = fresh.where((id) => !batch.has(c.workspaceId, id)).length;
      if (batch.size > 0 &&
          (batch.workspaceId != c.workspaceId ||
              batch.size + extra > _batchMax)) {
        _dispatch(batch);
        batch = _Batch();
      }
      batch.workspaceId = c.workspaceId;
      for (final r in c.requests) {
        final key = _key(c.workspaceId, r);
        if (_inflight.containsKey(key)) continue;
        _inflight[key] = Completer<BiBatchEntry>();
        batch.asked.add((r, _inflight[key]!));
      }
      _deliver(c);
    }
    _dispatch(batch);
  }

  static String _key(String workspaceId, BiBatchRequest r) =>
      '$workspaceId#${r.identity}';

  void _dispatch(_Batch batch) {
    if (batch.asked.isEmpty) return;
    final workspaceId = batch.workspaceId!;
    batchesSent++;
    final outgoing = [
      for (final (i, a) in batch.asked.indexed) _rekey(a.$1, '$i'),
    ];
    unawaited(() async {
      try {
        final entries = await _inner.read(workspaceId, outgoing);
        for (final (i, a) in batch.asked.indexed) {
          _inflight.remove(_key(workspaceId, a.$1));
          a.$2.complete(entries[i]);
        }
      } on Object catch (e, st) {
        // trace-exempt: handed to every waiter of this batch, who rethrow.
        for (final a in batch.asked) {
          _inflight.remove(_key(workspaceId, a.$1));
          a.$2.completeError(e, st);
        }
      }
    }());
  }

  void _deliver(_Call call) {
    final parts = [
      for (final r in call.requests)
        _inflight[_key(call.workspaceId, r)]!.future.then(
          (e) => e.withKey(r.key),
        ),
    ];
    unawaited(
      Future.wait(parts).then(
        call.done.complete,
        onError: call.done.completeError,
      ),
    );
  }

  static BiBatchRequest _rekey(BiBatchRequest r, String key) =>
      r.metricId == 'capacity.seat_utilisation'
      ? BiBatchRequest.capacity(
          key: key,
          from: r.from!,
          to: r.to!,
          levelId: r.levelId,
        )
      : BiBatchRequest.finance(
          key: key,
          metricId: r.metricId,
          fromMonth: r.fromMonth!,
          toMonth: r.toMonth!,
        );
}

class _Batch {
  String? workspaceId;
  final asked = <(BiBatchRequest, Completer<BiBatchEntry>)>[];

  int get size => asked.length;

  bool has(String workspace, String identity) =>
      workspace == workspaceId && asked.any((a) => a.$1.identity == identity);
}

class _Call {
  _Call(this.workspaceId, this.requests);

  final String workspaceId;
  final List<BiBatchRequest> requests;
  final done = Completer<List<BiBatchEntry>>();
}
