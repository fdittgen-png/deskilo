// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4005 — the Demo performs a house abroad: Ada, owner of the head, makes a
// house in Portugal through the Demo's own commands. The business exists
// among hers, it is a house of the organisation in its own currency, its
// birth record names the head, and the same request answers the same house.
import 'package:deskilo/core/demo/data/fake_organisation_repository.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/seed/demo_organisation_seed.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Ada makes a house in Portugal; it is a business of hers and a house '
      'of the organisation', () async {
    final f = DemoFixture.build();
    final organisations = FakeOrganisationRepository.from(
      () => demoOrganisations(f.workspaces),
      businesses: () => demoBusinessesAsHouses(f.workspaces),
      createBusiness: (r) => f.workspaces.createWorkspace(
        name: r.name,
        countryCode: r.country,
        currencyCode: r.currency,
        timezone: r.timezone,
        environment: WorkspaceEnvironment.production,
        withTwin: false,
        requestId: r.requestId,
      ),
    );
    final organisation = (await organisations.myOrganisations()).single;
    final request = (
      organisationId: organisation.id,
      name: 'Atelier Lisboa',
      country: 'PT',
      currency: 'EUR',
      timezone: 'Europe/Lisbon',
      language: 'en',
      requestId: 'req-lisboa',
    );
    final made = await organisations.createHouse(request);
    expect(made.refused, isNull);
    final id = made.workspaceId!;

    final business = (await f.workspaces.fetchMyWorkspaces())
        .where((w) => w.id == id)
        .single;
    expect(business.countryCode, 'PT');
    final now = (await organisations.myOrganisations()).single;
    expect(now.houseOf(id)?.currencyCode, 'EUR');
    final birth = await organisations.houseBirth(id);
    expect(birth?.headWorkspaceId, organisation.headWorkspaceId);

    final again = await organisations.createHouse(request);
    expect(again.workspaceId, id, reason: 'the same request, the same house');
    expect([
      for (final h in (await organisations.myOrganisations()).single.houses)
        if (h.workspaceId == id) h,
    ], hasLength(1));
  });
}
