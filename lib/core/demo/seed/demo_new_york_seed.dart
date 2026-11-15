// SPDX-License-Identifier: AGPL-3.0-or-later
// Synthetic New York tenant-run coworking workspace.
import '../../../features/money/domain/sales_tax_return.dart';
import '../../../features/workspace/domain/member.dart';
import '../../../features/workspace/domain/site.dart';
import '../../../features/workspace/domain/workspace.dart';
import '../../../features/workspace/domain/workspace_feature.dart';
import '../../../features/workspace/domain/workspace_permission.dart';
import '../data/money_repository.dart';
import '../data/workspace_repository.dart';
import '../demo_dataset.dart';
import '../demo_space_ids.dart';
import 'demo_city_people_seed.dart';
import 'demo_flags.dart';

export '../demo_space_ids.dart' show demoNewYorkSpaceId;


Workspace demoNewYorkSpace() => Workspace(
  id: demoNewYorkSpaceId,
  name: 'Hudson Cooperative Workspaces',
  countryCode: 'US',
  currencyCode: 'USD',
  timezone: 'America/New_York',
  inviteCode: 'HUDSONDEMO',
  environment: 'prod',
  rolePermissions: everydayMatrix(),
  // #3290 — a US space is not subject to VAT: the VAT family is off (its
  // descendants follow by the chain), so the setup guide asks for no VAT
  // rates, returns or e-invoicing VAT. US sales tax stays on.
  featureFlags: {
    ...demoOtherSpacesFeatureFlags,
    WorkspaceFeature.vatManagement.dbKey: false,
  },
  address: '100 Example Avenue\nNew York, NY 10001',
  street: '100 Example Avenue',
  city: 'New York',
  postalCode: '10001',
  branding: const {
    'seed_color': '#0F766E',
    'pattern': 'dots',
    'symbol_text': 'HC',
  },
);

void seedNewYorkPeople(FakeWorkspaceRepository space) {
  Member cast(DemoPerson p, {bool owner = false, bool admin = false}) => Member(
    id: p.memberId,
    workspaceId: demoNewYorkSpaceId,
    userId: p.userId,
    isAdmin: admin,
    isOwner: owner,
    status: MemberStatus.active,
  );
  final members = [
    cast(demoCast[0], owner: true, admin: true),
    cast(demoCast[1]),
    cast(demoCast[2], admin: true),
  ];
  space.myMember = members.first;
  space.otherMembers.addAll(members.skip(1));
  for (final person in demoCast.take(3)) {
    space.memberNames[person.memberId] = person.name;
    space.memberEmails[person.memberId] = person.email;
  }
  for (var i = 0; i < 57; i++) {
    final id = 'ny-member-${i + 1}';
    space.otherMembers.add(
      Member(
        id: id,
        workspaceId: demoNewYorkSpaceId,
        userId: 'ny-user-${i + 1}',
        isAdmin: false,
        isOwner: false,
        status: MemberStatus.active,
        homeSiteId: [
          'ny-site-main',
          'ny-site-brooklyn',
          'ny-site-queens',
          'ny-site-bronx',
          'ny-site-harlem',
        ][i % 5],
      ),
    );
    space.memberNames[id] = demoCityPersonName(i);
    space.memberEmails[id] = 'ny.member${i + 1}@example.test';
  }
  space.sites.addAll(const [
    Site(
      id: 'ny-site-main',
      workspaceId: demoNewYorkSpaceId,
      name: 'Hudson House',
      city: 'New York',
      countryCode: 'US',
      isDefault: true,
    ),
    Site(
      id: 'ny-site-brooklyn',
      workspaceId: demoNewYorkSpaceId,
      name: 'Brooklyn Studio',
      city: 'New York',
      countryCode: 'US',
      sortOrder: 1,
    ),
    Site(
      id: 'ny-site-queens',
      workspaceId: demoNewYorkSpaceId,
      name: 'Queens Studio',
      city: 'New York',
      countryCode: 'US',
      sortOrder: 2,
    ),
    Site(
      id: 'ny-site-bronx',
      workspaceId: demoNewYorkSpaceId,
      name: 'Bronx Studio',
      city: 'New York',
      countryCode: 'US',
      sortOrder: 3,
    ),
    Site(
      id: 'ny-site-harlem',
      workspaceId: demoNewYorkSpaceId,
      name: 'Harlem Studio',
      city: 'New York',
      countryCode: 'US',
      sortOrder: 4,
    ),
  ]);
}

/// #4009 -- what New York states for sales tax, one jurisdiction each (the
/// parts of the city's published combined 8.875 %): the state, the city and
/// the commuter district.
const demoNewYorkSalesTaxJurisdictions =
    <({String level, String name, double percent})>[
      (level: 'state', name: 'New York State', percent: 4),
      (level: 'city', name: 'New York City', percent: 4.5),
      (
        level: 'district',
        name: 'Metropolitan Commuter Transportation District',
        percent: 0.375,
      ),
    ];

/// The sales-tax return of New York for `[start, end]`, in dollars: the base
/// is the net of the house's own invoices issued in the period (a voided one
/// is out), the tax is each jurisdiction's rate on it, and an empty period
/// states nothing.
List<SalesTaxReturnRow> demoNewYorkSalesTaxReturn(
  FakeMoneyRepository money, {
  required DateTime start,
  required DateTime end,
}) {
  final inPeriod = [
    for (final i in money.invoices)
      if (i.voidedAt == null &&
          !i.issuedAt.isBefore(start) &&
          i.issuedAt.isBefore(end.add(const Duration(days: 1))))
        i,
  ];
  if (inPeriod.isEmpty) return const [];
  final base = inPeriod.fold<int>(0, (sum, i) => sum + i.netCents);
  final taxes = [
    for (final j in demoNewYorkSalesTaxJurisdictions)
      (base * j.percent / 100).round(),
  ];
  return [
    SalesTaxReturnRow(
      state: 'NY',
      line: SalesTaxLine.taxable,
      baseCents: base,
      taxCents: taxes.fold<int>(0, (a, b) => a + b),
      invoiceCount: inPeriod.length,
    ),
    for (var k = 0; k < taxes.length; k++)
      SalesTaxReturnRow(
        state: 'NY',
        line: SalesTaxLine.tax,
        level: demoNewYorkSalesTaxJurisdictions[k].level,
        name: demoNewYorkSalesTaxJurisdictions[k].name,
        percent: demoNewYorkSalesTaxJurisdictions[k].percent,
        baseCents: base,
        taxCents: taxes[k],
        invoiceCount: inPeriod.length,
      ),
  ];
}
