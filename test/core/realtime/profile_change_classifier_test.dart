// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2019 C — a heartbeat-only profile update refreshes the presence
// consumer alone; any identity change, a first sighting, an insert or a
// delete stays a full `profiles` refresh.
import 'package:deskilo/core/realtime/invalidation_map.dart';
import 'package:deskilo/core/realtime/profile_change_classifier.dart';
import 'package:deskilo/features/members/providers/directory_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const update = PostgresChangeEvent.update;
  Map<String, dynamic> row({
    String name = 'Ada',
    String seen = '2026-10-02T09:00:00Z',
    String modified = '2026-10-02T09:00:00Z',
    String? defaultWs = 'ws-1',
  }) => {
    'id': 'u1',
    'display_name': name,
    'last_seen_at': seen,
    'modified_datetime': modified,
    'default_workspace_id': defaultWs,
  };

  test('a first sighting is a full refresh: nothing to compare with', () {
    expect(ProfileChangeClassifier().signal(update, row()), 'profiles');
  });

  test('a heartbeat after a known row is presence only', () {
    final c = ProfileChangeClassifier()..signal(update, row());
    expect(
      c.signal(
        update,
        row(seen: '2026-10-02T09:05:00Z', modified: '2026-10-02T09:05:00Z'),
      ),
      kProfilePresenceSignal,
    );
  });

  test('a name or default-workspace change is never presence', () {
    final c = ProfileChangeClassifier()..signal(update, row());
    expect(c.signal(update, row(name: 'Grace', seen: 'later')), 'profiles');
    expect(c.signal(update, row(name: 'Grace', defaultWs: null)), 'profiles');
  });

  test('an insert or a delete is a full refresh, and a delete forgets', () {
    final c = ProfileChangeClassifier()..signal(update, row());
    expect(c.signal(PostgresChangeEvent.insert, row()), 'profiles');
    expect(c.signal(PostgresChangeEvent.delete, {'id': 'u1'}), 'profiles');
    expect(
      c.signal(update, row()),
      'profiles',
      reason: 'after a delete there is nothing to compare with',
    );
  });

  test('a row without an id is a full refresh', () {
    expect(
      ProfileChangeClassifier().signal(update, {'display_name': 'x'}),
      'profiles',
    );
  });

  test('presence refreshes the profiles only, not names or the default '
      'workspace', () {
    final presence = invalidationFor(kProfilePresenceSignal).providers;
    expect(presence, [memberProfilesProvider]);
    expect(presence, isNot(contains(defaultWorkspaceIdProvider)));
    expect(
      invalidationFor('profiles').providers,
      contains(defaultWorkspaceIdProvider),
    );
  });
}
