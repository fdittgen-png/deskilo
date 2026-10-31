// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2019 — subscriptions follow the active workspace. Workspace-owned
// tables are filtered by workspace_id (another workspace's change no
// longer wakes this one), and still have an unfiltered DELETE binding
// (a filter cannot match a delete). Account-wide tables stay unfiltered.
import 'package:deskilo/core/realtime/realtime_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final bindings = realtimeBindings('ws-a');
  Iterable<RealtimeBinding> of(String table) =>
      bindings.where((b) => b.table == table);

  test('a workspace-owned table: filtered by the workspace', () {
    expect(of('reservations').map((b) => (b.event, b.workspaceFilter)), [
      (PostgresChangeEvent.all, 'ws-a'),
    ]);
  });

  test('#3101 — every binding of a scoped table carries the workspace filter',
      () {
    final unfiltered = [
      for (final b in bindings)
        if ((workspaceScopedTables.contains(b.table) ||
                b.table == realtimeDeletionsTable) &&
            b.workspaceFilter != 'ws-a')
          '${b.table}/${b.event}',
    ];
    expect(unfiltered, isEmpty);
  });

  test('#3101 — deletes arrive as this workspace\'s deletion signals', () {
    expect(of(realtimeDeletionsTable).map((b) => (b.event, b.workspaceFilter)),
        [(PostgresChangeEvent.insert, 'ws-a')]);
    expect(deletionSignal({'table_name': 'reservations'}), 'reservations');
    // A row naming no rendered table, or none at all, wakes nothing.
    expect(deletionSignal({'table_name': 'profiles'}), isNull);
    expect(deletionSignal(const {}), isNull);
  });

  test('#3099 — a decision in another workspace does not wake this inbox', () {
    expect(of('event_decisions').map((b) => (b.event, b.workspaceFilter)), [
      (PostgresChangeEvent.all, 'ws-a'),
    ]);
  });

  test('account-wide tables stay unfiltered', () {
    for (final t in [
      'profiles',
      'members',
      'workspaces',
      'member_notes',
      'conversations',
      'conversation_participants',
    ]) {
      expect(of(t).single.workspaceFilter, isNull, reason: t);
    }
  });

  test('every rendered table is still bound; scoped ones are real tables', () {
    expect(bindings.map((b) => b.table).toSet(),
        {...realtimeTables, realtimeDeletionsTable});
    expect(realtimeTables.toSet().containsAll(workspaceScopedTables), isTrue);
  });
}
