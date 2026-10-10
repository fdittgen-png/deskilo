// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2343 — the global directory lives on the reference deployment, whatever
// server the device uses. A link is written THERE (through the device's
// own session when it uses that server, else the account's connection to
// it), a server's standing is read before anything is written, and
// Discover lists the directory, every linked server and the device's own.
import 'dart:convert';

import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/connected_installations.dart';
import 'package:deskilo/core/demo/data/connected_installations.dart';
import 'package:deskilo/core/public_network/data/public_network_client.dart';
import 'package:deskilo/features/directory/data/supabase_directory_participant_repository.dart';
import 'package:deskilo/features/directory/data/supabase_public_discovery_repository.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const directory = BackendEndpoint(
  'https://directory.example',
  'sb_publishable_directory_key',
);
const own = BackendEndpoint('https://own.example', 'sb_publishable_own_key');
const other = BackendEndpoint(
  'https://other.example',
  'sb_publishable_other_key',
);

/// The account's connections, recording which server each call went to.
class _Registry extends FakeConnectedInstallations {
  _Registry(this.clientFor);
  final SupabaseClient Function(String origin) clientFor;
  final used = <String>[];
  @override
  Future<T> use<T>(String source, Future<T> Function(SupabaseClient) action) {
    used.add(source);
    return action(clientFor(source));
  }
}

void main() {
  late List<http.Request> seen;
  late List<Map<String, Object?>> sources;
  late Set<String> down;

  http.Client transport() => MockClient((r) async {
    seen.add(r);
    if (down.contains(r.url.origin)) {
      return http.Response('{"message":"down"}', 503, request: r);
    }
    final Object body;
    if (r.url.path.endsWith('/public_network_descriptor')) {
      return http.Response(
        '{"code":"PGRST202","message":"not found"}',
        404,
        headers: {'content-type': 'application/json'},
        request: r,
      );
    } else if (r.url.path.endsWith('/public_directory_sources')) {
      final q = r.url.queryParameters;
      final from = int.parse(q['offset'] ?? '0');
      body = sources.skip(from).take(int.parse(q['limit'] ?? '20')).toList();
    } else if (r.url.path.endsWith('/public_workspace_cards')) {
      body = [
        {
          'workspace_id': '00000000-0000-4000-8000-000000002343',
          'name': 'Space on ${r.url.host}',
          'updated_at': '2026-10-10T09:00:00+00:00',
          'document': {
            'name': 'Space on ${r.url.host}',
            'host_type': 'company',
          },
        },
      ];
    } else {
      body = '';
    }
    return http.Response(
      body is String ? body : jsonEncode(body),
      body is String ? 204 : 200,
      headers: {'content-type': 'application/json'},
      request: r,
    );
  });

  SupabaseClient client(String origin, String key) => SupabaseClient(
    origin,
    key,
    httpClient: transport(),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  SupabaseDirectoryParticipantRepository participant(
    BackendEndpoint device, {
    _Registry? registry,
  }) => SupabaseDirectoryParticipantRepository(
    client(device.url, device.key),
    registry,
    negotiator: PublicNetworkNegotiator(transport: transport),
    transport: transport,
    directory: directory,
  );

  List<http.Request> registrations() => [
    for (final r in seen)
      if (r.url.path.endsWith('/rpc/register_public_directory')) r,
  ];

  setUp(() {
    seen = [];
    sources = [];
    down = {};
  });

  group('linking', () {
    test('from another server, the link is written on the directory, '
        'through the account\'s connection to it', () async {
      final registry = _Registry((origin) => client(origin, directory.key));
      await participant(own, registry: registry).register(other.url, other.key);
      expect(registry.used, [directory.url]);
      expect(registrations().single.url.origin, directory.url);
      expect(jsonDecode(registrations().single.body), {
        'p_origin': other.url,
        'p_key': other.key,
      });
    });

    test(
      'on the directory\'s own server, the device\'s session writes it',
      () async {
        final registry = _Registry((origin) => client(origin, directory.key));
        await participant(
          directory,
          registry: registry,
        ).register(other.url, other.key);
        expect(registry.used, isEmpty);
        expect(registrations().single.url.origin, directory.url);
      },
    );

    test('without an account on the directory\'s server, nothing is written '
        'and the outcome says so', () async {
      await expectLater(
        participant(own).register(other.url, other.key),
        throwsA(
          isA<ConnectionFailure>().having(
            (f) => f.reason,
            'reason',
            ConnectionFailureReason.notConnected,
          ),
        ),
      );
      expect(registrations(), isEmpty);
    });

    test('a server that does not answer is never registered', () async {
      down.add(other.url);
      final registry = _Registry((origin) => client(origin, directory.key));
      await expectLater(
        participant(own, registry: registry).register(other.url, other.key),
        throwsA(anything),
      );
      expect(registrations(), isEmpty);
    });
  });

  group('where a server stands', () {
    test('the directory\'s own server carries it', () async {
      expect(
        await participant(own).linkState(directory.url, directory.key),
        DirectoryLinkState.directory,
      );
    });

    test('a server that does not answer cannot be linked yet', () async {
      down.add(other.url);
      expect(
        await participant(own).linkState(other.url, other.key),
        DirectoryLinkState.unreachable,
      );
    });

    test(
      'a server that answers is linkable until it is listed, on any page',
      () async {
        expect(
          await participant(own).linkState(other.url, other.key),
          DirectoryLinkState.linkable,
        );
        sources = [
          for (var i = 0; i < 20; i++)
            {
              'origin': 'https://a$i.example',
              'publishable_key': 'sb_publishable_$i',
            },
          {'origin': other.url, 'publishable_key': other.key},
        ];
        expect(
          await participant(own).linkState(other.url, other.key),
          DirectoryLinkState.linked,
        );
      },
    );
  });

  test('Discover reads the directory, every linked server and the device\'s '
      'own server', () async {
    sources = [
      {'origin': other.url, 'publishable_key': other.key},
    ];
    final page = await SupabasePublicDiscoveryRepository(
      origin: directory.url,
      publishableKey: directory.key,
      local: own,
      transport: transport,
    ).search('');
    expect(page.workspaces.map((w) => w.source).toSet(), {
      directory.url,
      other.url,
      own.url,
    });
    expect(
      seen
          .where((r) => r.url.path.endsWith('/public_directory_sources'))
          .map((r) => r.url.origin),
      [directory.url],
      reason: 'the list of servers is the directory\'s',
    );
  });
}
