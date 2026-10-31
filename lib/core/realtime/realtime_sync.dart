// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'invalidation_map.dart' show kResyncSignal;
import 'profile_change_classifier.dart';

/// Push-driven freshness (#413): a stream of "table X changed" signals
/// for the signed-in user, fed by Supabase Realtime `postgres_changes`
/// on the tables migration 0080 publishes. RLS scopes what each
/// subscriber receives, so no client-side filter is needed — and every
/// event, one's own writes included, is only an INVALIDATION signal;
/// the providers refetch through their normal repositories.
abstract class RealtimeSync {
  /// Emits the table name on every change relevant to this user while
  /// [workspaceId] is the active workspace, and [kResyncSignal] when
  /// events may have been missed (the channel re-joined after an error).
  /// Cancelling the subscription tears the channel down.
  Stream<String> watch(String workspaceId);

  /// #2564 O5 — the account target's feed, on the personal home's client:
  /// the facts that span workspaces (memberships, the workspace list, the
  /// profile, the messenger). No workspace id: nothing here belongs to one.
  Stream<String> watchAccount();
}

/// The tables the app renders — one `postgres_changes` binding each.
/// Must stay a subset of what 0080 publishes.
@visibleForTesting
const realtimeTables = [
  'reservations',
  'members',
  'workspaces',
  'profiles',
  'levels',
  'offices',
  'desks',
  'seats',
  'plan_images',
  'events',
  'event_decisions',
  'member_notes',
  'conversations',
  'conversation_participants',
  'ledger_entries',
  'payment_intents',
  'invoices',
  'services',
  'accessories',
  'seat_accessories',
  'closure_days',
  'quota_extensions',
  'fee_bands',
  'packages',
  'validation_policies',
];

/// #2019 — tables whose rows belong to exactly one workspace and matter
/// only inside it: subscribed with `workspace_id=eq.<active>`, so a person
/// in several workspaces is not woken by the others. Account-wide facts
/// (profiles, memberships, the messenger, the workspace row itself) stay
/// unfiltered.
@visibleForTesting
const workspaceScopedTables = {
  'reservations', 'levels', 'offices', 'desks', 'seats', 'plan_images',
  'events', 'event_decisions', 'ledger_entries', 'payment_intents', 'invoices', 'services',
  'accessories', 'seat_accessories', 'closure_days', 'quota_extensions',
  'fee_bands', 'packages', 'validation_policies',
};

/// One `postgres_changes` binding: [workspaceFilter] null means every row
/// the subscriber may see (RLS still applies).
@visibleForTesting
typedef RealtimeBinding = ({
  String table,
  PostgresChangeEvent event,
  String? workspaceFilter,
});

/// #3101 — where deletes of the scoped tables arrive. Realtime cannot
/// filter a DELETE (the old row carries only its key), and an unfiltered
/// delete listener woke every client of every tenant. Migration 0615 has
/// each deleting statement write one row per (workspace, table) here,
/// subscribed as an INSERT filtered by the workspace like every scoped
/// table.
@visibleForTesting
const realtimeDeletionsTable = 'realtime_deletions';

/// The table a deletion signal names, when it is one this feed renders.
@visibleForTesting
String? deletionSignal(Map<String, Object?> newRecord) {
  final table = newRecord['table_name'];
  return table is String && workspaceScopedTables.contains(table) ? table : null;
}

/// #2019 — the bindings for [workspaceId]: every scoped table filtered by
/// the workspace, and its deletes through [realtimeDeletionsTable] (#3101).
@visibleForTesting
List<RealtimeBinding> realtimeBindings(String workspaceId) => [
  for (final table in realtimeTables)
    if (workspaceScopedTables.contains(table))
      (table: table, event: PostgresChangeEvent.all, workspaceFilter: workspaceId)
    else
      (table: table, event: PostgresChangeEvent.all, workspaceFilter: null),
  (
    table: realtimeDeletionsTable,
    event: PostgresChangeEvent.insert,
    workspaceFilter: workspaceId,
  ),
];

/// #2564 O5 — the account target's bindings: the tables that are not one
/// workspace's rows, unfiltered (RLS still applies).
List<RealtimeBinding> _accountBindings() => [
  for (final table in realtimeTables)
    if (!workspaceScopedTables.contains(table))
      (table: table, event: PostgresChangeEvent.all, workspaceFilter: null),
];

/// How long to wait before the [attempt]-th reconnect (0-based):
/// 2s, 4s, 8s, 16s, then 30s forever — fast enough that a kiosk
/// recovers from a Wi-Fi blip within seconds, slow enough that a dead
/// backend is not hammered.
@visibleForTesting
Duration reconnectDelay(int attempt) =>
    Duration(seconds: min(30, 2 << min(attempt, 4)));

/// The reconnect policy of one watched workspace (#961), kept apart from
/// the socket so the re-entrant sequence the pilot hit can be driven in
/// a test. The rule: a channel is handled AT MOST ONCE. Tearing a channel
/// down unsubscribes it, and unsubscribing fires `closed` on that same
/// channel — on a dead socket synchronously, from the push timeout. An
/// unguarded callback tore the channel down again from inside its own
/// teardown, 140 000 frames deep, until the stack overflowed; on a live
/// socket the same re-entry merely scheduled two reconnects per outage.
class ChannelSupervisor<C extends Object> {
  ChannelSupervisor({
    required this._create,
    required this._subscribe,
    required this._remove,
    required this._trace,
    required this._onResync,
    this._delayFor = reconnectDelay,
  });

  final C Function() _create;
  final void Function(C channel) _subscribe;
  final void Function(C channel) _remove;
  final void Function(String message) _trace;
  final void Function() _onResync;
  final Duration Function(int attempt) _delayFor;

  /// The channel whose statuses count; every other channel is stale.
  C? current;
  Timer? _retry;
  int attempt = 0;
  bool everJoined = false;
  bool disposed = false;

  /// Opens a fresh channel and subscribes it; the subscription reports
  /// back through [onStatus] with the channel it concerns.
  void start() {
    if (disposed) return;
    final channel = _create();
    current = channel;
    _subscribe(channel);
  }

  void onStatus(C channel, RealtimeSubscribeStatus status, [Object? error]) {
    // A stale channel — already torn down, or replaced — says nothing:
    // this is the guard that ends the recursion.
    if (disposed || channel != current) return;
    _trace('$status${error == null ? '' : ' ($error)'}');
    switch (status) {
      case RealtimeSubscribeStatus.subscribed:
        attempt = 0;
        // A RE-join means a gap: changes committed while the channel
        // was down were never delivered. One resync closes it.
        if (everJoined) _onResync();
        everJoined = true;
      case RealtimeSubscribeStatus.channelError:
      case RealtimeSubscribeStatus.timedOut:
      case RealtimeSubscribeStatus.closed:
        // Forget the channel BEFORE tearing it down, and tear it down
        // outside the library's trigger loop.
        current = null;
        scheduleMicrotask(() => _remove(channel));
        final delay = _delayFor(attempt++);
        _trace('reconnecting in ${delay.inSeconds}s (attempt $attempt)');
        _retry?.cancel();
        _retry = Timer(delay, start);
    }
  }

  void dispose() {
    disposed = true;
    _retry?.cancel();
    final channel = current;
    current = null;
    if (channel != null) _remove(channel);
  }
}

class SupabaseRealtimeSync implements RealtimeSync {
  SupabaseRealtimeSync(this._client, {void Function(String)? trace})
      : _trace = trace ?? _debugTrace;

  final SupabaseClient _client;

  /// Channel-state tracing (#577): every subscribe outcome and reconnect
  /// is announced so a stale kiosk can be diagnosed from the logs.
  final void Function(String message) _trace;

  static void _debugTrace(String message) {
    if (kDebugMode) debugPrint('[realtime] $message');
  }

  /// The client this feed runs on (tests pin which target it serves).
  @visibleForTesting
  SupabaseClient get client => _client;

  @override
  Stream<String> watch(String workspaceId) => _feed(
    'db-changes-$workspaceId',
    realtimeBindings(workspaceId),
  );

  @override
  Stream<String> watchAccount() => _feed('db-changes-account', _accountBindings());

  Stream<String> _feed(String channelName, List<RealtimeBinding> bindings) {
    final controller = StreamController<String>.broadcast();
    // #2019 C — one per watched workspace: presence-only profile updates.
    final profiles = ProfileChangeClassifier();
    late final ChannelSupervisor<RealtimeChannel> supervisor;
    supervisor = ChannelSupervisor<RealtimeChannel>(
      create: () {
        final ch = _client.channel(channelName);
        for (final b in bindings) {
          final ws = b.workspaceFilter;
          ch.onPostgresChanges(
            event: b.event,
            schema: 'public',
            table: b.table,
            filter: ws == null
                ? null
                : PostgresChangeFilter(
                    type: PostgresChangeFilterType.eq,
                    column: 'workspace_id',
                    value: ws,
                  ),
            callback: (payload) {
              if (controller.isClosed) return;
              final signal = switch (b.table) {
                'profiles' => profiles.signal(payload.eventType, payload.newRecord),
                realtimeDeletionsTable => deletionSignal(payload.newRecord),
                _ => b.table,
              };
              if (signal != null) controller.add(signal);
            },
          );
        }
        return ch;
      },
      subscribe: (ch) => ch.subscribe(
        (status, [error]) => supervisor.onStatus(ch, status, error),
      ),
      remove: (ch) => unawaited(_client.removeChannel(ch)),
      trace: (message) => _trace('channel $channelName → $message'),
      onResync: () {
        if (!controller.isClosed) controller.add(kResyncSignal);
      },
    );
    supervisor.start();
    controller.onCancel = () {
      supervisor.dispose();
      unawaited(controller.close());
    };
    return controller.stream;
  }
}
