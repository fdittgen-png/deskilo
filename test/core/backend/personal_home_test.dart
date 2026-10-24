// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2561 L3 -- the directory home comes from the installation's own
// declaration, read through the personal client, never from a constant or a
// selected workspace. A combined installation that declared nothing keeps
// the reference deployment (today's behaviour); a workspace host that named
// no home, or a declaration its roles contradict, is a typed refusal with no
// server read in its place. The production discovery consumer reads the
// declared home.
import 'dart:convert';

import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/context_client_providers.dart';
import 'package:deskilo/core/backend/personal_home.dart';
import 'package:deskilo/core/backend/personal_home_providers.dart';
import 'package:deskilo/features/directory/data/supabase_public_discovery_repository.dart';
import 'package:deskilo/features/directory/providers/directory_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _self = BackendEndpoint(
  'https://self.example',
  'sb_publishable_self_key',
);
const _ref = BackendEndpoint('https://ref.example', 'sb_publishable_ref_key_1');
const _home = BackendEndpoint(
  'https://home.example',
  'sb_publishable_home_key',
);

PersonalHomeDeclaration _d(
  List<String> roles,
  PersonalHomeKind kind, [
  BackendEndpoint? endpoint,
]) => PersonalHomeDeclaration(roles: roles, kind: kind, endpoint: endpoint);

Matcher _refused(PersonalHomeFault fault) => throwsA(
  isA<PersonalHomeUnavailable>().having((e) => e.fault, 'fault', fault),
);

/// One installation that answers its identity row and records every origin
/// it was asked at.
class _Server {
  _Server(this.identity, {this.error});
  final Map<String, Object?> identity;
  final Map<String, Object?>? error;
  final seen = <String>[];

  http.Client transport() => MockClient((r) async {
    seen.add('${r.url.origin}${r.url.path}');
    if (r.url.path == '/rest/v1/installation_identity') {
      if (error != null) {
        return http.Response(
          jsonEncode(error),
          400,
          headers: {'content-type': 'application/json'},
          request: r,
        );
      }
      return http.Response(
        jsonEncode(identity),
        200,
        headers: {'content-type': 'application/json'},
        request: r,
      );
    }
    if (r.url.path == '/rest/v1/public_directory_sources') {
      return http.Response(
        '[]',
        200,
        headers: {'content-type': 'application/json'},
        request: r,
      );
    }
    return http.Response('{}', 404, request: r);
  });

  SupabaseClient client(BackendEndpoint at) => SupabaseClient(
    at.url,
    at.key,
    httpClient: transport(),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
}

void main() {
  group('directoryHomeOf', () {
    test('nothing declared on a personal home keeps the reference', () {
      for (final roles in [
        const <String>[],
        ['personal_home'],
        ['personal_home', 'workspace_host'],
      ]) {
        expect(
          directoryHomeOf(
            _d(roles, PersonalHomeKind.unset),
            self: _self,
            reference: _ref,
          ).url,
          _ref.url,
        );
      }
    });

    test('a workspace host that names no home is refused, not defaulted', () {
      expect(
        () => directoryHomeOf(
          _d(['workspace_host'], PersonalHomeKind.unset),
          self: _self,
          reference: _ref,
        ),
        _refused(PersonalHomeFault.missing),
      );
    });

    test('self is the installation itself, only on a personal home', () {
      expect(
        directoryHomeOf(
          _d(['personal_home'], PersonalHomeKind.self),
          self: _self,
          reference: _ref,
        ).url,
        _self.url,
      );
      expect(
        () => directoryHomeOf(
          _d(['workspace_host'], PersonalHomeKind.self),
          self: _self,
          reference: _ref,
        ),
        _refused(PersonalHomeFault.contradictory),
      );
    });

    test('an endpoint is used only by a host that is not a home, only when '
        'it is an HTTPS origin with a publishable key', () {
      expect(
        directoryHomeOf(
          _d(
            ['workspace_host'],
            PersonalHomeKind.endpoint,
            const BackendEndpoint(
              'https://Home.Example/',
              'sb_publishable_home_key',
            ),
          ),
          self: _self,
          reference: _ref,
        ).url,
        'https://home.example',
      );
      expect(
        () => directoryHomeOf(
          _d(
            ['personal_home', 'workspace_host'],
            PersonalHomeKind.endpoint,
            _home,
          ),
          self: _self,
          reference: _ref,
        ),
        _refused(PersonalHomeFault.contradictory),
      );
      expect(
        () => directoryHomeOf(
          _d(
            ['workspace_host'],
            PersonalHomeKind.endpoint,
            const BackendEndpoint(
              'https://home.example',
              'sb_secret_abcdefghijklmn',
            ),
          ),
          self: _self,
          reference: _ref,
        ),
        _refused(PersonalHomeFault.invalid),
      );
    });

    test('an unknown kind is invalid', () {
      expect(
        () => PersonalHomeDeclaration.fromRow({
          'roles': ['workspace_host'],
          'personal_home_kind': 'guess',
        }),
        _refused(PersonalHomeFault.invalid),
      );
    });
  });

  group('readPersonalHomeDeclaration', () {
    test('reads the row of the installation the client talks to', () async {
      final server = _Server({
        'roles': ['workspace_host'],
        'personal_home_kind': 'endpoint',
        'personal_home_url': _home.url,
        'personal_home_key': _home.key,
      });
      final d = await readPersonalHomeDeclaration(server.client(_self));
      expect(d.kind, PersonalHomeKind.endpoint);
      expect(d.endpoint!.url, _home.url);
      expect(server.seen.single, '${_self.url}/rest/v1/installation_identity');
    });

    test('a schema before the declaration reads as legacy; any other '
        'failure is the caller\'s', () async {
      final legacy = _Server(
        const {},
        error: const {
          'code': '42703',
          'message':
              'column installation_identity.personal_home_kind does not exist',
        },
      );
      expect(
        (await readPersonalHomeDeclaration(legacy.client(_self))).kind,
        PersonalHomeKind.unset,
      );
      final broken = _Server(
        const {},
        error: const {'code': '42501', 'message': 'permission denied'},
      );
      await expectLater(
        readPersonalHomeDeclaration(broken.client(_self)),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  group('the directory consumer', () {
    ProviderContainer container(_Server server) {
      final c = ProviderContainer(
        overrides: [
          personalClientProvider.overrideWithValue(server.client(_self)),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test(
      'Discover reads the source list on the DECLARED personal home',
      () async {
        final server = _Server({
          'roles': ['workspace_host'],
          'personal_home_kind': 'endpoint',
          'personal_home_url': _home.url,
          'personal_home_key': _home.key,
        });
        final c = container(server);
        // The provider's own wiring, with the test's transport.
        final discovery = SupabasePublicDiscoveryRepository(
          directoryHome: () =>
              c.listen(directoryHomeProvider.future, (_, _) {}).read(),
          local: _self,
          transport: server.transport,
        );
        final page = await discovery.sources();
        expect(
          server.seen,
          [
            '${_self.url}/rest/v1/installation_identity',
            '${_home.url}/rest/v1/public_directory_sources',
          ],
          reason:
              'the declaration is read on the personal client, the list '
              'on the home it names; the reference is never asked',
        );
        expect(page.sources.map((s) => s.origin), [_home.url, _self.url]);
        expect(
          c.read(publicDiscoveryRepositoryProvider),
          isA<SupabasePublicDiscoveryRepository>(),
        );
      },
    );

    test(
      'a workspace host without a home fails the directory home, typed',
      () async {
        final server = _Server({
          'roles': ['workspace_host'],
          'personal_home_kind': 'unset',
        });
        final c = container(server);
        await expectLater(
          c.listen(directoryHomeProvider.future, (_, _) {}).read(),
          _refused(PersonalHomeFault.missing),
        );
      },
    );
  });
}
