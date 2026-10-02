// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1847 — the MANAGEMENT interface through the real Supabase client over a
// recorded transport: it calls exactly the contract's RPCs with exactly its
// parameters, refuses an input key the contract does not list before any
// request leaves, and reads the save's answer with the PUBLIC projection,
// so the owner's preview cannot show a field a visitor would not see.
import 'dart:convert';

import 'package:deskilo/core/public_network/public_network_codec.dart';
import 'package:deskilo/core/public_network/public_network_operations.dart';
import 'package:deskilo/features/directory/data/supabase_publication_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const workspace = '00000000-0000-4000-8000-0000000018d1';

void main() {
  late List<http.Request> seen;
  late Object? answer;

  SupabasePublicationRepository repository() => SupabasePublicationRepository(
    SupabaseClient(
      'https://home.example',
      'sb_publishable_home_test_key',
      httpClient: MockClient((request) async {
        seen.add(request);
        return http.Response(
          jsonEncode(answer),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    ),
  );

  setUp(() {
    seen = [];
    answer = null;
  });

  test(
    'ownPage calls the contract\'s RPC and keeps the draft fields',
    () async {
      answer = {
        'published': false,
        'document': {
          'host_type': 'person',
          'description': 'Draft text',
          'name': 'Mine',
          'contacts': <Object>[],
        },
      };
      final page = await repository().ownPage(workspace);
      expect(page['published'], isFalse);
      expect((page['document']! as Map)['description'], 'Draft text');
      final call = seen.single;
      expect(
        call.url.path,
        '/rest/v1/rpc/${PublicNetworkOperations.publicationPageRead.rpc}',
      );
      expect(jsonDecode(call.body), {'p_workspace': workspace});
    },
  );

  test('an unsaved page reads as unpublished and empty', () async {
    answer = {'published': false, 'document': <String, Object?>{}};
    expect(await repository().ownPage(workspace), {
      'published': false,
      'document': <String, Object?>{},
    });
  });

  test('savePage sends the contract\'s parameters and answers the PUBLIC '
      'projection', () async {
    answer = {
      'name': 'Mine',
      'host_type': 'company',
      'description': 'Open to all',
      'invite_code': 'CANARY-INVITE',
      'contacts': <Object>[],
    };
    final preview = await repository().savePage(workspace, {
      'host_type': 'company',
      'description': 'Open to all',
    }, true);
    expect(preview['description'], 'Open to all');
    expect('$preview', isNot(contains('CANARY')));
    final call = seen.single;
    expect(
      call.url.path,
      '/rest/v1/rpc/${PublicNetworkOperations.publicationPageSave.rpc}',
    );
    expect(
      (jsonDecode(call.body) as Map).keys.toSet(),
      PublicNetworkOperations.publicationPageSave.params.keys.toSet(),
    );
  });

  test('#2086 ownPage keeps which inherited fields follow the workspace '
      'information', () async {
    answer = {
      'published': true,
      'document': {'host_type': 'company', 'address': '1 Local Street'},
      'following': {'host_type': true, 'address': false, 'secret': true},
    };
    final page = await repository().ownPage(workspace);
    expect(page['following'], {'host_type': true, 'address': false});
  });

  test('#2086 resetPage calls the contract\'s RPC with the named fields, or '
      'null for all, and reads the PublicationPage answer', () async {
    answer = {
      'published': false,
      'document': {'address': '1 Local Street', 'invite_code': 'CANARY'},
      'following': {'host_type': true, 'address': true},
    };
    final page = await repository().resetPage(workspace, fields: {'address'});
    expect(page['published'], isFalse);
    expect('$page', isNot(contains('CANARY')));
    await repository().resetPage(workspace);
    expect(
      seen.map((r) => r.url.path).toSet(),
      {'/rest/v1/rpc/${PublicNetworkOperations.publicationPageReset.rpc}'},
    );
    expect(jsonDecode(seen.first.body), {
      'p_workspace': workspace,
      'p_fields': ['address'],
    });
    expect(jsonDecode(seen.last.body), {
      'p_workspace': workspace,
      'p_fields': null,
    });
    expect(
      (jsonDecode(seen.last.body) as Map).keys.toSet(),
      PublicNetworkOperations.publicationPageReset.params.keys.toSet(),
    );
  });

  test('#2086 a save without the inherited fields is a valid input: they '
      'follow the workspace information', () async {
    answer = {'name': 'Mine', 'host_type': 'association'};
    await repository().savePage(workspace, {'description': 'Desks'}, true);
    expect(
      ((jsonDecode(seen.single.body) as Map)['p_document'] as Map).keys,
      ['description'],
    );
  });

  test('an input key the contract does not list is refused before any '
      'request', () async {
    await expectLater(
      repository().savePage(workspace, {
        'host_type': 'company',
        'internal_note': 'never public',
      }, false),
      throwsA(isA<PublicContractRefusal>()),
    );
    expect(seen, isEmpty);
  });
}
