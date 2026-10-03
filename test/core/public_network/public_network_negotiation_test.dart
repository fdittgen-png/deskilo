// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1847 B — negotiation per operation, against fixtures labelled by origin:
// `captured` ones were read from a real server or recorded from the
// released client; `synthetic` ones stand in for servers that do not exist
// yet (no protocol 2 and no retired version has ever shipped). Unknown
// mandatory terms, capabilities and versions refuse the AFFECTED action
// with a typed outcome; everything the client can still speak keeps
// working. The transport half goes through the real Supabase client.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/public_network/data/public_network_client.dart';
import 'package:deskilo/core/public_network/public_network_negotiator.dart';
import 'package:deskilo/core/public_network/public_network_operations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> fixture(String name) => jsonDecode(
  File('test/fixtures/public_network/$name.json').readAsStringSync(),
) as Map<String, dynamic>;

PublicServerProfile server(String name) =>
    readPublicDescriptor(fixture(name)['descriptor']);

const apply = PublicNetworkOperations.workspaceProfileRequest;
const register = PublicNetworkOperations.directorySourcesRegister;

Matcher refused(PublicRefusalReason reason) => throwsA(
  isA<PublicActionRefusal>().having((r) => r.reason, 'reason', reason),
);

void main() {
  test('every fixture says whether it was captured or is synthetic', () {
    for (final f in Directory('test/fixtures/public_network').listSync()) {
      final kind =
          ((jsonDecode((f as File).readAsStringSync()) as Map)['provenance']
              as Map)['kind'];
      expect(kind, anyOf('captured', 'synthetic'), reason: f.path);
    }
  });

  group('the current server (captured descriptor)', () {
    test('both participant operations negotiate version 1 and its header', () {
      final s = server('descriptor_current');
      expect(negotiatePublicOperation(s, apply).version, 1);
      expect(
        negotiatePublicOperation(s, apply).header,
        'workspace.profile.request@1',
      );
      expect(negotiatePublicOperation(s, register).version, 1);
    });

    test('the descriptor this client reads equals the one the contract '
        'generates', () {
      final s = server('descriptor_current') as PublicNegotiatingServer;
      expect(s.offers.keys.toSet(), {
        for (final op in publicNetworkOperations.values)
          if (op.surface.name != 'management') op.id,
      });
    });
  });

  test('a server from before negotiation (captured PGRST202) is the baseline: '
      'version 1 of every baseline operation', () {
    const s = PublicServerProfile.baseline();
    expect(negotiatePublicOperation(s, apply).version, 1);
    expect(negotiatePublicOperation(s, register).version, 1);
    expect(fixture('legacy_server_no_descriptor')['body']['code'], 'PGRST202');
  });

  group('a synthetic newer server', () {
    test('the highest COMMON version is taken, not the server\'s highest', () {
      expect(
        negotiatePublicOperation(
          server('synthetic_newer_server'),
          apply,
        ).version,
        1,
      );
    });

    test('an operation requiring a capability this client does not know is '
        'refused; the other one is not', () {
      final s = server('synthetic_newer_server');
      expect(
        () => negotiatePublicOperation(s, register),
        refused(PublicRefusalReason.capabilityUnknown),
      );
      expect(negotiatePublicOperation(s, apply).version, 1);
    });

    test('optional additions (an unknown operation, a lifecycle note, a '
        'top-level extension) are ignored', () {
      final s = server('synthetic_newer_server') as PublicNegotiatingServer;
      expect(s.offers.containsKey('visit.quote.accept'), isTrue);
      expect(s.offers['workspace.profile.request']!.lifecycle?.terms, isEmpty);
    });
  });

  test('a retired version (synthetic sunset) refuses only that operation', () {
    final s = server('synthetic_retired_v1');
    expect(
      () => negotiatePublicOperation(s, apply),
      refused(PublicRefusalReason.versionUnsupported),
    );
    expect(negotiatePublicOperation(s, register).version, 1);
  });

  test('an unknown mandatory lifecycle term (synthetic #1850 seam) makes that '
      'one operation unavailable, never the others', () {
    final s = server('synthetic_unknown_lifecycle');
    expect(
      () => negotiatePublicOperation(s, apply),
      refused(PublicRefusalReason.termUnknown),
    );
    expect(negotiatePublicOperation(s, register).version, 1);
  });

  test('an unknown mandatory term in the whole descriptor refuses every '
      'negotiated action', () {
    final s = server('synthetic_unknown_required_term');
    expect(
      () => negotiatePublicOperation(s, apply),
      refused(PublicRefusalReason.termUnknown),
    );
    expect(
      () => negotiatePublicOperation(s, register),
      refused(PublicRefusalReason.termUnknown),
    );
  });

  test('a protocol this client does not speak refuses, by name', () {
    final s = readPublicDescriptor({
      ...fixture('descriptor_current')['descriptor'] as Map<String, dynamic>,
      'protocol_versions': [2],
    });
    expect(
      () => negotiatePublicOperation(s, apply),
      refused(PublicRefusalReason.protocolUnsupported),
    );
  });

  test('an operation the server does not list is unavailable there', () {
    final s = readPublicDescriptor({
      ...fixture('descriptor_current')['descriptor'] as Map<String, dynamic>,
      'operations': [
        {
          'id': 'directory.sources.register',
          'versions': [1],
        },
      ],
    });
    expect(
      () => negotiatePublicOperation(s, apply),
      refused(PublicRefusalReason.operationUnavailable),
    );
  });

  group('through the real client', () {
    const origin = 'https://target.example';
    const key = 'sb_publishable_target_test_key';
    late List<http.Request> seen;

    PublicNetworkNegotiator negotiator(
      http.Response Function(http.Request) a,
    ) => PublicNetworkNegotiator(
      transport: () => MockClient((r) async {
        seen.add(r);
        final res = a(r);
        return http.Response(
          res.body,
          res.statusCode,
          headers: {'content-type': 'application/json'},
          request: r,
        );
      }),
    );

    setUp(() => seen = []);

    test(
      'reads the descriptor anonymously on the target origin, once',
      () async {
        final n = negotiator(
          (_) => http.Response(
            jsonEncode(fixture('descriptor_current')['descriptor']),
            200,
          ),
        );
        expect((await n.negotiate(origin, key, apply)).version, 1);
        expect((await n.negotiate(origin, key, register)).version, 1);
        expect(seen, hasLength(1), reason: 'cached per origin');
        expect(
          seen.single.url.toString(),
          '$origin/rest/v1/rpc/public_network_descriptor',
        );
        expect(seen.single.headers['apikey'], key);
        final bearer =
            seen.single.headers['Authorization'] ??
            seen.single.headers['authorization'];
        expect(bearer == null || bearer == 'Bearer $key', isTrue);
      },
    );

    test('the captured legacy answer means the baseline', () async {
      final legacy = fixture('legacy_server_no_descriptor');
      final n = negotiator(
        (_) =>
            http.Response(jsonEncode(legacy['body']), legacy['status'] as int),
      );
      expect((await n.negotiate(origin, key, apply)).version, 1);
    });

    test(
      'an outage refuses the action as unreachable and is not cached',
      () async {
        var down = true;
        final n = negotiator(
          (_) => down
              ? http.Response('{"message":"upstream"}', 503)
              : http.Response(
                  jsonEncode(fixture('descriptor_current')['descriptor']),
                  200,
                ),
        );
        await expectLater(
          n.negotiate(origin, key, apply),
          refused(PublicRefusalReason.unreachable),
        );
        down = false;
        expect((await n.negotiate(origin, key, apply)).version, 1);
      },
    );

    test('forget() makes the next action read the descriptor again', () async {
      final n = negotiator(
        (_) => http.Response(
          jsonEncode(fixture('descriptor_current')['descriptor']),
          200,
        ),
      );
      await n.negotiate(origin, key, apply);
      n.forget(origin);
      await n.negotiate(origin, key, apply);
      expect(seen, hasLength(2));
    });
  });
}
