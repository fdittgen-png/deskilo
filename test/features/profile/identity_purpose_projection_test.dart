// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1833 (checkpoint A) — another person's profile reaches the app as a
// purpose projection, never as the `profiles` row.
//
// The directory, the plans, the kiosk, the invoices and the Excel export
// all read space mates through `fetchProfiles`. It used to `select *` the
// table, and the table's policy lets every space mate read the whole row:
// postal address, VAT id, legal id, phone, identity e-mail, document
// language. The fixture below answers the table route exactly as the
// database did for a peer (canaries included) and the RPC route with the
// projection `member_profiles` returns, so a reader that still takes the
// table route fails here. What the database grants to whom is proved in
// supabase/tests/database/104_member_profile_projection.sql; this file
// proves the app asks for the projection, for the right space, and reads
// each field only from the group its purpose names.
import 'dart:convert';

import 'package:deskilo/features/members/providers/directory_providers.dart';
import 'package:deskilo/features/profile/data/supabase_profile_repository.dart';
import 'package:deskilo/features/profile/domain/profile_projection.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fake_profile_repository.dart';
import '../../helpers/mock_providers.dart';

/// What `select * from profiles` answered a space mate (dev, 2026-10-01).
const Map<String, Object?> _tableRow = {
  'id': 'user-2',
  'display_name': 'Peer Person',
  'whatsapp': '+33600001833',
  'address': 'ADDRESS-CANARY',
  'country_code': 'BE',
  'vat_id': 'VAT-CANARY',
  'legal_id': 'LEGAL-CANARY',
  'street': 'STREET-CANARY',
  'phone': 'PHONE-CANARY',
  'email': 'mail-canary@x.test',
  'preferred_locale': 'de',
};

/// What `member_profiles` answers the same space mate.
const Map<String, Object?> _communityRow = {
  'id': 'user-2',
  'purposes': ['community'],
  'community': {
    'display_name': 'Peer Person',
    'avatar_path': 'user-2/avatar',
    'whatsapp': '+33600001833',
    'status_text': 'Here today',
    'last_seen_at': '2026-10-01T08:00:00Z',
  },
};

/// What it answers a holder of viewPersonalData / issueInvoices.
const Map<String, Object?> _operationalRow = {
  'id': 'user-2',
  'purposes': ['community', 'operational'],
  'community': {'display_name': 'Peer Person'},
  'operational': {
    'courtesy': 'mrs',
    'first_name': 'Ada',
    'last_name': 'Peer',
    'company': '',
    'street': '1 rue Canary',
    'postal_code': '34120',
    'city': 'Pézenas',
    'country_code': 'FR',
    'phone': '+33400000000',
    'email': 'ada@example.test',
    'vat_id': 'FR00123456789',
    'legal_id': '',
    'address': 'legacy block',
    'preferred_locale': 'de',
  },
};

typedef _Call = ({String path, Object? body});

({SupabaseClient client, List<_Call> calls}) _fixture(Object rpcAnswer) {
  final calls = <_Call>[];
  final client = SupabaseClient(
    'https://canonical.example',
    'test-key',
    httpClient: MockClient((request) async {
      calls.add((
        path: request.url.path,
        body: request.body.isEmpty ? null : jsonDecode(request.body),
      ));
      final Object answer = request.url.path == '/rest/v1/profiles'
          ? [_tableRow]
          : rpcAnswer;
      return http.Response(
        jsonEncode(answer),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }),
  );
  return (client: client, calls: calls);
}

void main() {
  test('a space mate read carries no billing identity', () async {
    final f = _fixture([_communityRow]);
    addTearDown(f.client.dispose);

    final peer = (await SupabaseProfileRepository(
      f.client,
    ).fetchProfiles('ws-1', ['user-2'])).single;

    expect(peer.displayName, 'Peer Person', reason: 'the positive control');
    expect(peer.whatsappUri, isNotNull);
    expect(peer.statusText, 'Here today');
    expect(peer.hasAvatar, isTrue);
    expect(
      [
        peer.address,
        peer.vatId,
        peer.countryCode,
        peer.preferredLocale,
        peer.identity.legalId,
        peer.identity.street,
        peer.identity.phone,
        peer.identity.email,
      ],
      everyElement(''),
      reason: 'none of the table row\'s private canaries may arrive',
    );
    expect(f.calls.map((c) => c.path), [
      '/rest/v1/rpc/member_profiles',
    ], reason: 'the row itself is never selected');
    expect(f.calls.single.body, {
      'p_workspace_id': 'ws-1',
      'p_user_ids': ['user-2'],
    });
  });

  test('the operational group fills the identity documents print', () async {
    final f = _fixture([_operationalRow]);
    addTearDown(f.client.dispose);

    final member = (await SupabaseProfileRepository(
      f.client,
    ).fetchProfiles('ws-1', ['user-2'])).single;

    expect(member.vatId, 'FR00123456789');
    expect(member.countryCode, 'FR');
    expect(member.address, 'legacy block');
    expect(member.preferredLocale, 'de');
    expect(member.fullName, 'Ada PEER');
    expect(member.identity.city, 'Pézenas');
    expect(member.displayName, 'Peer Person');
  });

  test('empty ids and an empty space ask nothing', () async {
    final f = _fixture(const <Object>[]);
    addTearDown(f.client.dispose);
    final repo = SupabaseProfileRepository(f.client);

    expect(await repo.fetchProfiles('ws-1', ['']), isEmpty);
    expect(await repo.fetchProfiles('', ['user-2']), isEmpty);
    expect(f.calls, isEmpty);
  });

  group('profileFromProjection', () {
    test('reads a field only from the group its purpose names', () {
      final profile = profileFromProjection({
        'id': 'user-2',
        'purposes': ['community'],
        // A private field at the top level, and one inside the wrong
        // group: neither is read.
        'address': 'TOP-LEVEL-CANARY',
        'community': {
          'display_name': 'Peer Person',
          'vat_id': 'MISPLACED-CANARY',
          'pin_hash': r'$2a$10$canary',
        },
      });
      expect(profile.displayName, 'Peer Person');
      expect(profile.address, '');
      expect(profile.vatId, '');
    });

    test('a group without its purpose, or a purpose without its group, '
        'grants nothing', () {
      final unlisted = profileFromProjection({
        'id': 'user-2',
        'purposes': ['community'],
        'community': {'display_name': 'Peer Person'},
        'operational': {'vat_id': 'UNLISTED-CANARY'},
      });
      expect(unlisted.vatId, '');
      expect(
        projectionPurposes({
          'id': 'user-2',
          'purposes': ['community', 'operational'],
          'community': {'display_name': 'Peer Person'},
        }),
        {ProfilePurpose.community},
      );
    });

    test('every purpose names its fields, and no field is in two', () {
      final all = [for (final fields in profilePurposeFields.values) ...fields];
      expect(profilePurposeFields.keys.toSet(), ProfilePurpose.values.toSet());
      expect(all.toSet().length, all.length);
      expect(all, isNot(contains('pin_hash')));
    });
  });

  test(
    'the directory asks as members of the space the ids came from',
    () async {
      final profile = FakeProfileRepository();
      const member = Member(
        id: 'member-1',
        workspaceId: 'ws-7',
        userId: 'user-1',
        isAdmin: false,
        isOwner: false,
        status: MemberStatus.active,
      );
      final container = ProviderContainer(
        overrides: [
          ...standardTestOverrides(profile: profile),
          workspaceMembersProvider.overrideWith((ref) async => const [member]),
        ],
      );
      addTearDown(container.dispose);

      await container.read(memberProfilesProvider.future);

      expect(profile.requestedWorkspaces, ['ws-7']);
      expect(profile.requestedIds, [
        ['user-1'],
      ]);
    },
  );
}
