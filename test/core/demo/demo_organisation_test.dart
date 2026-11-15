// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4009 — the Demo's reference is an organisation: Atelier du Marché heads it
// and London, New York, Zurich, Milan and Leipzig are its houses, each with
// its business's own country and currency; the Berlin practice stays outside.
// Me groups the houses under the organisation's name, the head first and then
// by country, the practice stays in the person's own groups, and inside a
// house the chip lists the other houses and nothing else. A house's figures
// are never added to another's: each house carries its own currency.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/demo/demo_space_ids.dart';
import 'package:deskilo/core/storage/space_prefs_store.dart';
import 'package:deskilo/features/me/application/me_spaces_layout.dart';
import 'package:deskilo/features/workspace/domain/organisation.dart';
import 'package:deskilo/features/workspace/providers/organisation_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DemoFixture fixture;
  late ProviderContainer container;

  setUp(() {
    fixture = DemoFixture.build();
    container = ProviderContainer(overrides: demoOverrides(fixture));
  });
  tearDown(() => container.dispose());

  Future<Organisation> organisation() async {
    final all = await container.read(myOrganisationsProvider.future);
    expect(all, hasLength(1));
    return all.single;
  }

  test(
    'Atelier du Marché heads the organisation, London, New York, Zurich, '
    'Milan and Leipzig are its houses, and the Berlin practice is not',
    () async {
      final org = await organisation();
      expect(org.name, 'Atelier du Marché');
      expect(org.headWorkspaceId, demoFirstSpaceId);
      expect(
        {for (final h in org.houses) h.workspaceId},
        {
          demoFirstSpaceId,
          demoSecondSpaceId,
          demoLondonSpaceId,
          demoNewYorkSpaceId,
          demoZurichSpaceId,
          demoMilanSpaceId,
        },
      );
      expect(org.houseOf(demoPracticeSpaceId), isNull);
      expect(org.byCountry.first.workspaceId, demoFirstSpaceId);
    },
  );

  test('each house has its business\'s own country and currency, so no '
      'figure of one is another\'s', () async {
    final org = await organisation();
    final rows = await fixture.workspaces.fetchMyWorkspaces();
    for (final house in org.houses) {
      final business = rows.singleWhere((w) => w.id == house.workspaceId);
      expect(
        (house.name, house.countryCode, house.currencyCode),
        (business.name, business.countryCode, business.currencyCode),
        reason: house.workspaceId,
      );
    }
    expect(
      {for (final h in org.houses) h.currencyCode},
      {'EUR', 'GBP', 'USD', 'CHF'},
    );
  });

  test('the persona\'s role in each house is the one they hold there, and a '
      'house they are not a member of is not listed', () async {
    final owner = (await organisation()).houseOf(demoFirstSpaceId)!;
    expect(owner.role, HouseRole.owner);
    container.dispose();
    fixture = DemoFixture.build()..becomePersona(DemoPersona.member);
    container = ProviderContainer(overrides: demoOverrides(fixture));
    final asMember = await organisation();
    expect(asMember.houseOf(demoFirstSpaceId)!.role, HouseRole.member);
  });

  test('Me shows the organisation first, the head first and then by '
      'country, and the practice in the person\'s own groups', () async {
    final org = await organisation();
    final rows = await fixture.workspaces.fetchMyWorkspaces();
    final layout = MeSpacesLayout.of(
      prefs: const SpacePrefs(),
      spaces: rows,
      lastUsedId: demoPracticeSpaceId,
      query: '',
      organisations: [org],
    );
    final first = layout.groups.first;
    expect(first.organisation, 'Atelier du Marché');
    expect(
      [for (final k in first.keys) layout.rows[k]!.first.id],
      [
        demoFirstSpaceId,
        demoZurichSpaceId, // CH
        demoSecondSpaceId, // DE
        demoLondonSpaceId, // GB
        demoMilanSpaceId, // IT
        demoNewYorkSpaceId, // US
      ],
    );
    final own = [
      for (final g in layout.groups.skip(1))
        for (final k in g.keys) layout.rows[k]!.first.id,
    ];
    expect(own, contains(demoPracticeSpaceId));
    expect(
      own.toSet().intersection({...org.houses.map((h) => h.workspaceId)}),
      isEmpty,
    );
  });

  test('inside a house the chip lists the other houses, and nothing in the '
      'practice', () async {
    final all = await container.read(myOrganisationsProvider.future);
    expect(
      [
        for (final h in Organisation.othersOf(all, demoLondonSpaceId))
          h.workspaceId,
      ],
      [
        demoFirstSpaceId,
        demoZurichSpaceId,
        demoSecondSpaceId,
        demoMilanSpaceId,
        demoNewYorkSpaceId,
      ],
    );
    expect(Organisation.othersOf(all, demoPracticeSpaceId), isEmpty);
  });
}
