// SPDX-License-Identifier: 0BSD
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Push-driven freshness (#413): a stream of "table X changed" signals
/// for the signed-in user, fed by Supabase Realtime `postgres_changes`
/// on the tables migration 0080 publishes. RLS scopes what each
/// subscriber receives, so no client-side filter is needed — and every
/// event, one's own writes included, is only an INVALIDATION signal;
/// the providers refetch through their normal repositories.
abstract class RealtimeSync {
  /// Emits the table name on every change relevant to this user while
  /// [workspaceId] is the active workspace. Cancelling the subscription
  /// tears the channel down.
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

class SupabaseRealtimeSync implements RealtimeSync {
  SupabaseRealtimeSync(this._client);

  final SupabaseClient _client;

  @override
  Stream<String> watch(String workspaceId) {
    final controller = StreamController<String>.broadcast();
    final channel = _client.channel('db-changes-$workspaceId');
    for (final table in realtimeTables) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) {
          if (!controller.isClosed) controller.add(table);
        },
      );
    }
    channel.subscribe();
    controller.onCancel = () {
      _client.removeChannel(channel);
      controller.close();
    };
    return controller.stream;
  }
}
