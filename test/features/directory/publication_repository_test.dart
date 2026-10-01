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
