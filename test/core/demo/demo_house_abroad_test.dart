// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4005 — the Demo performs a house abroad. Its house (Atelier Kraków, in
// Poland, in złoty) is nowhere until Ada adds it through the Demo's own
// commands. Then it is a business of hers and a house of the organisation.
// The head's services and packages arrive in its money inactive, at 0, with
// the head's rate categories as hints. Its birth record says the prices are
// still to be named. The same request answers the same house, and another
// country is refused in words.
import 'package:deskilo/core/demo/data/fake_organisation_repository.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_house_reveal.dart';
import 'package:deskilo/core/demo/demo_space_ids.dart';
import 'package:deskilo/core/demo/seed/demo_house_seed.dart';
import 'package:deskilo/core/demo/seed/demo_organisation_seed.dart';
import 'package:deskilo/features/workspace/domain/organisation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DemoFixture f;
  late FakeOrganisationRepository organisations;

  setUp(() {
    f = DemoFixture.build();
    organisations = FakeOrganisationRepository.from(
      () => demoOrganisations(f.workspaces),
      businesses: () => demoBusinessesAsHouses(f.workspaces),
      createBusiness: (r) => revealDemoHouse(f, name: r.name),
      onlyHouse: (country: demoHouseCountry, currency: demoHouseCurrency),
    );
  });

  HouseRequest request(String id, String org, {String country = 'PL'}) => (
    organisationId: org,
    name: 'Atelier Kraków',
    country: country,
    currency: country == 'PL' ? demoHouseCurrency : 'EUR',
    timezone: demoHouseTimezone,
    language: 'en',
    requestId: id,
  );

  test('the house is nowhere until it is added', () async {
    final mine = await f.workspaces.fetchMyWorkspaces();
    expect(mine.any((w) => w.id == demoHouseSpaceId), isFalse);
    final o = (await organisations.myOrganisations()).single;
    expect(o.houseOf(demoHouseSpaceId), isNull);
  });

  test('Ada adds the house: hers, a house of the organisation, its prices '
      'to be named', () async {
    final org = (await organisations.myOrganisations()).single;
    final made = await organisations.createHouse(request('req-1', org.id));
    expect(made.refused, isNull);
    expect(made.workspaceId, demoHouseSpaceId);

    final business = (await f.workspaces.fetchMyWorkspaces())
        .where((w) => w.id == demoHouseSpaceId)
        .single;
    expect(business.currencyCode, demoHouseCurrency);
    expect(
      (await organisations.myOrganisations()).single.houseOf(demoHouseSpaceId),
      isNotNull,
    );

    final house = f.house.money.commercialTerms;
    final services = await house.fetchServices(
      demoHouseSpaceId,
      includeInactive: true,
    );
    final headServices = await f.money.commercialTerms.fetchServices(
      demoFirstSpaceId,
      includeInactive: true,
    );
    expect(services, hasLength(headServices.length));
    expect(services.every((s) => !s.active && s.priceCents == 0), isTrue);

    final birth = (await organisations.houseBirth(demoHouseSpaceId))!;
    expect(birth.pricesPending, isTrue);
    expect(birth.amountsKept, isFalse);
    expect(birth.services, headServices.length);

    final again = await organisations.createHouse(request('req-1', org.id));
    expect(again.workspaceId, demoHouseSpaceId);
    expect(
      await house.fetchServices(demoHouseSpaceId, includeInactive: true),
      hasLength(headServices.length),
      reason: 'carried once',
    );
  });

  test('another country is refused in words, nothing is added', () async {
    final org = (await organisations.myOrganisations()).single;
    final made = await organisations.createHouse(
      request('req-2', org.id, country: 'PT'),
    );
    expect(made.refused, OrganisationRefusal.demoOneHouse);
    expect(f.houseRevealed, isFalse);
  });
}
