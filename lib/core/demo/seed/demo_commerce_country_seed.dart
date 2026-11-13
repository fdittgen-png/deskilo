// SPDX-License-Identifier: AGPL-3.0-or-later
// Fictional country scenarios: the sample terms describe this business,
// never a rule for other businesses in that country.
import '../../../features/workspace/domain/member.dart';
import '../../../features/workspace/domain/site.dart';
import '../../../features/workspace/domain/workspace.dart';
import '../../../features/workspace/domain/workspace_feature.dart';
import '../../../features/workspace/domain/workspace_permission.dart';
import '../data/workspace_repository.dart';
import '../demo_dataset.dart';
import 'demo_flags.dart';

const demoZurichSpaceId = 'ws-5';
const demoMilanSpaceId = 'ws-6';

// The prices and stock shapes remain the deterministic city scenarios;
// these businesses sell printing services and goods rather than refreshments.
const demoCommerceCatalogue = <(String, int, bool)>[
  ('Postcard sets', 250, true),
  ('Presentation folders', 200, true),
  ('Paper packs', 150, true),
  ('Stationery sets', 200, true),
  ('Binding kits', 400, true),
  ('Black and white pages', 15, false),
  ('Colour pages', 50, false),
  ('Copies', 20, false),
  ('3D print jobs', 500, false),
];

const demoCommercePurchaseLabels = (
  rentalSupplier: 'Studio Equipment Rentals (Demo)',
  materialsSupplier: 'Paper Materials Wholesale (Demo)',
  materialsContact: 'orders@paper-materials.example.test',
  rental: 'Print finishing equipment rental', stock: 'Stationery sets restock',
  materials: 'Paper packs for studio use', pending: 'Stationery sets restock',
);

typedef DemoCommerceSpec = ({
  String workspaceId, String prefix, String name, String city,
  String country, String currency, String timeZone, String siteId,
  String address, String postalCode, String vatId, String legalId, String iban, double vatPercent,
});

const DemoCommerceSpec demoZurichSpec = (
  workspaceId: demoZurichSpaceId, prefix: 'ch', name: 'Limmat Print & Supply (Demo)',
  city: 'Zürich', country: 'CH', currency: 'CHF', timeZone: 'Europe/Zurich',
  siteId: 'ch-site-limmat', address: 'Demoquai 12', postalCode: '8005',
  vatId: 'CHE-999.999.996 MWST', legalId: 'CHE-999.999.996',
  iban: 'CH93 0076 2011 6238 5295 7', vatPercent: 8.1,
);
const DemoCommerceSpec demoMilanSpec = (
  workspaceId: demoMilanSpaceId, prefix: 'it', name: 'Navigli Design & Supply (Demo)',
  city: 'Milano', country: 'IT', currency: 'EUR', timeZone: 'Europe/Rome',
  siteId: 'it-site-navigli', address: 'Via Dimostrazione 18', postalCode: '20144',
  vatId: 'IT99999999990', legalId: '99999999990',
  iban: 'IT60X0542811101000000123456', vatPercent: 22,
);

Workspace demoCommerceWorkspace(DemoCommerceSpec spec) => Workspace(
  id: spec.workspaceId, name: spec.name, countryCode: spec.country,
  currencyCode: spec.currency, timezone: spec.timeZone,
  rolePermissions: everydayMatrix(), featureFlags: {
    ...demoFeatureFlags, WorkspaceFeature.placeBooking.dbKey: false,
  },
  environment: 'prod', inviteCode: '${spec.prefix.toUpperCase()}DEMO',
  address: '${spec.address}\n${spec.postalCode} ${spec.city}',
  street: spec.address, postalCode: spec.postalCode, city: spec.city,
  vatRegime: 'vat_registered', vatId: spec.vatId, legalId: spec.legalId,
  paymentInstructions: {'iban': spec.iban},
);

void seedCommercePeople(FakeWorkspaceRepository space, DemoCommerceSpec spec) {
  final rows = [
    for (final (index, person) in demoCast.take(3).indexed)
      Member(id: person.memberId, workspaceId: spec.workspaceId,
        userId: person.userId, isOwner: index == 0,
        isAdmin: index == 0 || index == 2, status: MemberStatus.active,
        homeSiteId: spec.siteId),
  ];
  space.myMember = rows.first;
  space.otherMembers.addAll(rows.skip(1));
  for (final person in demoCast.take(3)) {
    space.memberNames[person.memberId] = person.name;
    space.memberEmails[person.memberId] = person.email;
  }
  space.sites.add(Site(id: spec.siteId, workspaceId: spec.workspaceId,
    name: spec.name, street: spec.address, postalCode: spec.postalCode,
    city: spec.city, countryCode: spec.country, isDefault: true));
}
