// SPDX-License-Identifier: 0BSD
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'invalidation_map.dart' show kResyncSignal;

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
}

/// The tables the app renders — one `postgres_changes` binding each.
/// Must stay a subset of what 0080 publishes.
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

/// How long to wait before the [attempt]-th reconnect (0-based):
/// 2s, 4s, 8s, 16s, then 30s forever — fast enough that a kiosk
/// recovers from a Wi-Fi blip within seconds, slow enough that a dead
/// backend is not hammered.
Duration reconnectDelay(int attempt) =>
    Duration(seconds: min(30, 2 << min(attempt, 4)));

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

  @override
  Stream<String> watch(String workspaceId) {
    final controller = StreamController<String>.broadcast();
    RealtimeChannel? channel;
    Timer? retry;
    var attempt = 0;
    var everJoined = false;
    var disposed = false;

    void connect() {
      final ch = _client.channel('db-changes-$workspaceId');
      channel = ch;
      for (final table in realtimeTables) {
        ch.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          callback: (_) {
            if (!controller.isClosed) controller.add(table);
          },
        );
      }
      ch.subscribe((status, [error]) {
        if (disposed) return;
        _trace('channel $workspaceId → $status'
            '${error == null ? '' : ' ($error)'}');
        switch (status) {
          case RealtimeSubscribeStatus.subscribed:
            attempt = 0;
            // A RE-join means a gap: changes committed while the channel
            // was down were never delivered. One resync closes it.
            if (everJoined && !controller.isClosed) {
              controller.add(kResyncSignal);
            }
            everJoined = true;
          case RealtimeSubscribeStatus.channelError:
          case RealtimeSubscribeStatus.timedOut:
          case RealtimeSubscribeStatus.closed:
            unawaited(_client.removeChannel(ch));
            channel = null;
            final delay = reconnectDelay(attempt++);
            _trace('reconnecting in ${delay.inSeconds}s '
                '(attempt $attempt)');
            retry?.cancel();
            retry = Timer(delay, connect);
        }
      });
    }

    connect();
    controller.onCancel = () {
      disposed = true;
      retry?.cancel();
      final ch = channel;
      if (ch != null) unawaited(_client.removeChannel(ch));
      controller.close();
    };
    return controller.stream;
  }
}
