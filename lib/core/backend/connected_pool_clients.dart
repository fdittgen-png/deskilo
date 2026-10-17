// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2562 -- the long-lived, self-refreshing clients of connected targets: the
// workspace client of a split deployment. Each one carries only its own
// target's session (never the home's), refreshes itself, and every refreshed
// session is saved back under that target's own record by the pool. A
// missing, quarantined, expired or changed target is a typed
// [ConnectionFailure]; the caller never falls back to another client.
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_settings.dart';
import 'connection_outcome.dart';

/// A verified, self-refreshing client of one connected target.
class PooledClient {
  PooledClient._(
    this.client, {
    required this.account,
    required this.installationId,
    required this.epoch,
  });

  final SupabaseClient client;

  /// The signed-in account's id on THAT target.
  final String account;
  final String installationId;

  /// The connection's epoch when it was opened; a disconnect moves it on.
  final int epoch;
  StreamSubscription<AuthState>? _listener;

  Future<void> dispose() async {
    await _listener?.cancel();
    await client.dispose();
  }
}

/// #2562 -- a lease on the pooled client of ONE connected target, held for
/// as long as a consumer (a realtime channel, a workspace context) lives.
/// The pool owns the client; the lease only guarantees what the holder may
/// rely on: [client] is that target's own and never anything else, and when
/// the pool ends the connection (disconnect, replaced connection, closed
/// pool, signed-out target) [ended] completes with the typed reason and
/// [client] refuses from then on, so a holder can neither keep serving a
/// dead target nor be answered by another one.
class PinnedClient {
  PinnedClient._(this._pooled, this.source, this._onRelease);

  final PooledClient _pooled;
  final String source;
  final void Function(PinnedClient pin) _onRelease;
  final _ended = Completer<ConnectionFailure>();
  ConnectionFailure? _failure;
  bool _released = false;

  /// The target's own client; throws the typed end once the lease ended.
  SupabaseClient get client {
    final failure = _failure;
    if (failure != null) throw failure;
    return _pooled.client;
  }

  String get account => _pooled.account;
  String get installationId => _pooled.installationId;
  bool get isLive => _failure == null && !_released;

  /// Completes (never with an error) when the pool ended this connection.
  Future<ConnectionFailure> get ended => _ended.future;

  /// Gives the lease back; idempotent. The pool keeps the client for the
  /// next holder and closes it with the connection.
  void release() {
    if (_released) return;
    _released = true;
    _onRelease(this);
  }

  void _end(ConnectionFailure failure) {
    if (_failure != null) return;
    _failure = failure;
    if (!_ended.isCompleted) _ended.complete(failure);
  }
}

typedef PoolRecord = Map<String, dynamic>;
typedef PoolRecordOf = Future<PoolRecord> Function(String source);
typedef PoolVerify = Future<void> Function(
  String source,
  PoolRecord record,
  int epoch,
  SupabaseClient client,
);

class PooledClients {
  PooledClients({
    required this.origin,
    required this.check,
    required this.epochOf,
    required this.record,
    required this.newClient,
    required this.verify,
    required this.save,
  });

  /// The home origin: never a pooled target.
  final String origin;
  final void Function(String source) check;
  final int Function(String source) epochOf;
  final PoolRecordOf record;
  final SupabaseClient Function(BackendEndpoint endpoint) newClient;
  final PoolVerify verify;
  final PoolVerify save;
  final _open = <String, PooledClient>{};
  final _pins = <String, Set<PinnedClient>>{};

  /// #2562 -- the pooled client of [source] as a lease that lives as long
  /// as its holder (a channel's lifetime), see [PinnedClient].
  Future<PinnedClient> pin(String source) async {
    final pooled = await open(source);
    final pin = PinnedClient._(pooled, source, _unpin);
    (_pins[source] ??= {}).add(pin);
    return pin;
  }

  void _unpin(PinnedClient pin) {
    final set = _pins[pin.source];
    if (set == null) return;
    set.remove(pin);
    if (set.isEmpty) _pins.remove(pin.source);
  }

  void _endPins(String source, ConnectionFailureReason reason) {
    final set = _pins.remove(source);
    if (set == null) return;
    for (final pin in set) {
      pin._end(ConnectionFailure(source, reason));
    }
  }

  Future<PooledClient> open(String source) async {
    check(source);
    if (source.isEmpty || source == origin) {
      throw ConnectionFailure(source, ConnectionFailureReason.currentServer);
    }
    final live = _open[source];
    if (live != null && live.epoch == epochOf(source)) {
      final session = live.client.auth.currentSession;
      if (session != null && !session.isExpired) return live;
    }
    await discard(
      source,
      live != null && live.epoch == epochOf(source)
          ? ConnectionFailureReason.expired
          : ConnectionFailureReason.cancelled,
    );
    final epoch = epochOf(source);
    final saved = await record(source);
    final client = newClient(BackendEndpoint(source, saved['key'] as String));
    try {
      await verify(source, saved, epoch, client);
      check(source);
      if (epoch != epochOf(source)) {
        throw ConnectionFailure(source, ConnectionFailureReason.cancelled);
      }
    } catch (e, st) {
      await client.dispose();
      Error.throwWithStackTrace(e, st);
    }
    final pooled =
        PooledClient._(
            client,
            account: saved['account'] as String,
            installationId: saved['installation_id'] as String,
            epoch: epoch,
          )
          .._listener = client.auth.onAuthStateChange.listen((change) {
            if (change.event == AuthChangeEvent.signedOut) {
              // The target ended its own session: leases end as expired.
              final self = _open[source];
              if (self != null && identical(self.client, client)) {
                unawaited(discard(source, ConnectionFailureReason.expired));
              }
              return;
            }
            if (change.event != AuthChangeEvent.tokenRefreshed) return;
            // trace-exempt: the pool remembers and traces a failed save.
            unawaited(save(source, saved, epoch, client));
          });
    _open[source] = pooled;
    await save(source, saved, epoch, client);
    return pooled;
  }

  Future<void> discard(
    String source, [
    ConnectionFailureReason reason = ConnectionFailureReason.cancelled,
  ]) async {
    final old = _open.remove(source);
    _endPins(source, reason);
    if (old != null) await old.dispose();
  }

  Future<void> closeAll() async {
    final all = _open.values.toList();
    _open.clear();
    for (final source in _pins.keys.toList()) {
      _endPins(source, ConnectionFailureReason.cancelled);
    }
    for (final pooled in all) {
      await pooled.dispose();
    }
  }
}
