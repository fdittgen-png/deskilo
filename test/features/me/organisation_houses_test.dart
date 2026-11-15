// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4006 — an organisation's houses on Me and in the chip. Me groups them
// under the organisation's name, the head first and then by country, and a
// business outside the organisation stays where the person put it; inside a
// house, the chip lists the organisation's other houses and nothing else.
import 'package:deskilo/app/shell/house_switch.dart';
import 'package:deskilo/app/shell/space_chip.dart';
import 'package:deskilo/core/storage/space_prefs_store.dart';
import 'package:deskilo/features/me/application/me_spaces_layout.dart';
import 'package:deskilo/features/workspace/domain/organisation.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/organisation_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

Workspace _space(String id, String name, String country, String currency) =>
    Workspace(
      id: id,
      name: name,
      countryCode: country,
      currencyCode: currency,
      timezone: 'Europe/Paris',
      inviteCode: 'X',
      environment: 'production',
    );

final _head = _space('head', 'Atelier du Marché', 'FR', 'EUR');
final _zurich = _space('zh', 'Atelier Zürich', 'CH', 'CHF');
final _london = _space('ldn', 'Atelier London', 'GB', 'GBP');
final _milan = _space('mi', 'Atelier Milano', 'IT', 'EUR');
final _berlin = _space('ber', 'Praxis Berlin', 'DE', 'EUR');
final _spaces = [_berlin, _zurich, _head, _milan, _london];

OrganisationHouse _house(Workspace w) => OrganisationHouse(
  workspaceId: w.id,
  name: w.name,
  countryCode: w.countryCode,
  currencyCode: w.currencyCode,
  role: HouseRole.owner,
);

// The server's order: the head first, then by name.
final _organisation = Organisation(
  id: 'org',
  name: 'Atelier du Marché',
  headWorkspaceId: _head.id,
  houses: [
    for (final w in [_head, _london, _milan, _zurich]) _house(w),
  ],
);

void main() {
  test('the server read becomes the organisation, an unknown role the '
      'least one', () {
    final read = Organisation.fromJson({
      'id': 'org',
      'name': 'Atelier du Marché',
      'head_workspace_id': 'head',
      'houses': [
        {
          'workspace_id': 'head',
          'name': 'Atelier du Marché',
          'country_code': 'FR',
          'currency_code': 'EUR',
          'role': 'co_owner',
        },
        {
          'workspace_id': 'ldn',
          'name': 'Atelier London',
          'country_code': 'GB',
          'currency_code': 'GBP',
          'role': 'steward',
        },
      ],
    });
    expect(read.headWorkspaceId, 'head');
    expect(
      [for (final h in read.houses) h.role],
      [HouseRole.coOwner, HouseRole.member],
    );
    expect(read.houseOf('ldn')?.currencyCode, 'GBP');
  });

  group('Me', () {
    final layout = MeSpacesLayout.of(
      prefs: const SpacePrefs(),
      spaces: _spaces,
      lastUsedId: _berlin.id,
      query: '',
      organisations: [_organisation],
    );

    test('groups the organisation first, the head first and then the houses '
        'by country', () {
      final group = layout.groups.first;
      expect(group.organisation, 'Atelier du Marché');
      expect(group.id, 'organisation:org');
      expect(
        [for (final k in group.keys) layout.rows[k]!.first.id],
        [
          'head', // the head
          'zh', // CH
          'ldn', // GB
          'mi', // IT
        ],
      );
    });

    test('a business outside the organisation stays in the person\'s own '
        'groups, and no house is there twice', () {
      final outside = [
        for (final g in layout.groups.skip(1))
          for (final k in g.keys) layout.rows[k]!.first.id,
      ];
      expect(outside, ['ber']);
    });

    test('a search keeps only the houses it finds', () {
      final found = MeSpacesLayout.of(
        prefs: const SpacePrefs(),
        spaces: _spaces,
        lastUsedId: null,
        query: 'london',
        organisations: [_organisation],
      );
      expect(found.groups.first.organisation, 'Atelier du Marché');
      expect(
        [for (final k in found.groups.first.keys) found.rows[k]!.first.id],
        ['ldn'],
      );
    });

    test('with no organisation, every business is where it was', () {
      final plain = MeSpacesLayout.of(
        prefs: const SpacePrefs(),
        spaces: _spaces,
        lastUsedId: null,
        query: '',
      );
      expect(plain.groups.any((g) => g.organisation != null), isFalse);
    });
  });

  test('the other houses of a house are its organisation\'s, never a '
      'business outside it', () {
    expect(
      [
        for (final h in Organisation.othersOf([_organisation], 'ldn'))
          h.workspaceId,
      ],
      ['head', 'zh', 'mi'],
    );
    expect(Organisation.othersOf([_organisation], 'ber'), isEmpty);
  });

  group('the chip', () {
    Future<void> pumpChip(WidgetTester tester, Workspace current) => pumpApp(
      tester,
      const Scaffold(
        body: Center(child: SpaceChip(tabTitle: 'Home')),
      ),
      overrides: [
        currentWorkspaceProvider.overrideWith((ref) async => current),
        myWorkspacesProvider.overrideWith((ref) async => _spaces),
        myOrganisationsProvider.overrideWith((ref) async => [_organisation]),
      ],
    );

    testWidgets('inside a house, a tap lists the other houses with their '
        'country and currency, and the way back to Me', (tester) async {
      await pumpChip(tester, _london);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('space-chip-houses')));
      await tester.pumpAndSettle();
      for (final w in [_head, _zurich, _milan]) {
        expect(find.byKey(ValueKey('house-${w.id}')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('house-ldn')), findsNothing);
      expect(find.byKey(const ValueKey('house-ber')), findsNothing);
      expect(find.text('Switzerland · CHF'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('house-sheet-back-to-me')),
        findsOneWidget,
      );
    });

    testWidgets('a business in no organisation keeps a chip that is not a '
        'switcher', (tester) async {
      await pumpChip(tester, _berlin);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('space-chip')), findsOneWidget);
      expect(find.byKey(const ValueKey('space-chip-houses')), findsNothing);
    });

    testWidgets('the sheet answers the house picked', (tester) async {
      Workspace? picked;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => FilledButton(
            key: const ValueKey('open'),
            onPressed: () async =>
                picked = await HouseSheet.open(context, [_head, _zurich]),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('house-zh')));
      await tester.pumpAndSettle();
      expect(picked?.id, 'zh');
    });
  });
}
