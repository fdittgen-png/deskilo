// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1847 B — the PARTICIPANT interface negotiates before it mutates. Through
// the real Supabase client over a recorded transport: against the current
// server the request names its version; against a server from before
// negotiation (the captured PGRST202) it still goes through; an operation
// this client cannot honour there is refused BEFORE any mutation leaves,
// while the unrelated one still works; and the server's own revalidation
// refusal arrives as the same typed outcome. The released client's request
// (captured) is what the server accepts as the unlabelled version — pgTAP
// 107 proves that half on the database.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/demo/data/connected_installations.dart';
import 'package:deskilo/core/public_network/data/public_network_client.dart';
import 'package:deskilo/core/public_network/public_network_negotiator.dart';
import 'package:deskilo/features/directory/data/supabase_directory_participant_repository.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const origin = 'https://target.example';
const key = 'sb_publishable_target_test_key';
const workspace = PublicWorkspace(
  '00000000-0000-4000-8000-0000001847b1',
  origin,
  key,
  {'name': 'Target office', 'host_type': 'company'},
);

Map<String, dynamic> fixture(String name) => jsonDecode(
  File('test/fixtures/public_network/$name.json').readAsStringSync(),
) as Map<String, dynamic>;

/// The account's session on the target, as the connected registry hands
/// it out — here the same recorded transport.
class _Registry extends FakeConnectedInstallations {
  _Registry(this.client);
  final SupabaseClient client;
  @override
  Future<T> use<T>(String source, Future<T> Function(SupabaseClient) action) =>
      action(client);
}

void main() {
  late List<http.Request> seen;
  late http.Response Function(http.Request) descriptor;
  late http.Response Function(http.Request) mutation;

  MockClient transport() => MockClient((r) async {
    seen.add(r);
    final res = r.url.path.endsWith('/public_network_descriptor')
        ? descriptor(r)
        : r.url.path.contains('/rpc/')
        ? mutation(r)
        : http.Response('[]', 200);
    return http.Response(
      res.body,
      res.statusCode,
      headers: {'content-type': 'application/json'},
      request: r,
    );
  });

  SupabaseDirectoryParticipantRepository repository() {
    final client = SupabaseClient(
      origin,
      key,
      httpClient: transport(),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    return SupabaseDirectoryParticipantRepository(
      client,
      _Registry(client),
      negotiator: PublicNetworkNegotiator(transport: transport),
      transport: transport,
    );
  }

  http.Response serve(String name) =>
      http.Response(jsonEncode(fixture(name)['descriptor']), 200);

  List<http.Request> mutations() => [
    for (final r in seen)
      if (r.url.path.contains('/rpc/') &&
          !r.url.path.endsWith('/public_network_descriptor'))
        r,
  ];

  setUp(() {
    seen = [];
    descriptor = (_) => serve('descriptor_current');
    mutation = (_) => http.Response('', 204);
  });

  test(
    'against the current server, apply negotiates and names its version',
    () async {
      await repository().apply(workspace);
      final call = mutations().single;
      expect(call.url.path, '/rest/v1/rpc/request_public_workspace_profile');
      expect(
        call.headers['x-deskilo-operation'],
        'workspace.profile.request@1',
      );
      expect(jsonDecode(call.body), {'p_workspace': workspace.id});
      expect(
        seen.indexWhere(
          (r) => r.url.path.endsWith('/public_network_descriptor'),
        ),
        lessThan(seen.indexOf(call)),
        reason: 'negotiation happens before the mutation',
      );
    },
  );

  test('the body is the released client\'s captured body: only the version '
      'header is new', () async {
    await repository().apply(workspace);
    final released =
        (fixture('released_client_requests')['requests'] as List).single as Map;
    final call = mutations().single;
    expect(call.url.path, released['path']);
    expect(jsonDecode(call.body), released['body']);
    expect(
      (released['headers'] as Map).containsKey('x-deskilo-operation'),
      isFalse,
    );
  });

  test('a server from before negotiation (captured PGRST202) still takes the '
      'request', () async {
    final legacy = fixture('legacy_server_no_descriptor');
    descriptor = (_) =>
        http.Response(jsonEncode(legacy['body']), legacy['status'] as int);
    await repository().apply(workspace);
    expect(mutations(), hasLength(1));
  });

  test('a retired version (synthetic) is refused BEFORE the mutation; the '
      'unrelated register still works', () async {
    descriptor = (_) => serve('synthetic_retired_v1');
    final repo = repository();
    await expectLater(
      repo.apply(workspace),
      throwsA(
        isA<PublicActionRefusal>()
            .having(
              (r) => r.reason,
              'reason',
              PublicRefusalReason.versionUnsupported,
            )
            .having((r) => r.byServer, 'byServer', isFalse),
      ),
    );
    expect(mutations(), isEmpty, reason: 'nothing was sent');
    await repo.register(origin, key);
    expect(
      mutations().single.url.path,
      '/rest/v1/rpc/register_public_directory',
    );
    expect(
      mutations().single.headers['x-deskilo-operation'],
      'directory.sources.register@1',
    );
  });

  test('an unknown required capability (synthetic newer server) refuses '
      'register, not apply', () async {
    descriptor = (_) => serve('synthetic_newer_server');
    final repo = repository();
    await expectLater(
      repo.register(origin, key),
      throwsA(
        isA<PublicActionRefusal>().having(
          (r) => r.reason,
          'reason',
          PublicRefusalReason.capabilityUnknown,
        ),
      ),
    );
    await repo.apply(workspace);
    expect(
      mutations().single.headers['x-deskilo-operation'],
      'workspace.profile.request@1',
    );
  });

  test('the server\'s revalidation refusal is the same typed outcome, and the '
      'next action asks for the descriptor again', () async {
    mutation = (_) => http.Response(
      jsonEncode({'code': 'P0001', 'message': publicNetworkVersionRefusal}),
      400,
    );
    final repo = repository();
    await expectLater(
      repo.apply(workspace),
      throwsA(
        isA<PublicActionRefusal>()
            .having(
              (r) => r.reason,
              'reason',
              PublicRefusalReason.versionUnsupported,
            )
            .having((r) => r.byServer, 'byServer', isTrue),
      ),
    );
    mutation = (_) => http.Response('', 204);
    await repo.apply(workspace);
    expect(
      seen.where((r) => r.url.path.endsWith('/public_network_descriptor')),
      hasLength(2),
    );
  });

  test(
    'an unreachable descriptor refuses the action; no mutation is sent',
    () async {
      descriptor = (_) => http.Response('{"message":"down"}', 503);
      await expectLater(
        repository().apply(workspace),
        throwsA(
          isA<PublicActionRefusal>().having(
            (r) => r.reason,
            'reason',
            PublicRefusalReason.unreachable,
          ),
        ),
      );
      expect(mutations(), isEmpty);
    },
  );

  test('another refusal (not a version) passes through untouched', () async {
    mutation = (_) => http.Response(
      jsonEncode({'code': 'P0001', 'message': 'workspace not published'}),
      400,
    );
    await expectLater(
      repository().apply(workspace),
      throwsA(isA<PostgrestException>()),
    );
  });
}
