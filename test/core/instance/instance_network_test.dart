// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2561 L3 -- the wizard's network declaration: the roles and the explicit
// personal home are checked (HTTPS, publishable key, a real personal home
// that understands personal@1, not this instance) BEFORE anything is
// written, and recorded through the two operator functions in that order.
import 'package:deskilo/core/instance/instance_builder.dart';
import 'package:deskilo/core/instance/instance_doctor.dart';
import 'package:deskilo/core/instance/instance_network.dart';
import 'package:deskilo/core/instance/instance_security_checks.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_supabase_management.dart';

const _home = PersonalHomeEndpoint(
  'https://Home.Example/',
  'sb_publishable_home_key_123',
);
const _own = '00000000-0000-4000-8000-000000000001';

PersonalHomeProbe _probe(
  List<String> roles,
  List<String> capabilities, {
  String id = '00000000-0000-4000-8000-0000000000aa',
  List<PersonalHomeEndpoint>? seen,
}) => (home) async {
  seen?.add(home);
  return (roles: roles, capabilities: capabilities, installationId: id);
};

void main() {
  group('verifyInstanceNetwork', () {
    test(
      'combined and personal home record no endpoint and probe nothing',
      () async {
        for (final role in [
          InstanceRoleChoice.combined,
          InstanceRoleChoice.personalHome,
        ]) {
          final seen = <PersonalHomeEndpoint>[];
          expect(
            await verifyInstanceNetwork(
              InstanceNetworkChoice(role, personalHome: _home),
              ownInstallationId: _own,
              probe: _probe(const [], const [], seen: seen),
            ),
            isNull,
          );
          expect(seen, isEmpty);
        }
      },
    );

    test('a workspace host needs a home, an HTTPS origin and a publishable '
        'key', () async {
      Future<void> refused(
        PersonalHomeEndpoint? home,
        InstanceNetworkFault fault,
      ) => expectLater(
        verifyInstanceNetwork(
          InstanceNetworkChoice(
            InstanceRoleChoice.workspaceHost,
            personalHome: home,
          ),
          ownInstallationId: _own,
          probe: _probe(const ['personal_home'], const ['personal@1']),
        ),
        throwsA(
          isA<InstanceNetworkRefused>().having((e) => e.fault, 'fault', fault),
        ),
      );
      await refused(null, InstanceNetworkFault.homeRequired);
      await refused(
        const PersonalHomeEndpoint('', ''),
        InstanceNetworkFault.homeRequired,
      );
      await refused(
        const PersonalHomeEndpoint(
          'http://home.example',
          'sb_publishable_home_key_123',
        ),
        InstanceNetworkFault.homeEndpoint,
      );
      await refused(
        const PersonalHomeEndpoint(
          'https://home.example',
          'sb_secret_abcdefghijklmnop',
        ),
        InstanceNetworkFault.homeEndpoint,
      );
    });

    test('the home must be a personal home that understands personal@1, '
        'and not this instance', () async {
      Future<void> refused(PersonalHomeProbe probe, InstanceNetworkFault f) =>
          expectLater(
            verifyInstanceNetwork(
              const InstanceNetworkChoice(
                InstanceRoleChoice.workspaceHost,
                personalHome: _home,
              ),
              ownInstallationId: _own,
              probe: probe,
            ),
            throwsA(
              isA<InstanceNetworkRefused>().having((e) => e.fault, 'fault', f),
            ),
          );
      await refused(
        _probe(const ['workspace_host'], const ['workspace@1']),
        InstanceNetworkFault.homeNotPersonal,
      );
      await refused(
        _probe(const [], const []),
        InstanceNetworkFault.homeNotPersonal,
      );
      await refused(
        _probe(const ['personal_home'], const ['personal@2']),
        InstanceNetworkFault.homeNotPersonal,
      );
      await refused(
        _probe(const ['personal_home'], const ['personal@1'], id: _own),
        InstanceNetworkFault.homeIsThisInstance,
      );
      await refused(
        (_) async => throw Exception('offline'),
        InstanceNetworkFault.homeUnreachable,
      );
    });

    test('a verified home comes back canonical, as it was probed', () async {
      final seen = <PersonalHomeEndpoint>[];
      final home = await verifyInstanceNetwork(
        const InstanceNetworkChoice(
          InstanceRoleChoice.workspaceHost,
          personalHome: _home,
        ),
        ownInstallationId: _own,
        probe: _probe(
          const ['personal_home'],
          const ['personal@1'],
          seen: seen,
        ),
      );
      expect(home!.url, 'https://home.example');
      expect(seen.single.url, 'https://home.example');
    });
  });

  group('InstanceBuilder.declareNetwork', () {
    test('roles first, then the declaration, quoted', () async {
      final api = FakeSupabaseManagement()
        ..queryRows = const [
          {'id': _own},
        ];
      await InstanceBuilder(api).declareNetwork(
        'ref1',
        const InstanceNetworkChoice(
          InstanceRoleChoice.workspaceHost,
          personalHome: PersonalHomeEndpoint(
            'https://home.example',
            "sb_publishable_o'key_123",
          ),
        ),
        probe: _probe(const ['personal_home'], const ['personal@1']),
      );
      expect(
        api.sql['ref1']!.single,
        "select public.operator_set_installation_roles(array['workspace_host']::text[]);\n"
        "select public.operator_set_personal_home('endpoint', 'https://home.example', 'sb_publishable_o''key_123');\n",
      );
    });

    test(
      'combined keeps today\'s behaviour: both roles, nothing declared',
      () async {
        final api = FakeSupabaseManagement()
          ..queryRows = const [
            {'id': _own},
          ];
        await InstanceBuilder(api).declareNetwork(
          'ref1',
          const InstanceNetworkChoice(InstanceRoleChoice.combined),
          probe: _probe(const [], const []),
        );
        expect(
          api.sql['ref1']!.single,
          contains("array['personal_home', 'workspace_host']"),
        );
        expect(
          api.sql['ref1']!.single,
          contains("operator_set_personal_home('unset')"),
        );
      },
    );

    test(
      'a refused home writes nothing and is a typed network failure',
      () async {
        final api = FakeSupabaseManagement()
          ..queryRows = const [
            {'id': _own},
          ];
        await expectLater(
          InstanceBuilder(api).declareNetwork(
            'ref1',
            const InstanceNetworkChoice(
              InstanceRoleChoice.workspaceHost,
              personalHome: _home,
            ),
            probe: _probe(const ['workspace_host'], const ['workspace@1']),
          ),
          throwsA(
            isA<InstanceStepFailure>()
                .having((e) => e.item, 'item', 'network')
                .having((e) => e.message, 'message', 'homeNotPersonal'),
          ),
        );
        expect(api.sql['ref1'], isNull);
      },
    );
  });

  group('the doctor reads the declaration against the roles', () {
    Map<String, Object?> row(List<String> roles, String? kind, [String? url]) =>
        {
          'roles': roles,
          'personal_home_kind': kind,
          'personal_home_url': url,
          'workspaces': 0,
          'members': 0,
        };

    test('a workspace host that names no home is the alarm', () {
      final f = checkInstallationRoles([
        row(['workspace_host'], 'unset'),
      ]);
      expect(f.last.level, DoctorLevel.alarm);
      expect(f.last.title, 'Personal home');
    });

    test('a contradiction is the alarm; a coherent one is fine', () {
      expect(
        checkInstallationRoles([
          row(['workspace_host'], 'self'),
        ]).last.level,
        DoctorLevel.alarm,
      );
      expect(
        checkInstallationRoles([
          row(
            ['personal_home', 'workspace_host'],
            'endpoint',
            'https://h.example',
          ),
        ]).last.level,
        DoctorLevel.alarm,
      );
      final ok = checkInstallationRoles([
        row(['workspace_host'], 'endpoint', 'https://h.example'),
      ]).last;
      expect(ok.level, DoctorLevel.ok);
      expect(ok.detail, 'https://h.example');
    });

    test('a schema before the declaration adds no finding', () {
      expect(
        checkInstallationRoles([
          row(['workspace_host'], null),
        ]),
        hasLength(1),
      );
    });
  });
}
