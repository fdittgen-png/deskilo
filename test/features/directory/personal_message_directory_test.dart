// SPDX-License-Identifier: AGPL-3.0-or-later
// #2472 (P): the strict adapter of my_personal_message_directory_v1 at the
// personal home. It sends the section, workspace, cursor and search as the
// reader takes them, types every page strictly (a malformed answer is
// never an empty directory), names each refusal, and says "unsupported"
// only for a home that lacks the reader. Who is listed is the database's
// answer (pgTAP 274).
import 'dart:convert';

import 'package:deskilo/features/directory/data/supabase_personal_message_directory_repository.dart';
import 'package:deskilo/features/directory/domain/personal_message_directory.dart';
import 'package:deskilo/features/directory/domain/recipient_search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _a = 'aaaaaaaa-0000-4000-8000-000000000001:00000000-0000-4000-8000-0000000000f1';
const _b = 'bbbbbbbb-0000-4000-8000-000000000001:00000000-0000-4000-8000-0000000000f1';

Map<String, Object?> _envelope(
  String section,
  List<Object?> items, {
  String? next,
  String status = 'ready',
}) => {
  'schema_version': 1,
  'section': section,
  'items': items,
  'next_key': next,
  'has_more': next != null,
  'relationship_status': status,
};

Map<String, Object?> _person(String id, {String? name}) => {
  'person_id': id,
  'personal_home_id': 'home',
  'context_workspace_ref': _a,
  'view': {
    'can_message': true,
    if (name != null) 'identity': {'name': name, 'avatar_path': null},
  },
};

class _Home {
  final List<Map<String, dynamic>> received = [];
  Object? answer;
  ({int status, String code})? refusal;

  Future<http.Response> handle(http.Request request) async {
    expect(request.url.path, '/rest/v1/rpc/my_personal_message_directory_v1');
    received.add(jsonDecode(request.body) as Map<String, dynamic>);
    final r = refusal;
    return http.Response(
      jsonEncode(
        r == null
            ? answer
            : {'code': r.code, 'message': 'no', 'details': null, 'hint': null},
      ),
      r?.status ?? 200,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }
}

SupabasePersonalMessageDirectoryRepository _adapter(_Home home) =>
    SupabasePersonalMessageDirectoryRepository(
      SupabaseClient(
        'http://127.0.0.1:54321',
        'sb_publishable_test',
        httpClient: MockClient(home.handle),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    );

Matcher _refused(DirectoryFailure failure) => throwsA(
  isA<DirectoryRefused>().having((e) => e.failure, 'failure', failure),
);

void main() {
  test('a page of people: the reader\'s parameters, a hidden name read as '
      'none, the cursor of the next page', () async {
    final home = _Home()
      ..answer = _envelope('people', [
        _person('p1', name: 'Ada Lovelace'),
        _person('p2'),
      ], next: 'p2');
    final page = await _adapter(home).people(_a, after: 'p0', query: 'a');
    expect(home.received.single, {
      'p_section': 'people',
      'p_workspace_network_id': _a,
      'p_after_key': 'p0',
      'p_query': 'a',
    });
    expect(page.items.map((p) => p.name), ['Ada Lovelace', null]);
    expect(page.items.first.workspaceRef, _a);
    expect(page.hasMore, isTrue);
    expect(page.nextKey, 'p2');
    expect(page.status, RelationshipStatus.ready);
  });

  test('workspaces and groups decode, a remote workspace named by my fact '
      'or unnamed', () async {
    final home = _Home()
      ..answer = _envelope('workspaces', [
        {'network_id': _a, 'installation_id': 'x', 'workspace_id': 'y', 'permitted_name': null},
        {'network_id': _b, 'installation_id': 'x', 'workspace_id': 'y', 'permitted_name': 'Studio Sud'},
        {'network_id': '$_b-2', 'installation_id': 'x', 'workspace_id': 'y', 'permitted_name': ' '},
      ], status: 'partial');
    final workspaces = await _adapter(home).workspaces();
    expect(workspaces.items.map((w) => w.name), [null, 'Studio Sud', null]);
    expect(workspaces.status, RelationshipStatus.partial);
    expect(home.received.single['p_workspace_network_id'], isNull);

    home.answer = _envelope('groups', [
      {'group_id': 'g1', 'title': 'Floor crew', 'announce_only': true, 'can_write': false},
    ]);
    final groups = await _adapter(home).groups();
    expect(groups.items.single.canWrite, isFalse);
    expect(groups.items.single.announceOnly, isTrue);
    expect(groups.hasMore, isFalse);
  });

  test('a malformed answer is refused as malformed, never an empty page', () async {
    final home = _Home();
    final adapter = _adapter(home);
    for (final bad in <Object?>[
      {..._envelope('people', const []), 'schema_version': 2},
      _envelope('groups', const []),
      {..._envelope('people', const []), 'has_more': true},
      {..._envelope('people', const []), 'items': null},
      {..._envelope('people', const []), 'relationship_status': 'fine'},
      _envelope('people', [{'person_id': 1}]),
    ]) {
      home.answer = bad;
      await expectLater(adapter.people(_a), _refused(DirectoryFailure.malformed));
    }
  });

  test('each refusal is named; a home without the reader is unsupported', () async {
    final home = _Home();
    final adapter = _adapter(home);
    for (final (status, code, failure) in [
      (404, 'PGRST202', DirectoryFailure.unsupported),
      (403, '42501', DirectoryFailure.forbidden),
      (400, '22023', DirectoryFailure.invalid),
    ]) {
      home.refusal = (status: status, code: code);
      await expectLater(adapter.groups(), _refused(failure));
    }
    home.refusal = (status: 500, code: 'XX000');
    await expectLater(adapter.groups(), throwsA(isA<PostgrestException>()));
  });

  test('only a transport failure is retried', () {
    expect(
      personalDirectoryRetry(0, const DirectoryRefused(DirectoryFailure.forbidden)),
      isNull,
    );
    expect(personalDirectoryRetry(0, StateError('offline')), isNotNull);
    expect(personalDirectoryRetry(2, StateError('offline')), isNull);
  });

  test('suggestions: a person once with every shared workspace, a hidden '
      'name never suggested, a remote workspace by its neutral label', () {
    const directory = PersonalDirectory(
      workspaces: [
        DirectoryWorkspace(networkId: _a, name: 'Atelier'),
        DirectoryWorkspace(networkId: _b),
      ],
      people: {
        _a: DirectoryPage(
          items: [
            DirectoryPerson(id: 'p1', workspaceRef: _a, name: 'Ada'),
            DirectoryPerson(id: 'p2', workspaceRef: _a),
          ],
          status: RelationshipStatus.ready,
        ),
        _b: DirectoryPage(
          items: [DirectoryPerson(id: 'p1', workspaceRef: _b, name: 'Ada')],
          status: RelationshipStatus.ready,
        ),
      },
      groups: [],
      status: RelationshipStatus.ready,
    );
    final all = personalRecipients(directory, unnamed: 'Elsewhere');
    expect(all.map((r) => r.id), ['p1']);
    expect(all.single.source, '');
    expect(all.single.workspaces, ['Atelier', 'Elsewhere']);
  });
}
