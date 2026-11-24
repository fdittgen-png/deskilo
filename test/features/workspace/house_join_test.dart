// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4008 — a member of one house asks to join another: the houses offered
// read as the server lists them, a request answers a member at once or a
// request the house decides, the server's refusals are said in their own
// words, and only a house's owners set its welcome.
import 'package:deskilo/core/codes/pg_code.dart';
import 'package:deskilo/core/demo/data/fake_organisation_repository.dart';
import 'package:deskilo/features/workspace/data/supabase_organisation_repository.dart';
import 'package:deskilo/features/workspace/domain/organisation.dart';
import 'package:flutter_test/flutter_test.dart';

const _milan = JoinableHouse(
  organisationId: 'org',
  organisationName: 'Atelier',
  workspaceId: 'milan',
  name: 'Navigli',
  countryCode: 'IT',
  currencyCode: 'EUR',
);

Organisation _organisation(HouseRole role) => Organisation(
  id: 'org',
  name: 'Atelier',
  headWorkspaceId: 'head',
  houses: [
    const OrganisationHouse(
      workspaceId: 'head',
      name: 'Head',
      countryCode: 'FR',
      currencyCode: 'EUR',
      role: HouseRole.member,
    ),
    OrganisationHouse(
      workspaceId: 'zurich',
      name: 'Limmat',
      countryCode: 'CH',
      currencyCode: 'CHF',
      role: role,
    ),
  ],
);

void main() {
  test('a house offered reads as the server lists it', () {
    final house = JoinableHouse.fromJson({
      'organisation_id': 'org',
      'organisation_name': 'Atelier',
      'workspace_id': 'milan',
      'name': 'Navigli',
      'country_code': 'IT',
      'currency_code': 'EUR',
      'request': 'pending',
      'welcome': true,
    });
    expect(house.asked, isTrue);
    expect(house.welcome, isTrue);
    expect(
      JoinableHouse.fromJson({
        'organisation_id': 'org',
        'workspace_id': 'milan',
        'request': null,
      }).asked,
      isFalse,
    );
  });

  test('the answer is a member at once only for an active row', () {
    expect(HouseJoin.of('active'), HouseJoin.member);
    expect(HouseJoin.of('pending'), HouseJoin.asked);
    expect(HouseJoin.of(null), HouseJoin.asked);
  });

  test('the server\'s refusals are said in their own words', () {
    expect(
      SupabaseOrganisationRepository.refusalOf(
        PgCode.insufficientPrivilege,
        'only a member of a house of this organisation asks to join another',
      ),
      OrganisationRefusal.notAMember,
    );
    expect(
      SupabaseOrganisationRepository.refusalOf(
        PgCode.insufficientPrivilege,
        'only a person asks to join a house',
      ),
      OrganisationRefusal.onlyAPerson,
    );
    expect(
      SupabaseOrganisationRepository.refusalOf(
        PgCode.invalidParameterValue,
        'this business is no house of an organisation',
      ),
      OrganisationRefusal.noHouse,
    );
    expect(
      SupabaseOrganisationRepository.refusalOf(PgCode.insufficientPrivilege, 'anything else'),
      OrganisationRefusal.notOwner,
    );
  });

  group('asking', () {
    test('a house that decides keeps the request, asked', () async {
      final repo = FakeOrganisationRepository(joinable: const [_milan]);
      final answer = await repo.askToJoin('milan');
      expect(answer.joined, HouseJoin.asked);
      expect((await repo.joinableHouses()).single.asked, isTrue);
    });

    test('a welcoming house takes the person at once', () async {
      final repo = FakeOrganisationRepository(
        joinable: const [_milan],
        welcoming: {'milan'},
      );
      expect((await repo.joinableHouses()).single.welcome, isTrue);
      final answer = await repo.askToJoin('milan');
      expect(answer.joined, HouseJoin.member);
      expect(await repo.joinableHouses(), isEmpty);
    });

    test('a house not offered is refused in words', () async {
      final repo = FakeOrganisationRepository();
      expect(
        (await repo.askToJoin('milan')).refused,
        OrganisationRefusal.notAMember,
      );
    });
  });

  group('the welcome', () {
    test('is set by the house\'s owner and read back', () async {
      final repo = FakeOrganisationRepository(
        organisations: [_organisation(HouseRole.owner)],
      );
      expect(await repo.welcomesMembers('org', 'zurich'), isFalse);
      expect(await repo.setWelcome('zurich', on: true), isNull);
      expect(await repo.welcomesMembers('org', 'zurich'), isTrue);
    });

    test(
      'is refused to a member, and to a business in no organisation',
      () async {
        final repo = FakeOrganisationRepository(
          organisations: [_organisation(HouseRole.member)],
        );
        expect(
          await repo.setWelcome('zurich', on: true),
          OrganisationRefusal.notOwner,
        );
        expect(
          await repo.setWelcome('elsewhere', on: true),
          OrganisationRefusal.inNone,
        );
        expect(await repo.welcomesMembers('org', 'zurich'), isFalse);
      },
    );
  });
}
