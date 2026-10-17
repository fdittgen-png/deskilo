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
    await discard(source);
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
            if (change.event != AuthChangeEvent.tokenRefreshed) return;
            // trace-exempt: the pool remembers and traces a failed save.
            unawaited(save(source, saved, epoch, client));
          });
    _open[source] = pooled;
    await save(source, saved, epoch, client);
    return pooled;
  }

  Future<void> discard(String source) async {
    final old = _open.remove(source);
    if (old != null) await old.dispose();
  }

  Future<void> closeAll() async {
    final all = _open.values.toList();
    _open.clear();
    for (final pooled in all) {
      await pooled.dispose();
    }
  }
}
