// SPDX-License-Identifier: AGPL-3.0-or-later
// #2562 C2c -- the personal home's list of enrolled workspace hosts, read
// strictly, and the one decision whether a chosen host may be used now.
import 'package:deskilo/features/workspace/domain/workspace_host.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _host(String c, {String state = 'available'}) => {
      'installation_id': 'inst-$c',
      'origin': 'https://w-$c.example',
      'publishable_key': 'sb_publishable_w${c}_key',
      'state': state,
    };

void main() {
  group('the answer', () {
    test('reads each host with its state, in order', () {
      final hosts = WorkspaceHosts.parse({
        'here_hosts': false,
        'hosts': [
          _host('a'),
          _host('b', state: 'not_accepting'),
          _host('c', state: 'unverified'),
        ],
      });
      expect(hosts.hereHosts, isFalse);
      expect([for (final h in hosts.hosts) '${h.host} ${h.state.name}'], [
        'w-a.example available',
        'w-b.example notAccepting',
        'w-c.example unverified',
      ]);
      expect(hosts.byId('inst-a')?.publishableKey, 'sb_publishable_wa_key');
    });

    test('a malformed answer is refused, never a shorter list', () {
      for (final bad in <Object?>[
        null,
        <Object?>[],
        {'hosts': <Object?>[]},
        {'here_hosts': true, 'hosts': [_host('a', state: 'revoked')]},
        {'here_hosts': true, 'hosts': [{..._host('a'), 'origin': 'http://w-a.example'}]},
        {'here_hosts': true, 'hosts': [{..._host('a'), 'origin': 'https://w-a.example/path'}]},
        {'here_hosts': true, 'hosts': [{..._host('a'), 'publishable_key': ''}]},
      ]) {
        expect(() => WorkspaceHosts.parse(bad), throwsA(isA<Exception>()),
            reason: '$bad');
      }
    });
  });

  group('deciding a chosen host', () {
    final fresh = WorkspaceHosts.parse({
      'here_hosts': true,
      'hosts': [
        _host('a'),
        _host('b', state: 'not_accepting'),
        _host('c', state: 'unverified'),
      ],
    });
    const atA = (source: 'https://w-a.example', installationId: 'inst-a');

    HostRefusal? refusal(HostReadiness r) => r is HostRefused ? r.reason : null;

    test('enrolled, accepting and connected to it: ready on that connection',
        () {
      final r = decideHost(fresh, 'inst-a', [atA]);
      expect(r, isA<HostReady>());
      expect((r as HostReady).source, 'https://w-a.example');
    });

    test('not connected yet: the identity sign-in comes first', () {
      expect(decideHost(fresh, 'inst-a', const []), isA<HostNeedsConnection>());
    });

    test('each refusal is typed', () {
      expect(refusal(decideHost(fresh, 'inst-gone', [atA])), HostRefusal.revoked);
      expect(refusal(decideHost(fresh, 'inst-b', [atA])), HostRefusal.notAccepting);
      expect(refusal(decideHost(fresh, 'inst-c', [atA])), HostRefusal.unverified);
      expect(
          refusal(decideHost(fresh, 'inst-a',
              const [(source: 'https://w-a.example', installationId: 'inst-x')])),
          HostRefusal.unverified,
          reason: 'its address answers as another installation');
      expect(
          refusal(decideHost(fresh, 'inst-a',
              const [(source: 'https://w-z.example', installationId: 'inst-a')])),
          HostRefusal.unverified,
          reason: 'the installation answers at another address');
    });
  });
}
