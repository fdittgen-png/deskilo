// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1833 (checkpoint B) — the member names every map, grid and list shows
// come from the purpose projection, not from the `profiles` rows.
//
// `fetchMemberNames` used to select `first_name, last_name` of every
// space mate straight from the table: a member's legal name reached every
// other member. The fixture answers the table route the way it did
// before 0320 (a canary legal name) and the RPC route with what
// `member_profiles` answers that caller, so a reader that still takes the
// table route fails. A space mate sees the display name; whoever holds
// the operational group still gets "Prénom NOM" for the documents.
import 'dart:convert';

import 'package:deskilo/features/workspace/data/supabase_workspace_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _members = [
  {
    'id': 'member-2',
    'user_id': 'user-2',
    'managed_identity': null,
    'managed_name': '',
    'member_number': '',
    'home_site_id': null,
  },
];

const Map<String, Object?> _tableRow = {
  'id': 'user-2',
  'display_name': 'Ada',
  'first_name': 'LEGAL-FIRST-CANARY',
  'last_name': 'LEGAL-LAST-CANARY',
};

({SupabaseClient client, List<String> paths}) _fixture(Object projection) {
  final paths = <String>[];
  final client = SupabaseClient(
    'https://canonical.example',
    'test-key',
    httpClient: MockClient((request) async {
      paths.add(request.url.path);
      final Object answer = switch (request.url.path) {
        '/rest/v1/members' => _members,
        '/rest/v1/profiles' => [_tableRow],
        _ => projection,
      };
      return http.Response(
        jsonEncode(answer),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }),
  );
  return (client: client, paths: paths);
}

void main() {
  test(
    'a space mate is named by the display name, never the legal name',
    () async {
      final f = _fixture([
        {
          'id': 'user-2',
          'purposes': ['community'],
          'community': {'display_name': 'Ada'},
        },
      ]);
      addTearDown(f.client.dispose);

      final names = await SupabaseWorkspaceRepository(f.client)
          .fetchMemberNames('ws-1');

      expect(names, {'member-2': 'Ada'});
      expect(
        f.paths,
        isNot(contains('/rest/v1/profiles')),
        reason: 'the rows themselves are never selected',
      );
      expect(f.paths, contains('/rest/v1/rpc/member_profiles'));
    },
  );

  test('the operational group still names the member for documents', () async {
    final f = _fixture([
      {
        'id': 'user-2',
        'purposes': ['community', 'operational'],
        'community': {'display_name': 'Ada'},
        'operational': {'first_name': 'Ada', 'last_name': 'Lovelace'},
      },
    ]);
    addTearDown(f.client.dispose);

    final names = await SupabaseWorkspaceRepository(f.client)
        .fetchMemberNames('ws-1');

    expect(names, {'member-2': 'Ada LOVELACE'});
  });

  test('a legal name outside the operational group is not read', () async {
    final f = _fixture([
      {
        'id': 'user-2',
        'purposes': ['community'],
        'community': {'display_name': 'Ada', 'first_name': 'MISPLACED-CANARY'},
        'operational': {'first_name': 'UNLISTED-CANARY'},
      },
    ]);
    addTearDown(f.client.dispose);

    final names = await SupabaseWorkspaceRepository(f.client)
        .fetchMemberNames('ws-1');

    expect(names, {'member-2': 'Ada'});
  });
}
