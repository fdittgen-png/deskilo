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

  test('a workspace-owned table: filtered by the workspace, deletes kept', () {
    expect(of('reservations').map((b) => (b.event, b.workspaceFilter)), [
      (PostgresChangeEvent.all, 'ws-a'),
      (PostgresChangeEvent.delete, null),
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
      'event_decisions',
    ]) {
      expect(of(t).single.workspaceFilter, isNull, reason: t);
    }
  });

  test('every rendered table is still bound; scoped ones are real tables', () {
    expect(bindings.map((b) => b.table).toSet(), realtimeTables.toSet());
    expect(realtimeTables.toSet().containsAll(workspaceScopedTables), isTrue);
  });
}
