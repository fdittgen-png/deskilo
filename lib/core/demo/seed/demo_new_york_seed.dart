// SPDX-License-Identifier: AGPL-3.0-or-later
// Synthetic New York tenant-run coworking workspace.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:deskilo_vat_declaration/deskilo_vat_declaration.dart'
    show VatComponent;

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

/// The postal code the house's invoices freeze their sales tax with.
const _postal = '10001';

/// New York's combined 8.875 % as the server's rate table states it, one
/// component per jurisdiction: the state, the city and the commuter district.
const _components = <({String level, String name, double percent})>[
  (level: 'state', name: 'New York State', percent: 4),
  (level: 'city', name: 'New York City', percent: 4.5),
  (
    level: 'district',
    name: 'Metropolitan Commuter Transportation District',
    percent: 0.375,
  ),
];

/// #4009 -- what New York's invoices freeze for sales tax (0434), over the
/// house's finished history. A membership, a booking, a hire or a supply is a
/// licence to occupy space (or a payment's worth of it): outside the tax, with
/// no tax stated, and the invoice freezes it so, with its state and ZIP code.
/// Beside them, three sales of the product the state taxes, in the last full
/// month, each issued with its price and its three jurisdictions frozen, paid
/// by transfer like the rest. Nothing else of the history changes.
void seedDemoNewYorkSalesTax(
  FakeMoneyRepository money,
  FakeWorkspaceRepository space,
  DateTime now,
) {
  for (var i = 0; i < money.invoices.length; i++) {
    final invoice = money.invoices[i];
    money.invoices[i] = invoice.copyWith(
      vatTotals: [
        for (final t in invoice.vatTotals)
          InvoiceVatTotal(
            percent: t.percent,
            category: t.category,
            grossCents: t.grossCents,
            netCents: t.netCents,
            vatCents: t.vatCents,
            state: 'NY',
            jurisdiction: _postal,
          ),
      ],
    );
  }
  final month = DateTime(now.year, now.month - 1);
  final period = yearMonth(month.year, month.month);
  final issued = DateTime(month.year, month.month + 1, 0);
  final buyers = [space.myMember, ...space.otherMembers].take(3).toList();
  final workspace = space.workspaces.firstWhere(
    (w) => w.id == demoNewYorkSpaceId,
  );
  for (final (k, buyer) in buyers.indexed) {
    final net = (2 + k) * 2400;
    final taxes = [
      for (final c in _components) (net * c.percent / 100).round(),
    ];
    final tax = taxes.fold<int>(0, (a, b) => a + b);
    final id = 'ny-sale-$period-$k';
    money.invoices.add(
      Invoice(
        id: id,
        workspaceId: demoNewYorkSpaceId,
        memberId: buyer.id,
        number: 'NY-$period-T${k + 1}',
        issuedAt: issued,
        period: period,
        title: 'Branded tote bags · $period',
        lines: [
          InvoiceLine(
            kind: 'service',
            label: 'Branded tote bag',
            quantity: 2 + k,
            amountCents: net + tax,
            netCents: net,
            taxCents: tax,
            vatPercent: 8.875,
            vatCategory: 'S',
          ),
        ],
        totalCents: net + tax,
        vatTotals: [
          InvoiceVatTotal(
            percent: 8.875,
            category: 'S',
            grossCents: net + tax,
            netCents: net,
            vatCents: tax,
            state: 'NY',
            jurisdiction: _postal,
            components: [
              for (final (j, c) in _components.indexed)
                VatComponent(
                  scheme: 'SALES_TAX',
                  authority: 'US-NY',
                  level: c.level,
                  name: c.name,
                  percent: c.percent,
                  baseCents: net,
                  taxCents: taxes[j],
                ),
            ],
          ),
        ],
        currency: 'USD',
        memberName: space.memberNames[buyer.id] ?? 'Demo member',
        memberAddress: '',
        workspaceName: workspace.name,
        workspaceAddress: workspace.address,
        issuerName: workspace.name,
        signature: 'demo',
        dueOn: issued.add(const Duration(days: 14)),
      ),
    );
    final paid = issued.add(const Duration(days: 5));
    money.ledger.add(
      LedgerEntry(
        id: '$id-charge',
        memberId: buyer.id,
        kind: LedgerKind.charge,
        category: LedgerCategory.service,
        amountCents: net + tax,
        description: 'Branded tote bag',
        period: period,
        createdAt: issued,
      ),
    );
    if (paid.isAfter(now)) continue;
    money.ledger.add(
      LedgerEntry(
        id: '$id-payment',
        memberId: buyer.id,
        kind: LedgerKind.credit,
        category: LedgerCategory.payment,
        amountCents: net + tax,
        description: 'Demo bank transfer',
        period: period,
        createdAt: paid,
        occurredOn: paid,
      ),
    );
    money.usePayment('$id-payment', net + tax);
    money.invoiceMatchesStore[id] = InvoiceMatch(
      invoiceId: id,
      paidCents: net + tax,
      resolution: 'exact',
      paymentLedgerId: '$id-payment',
      matchedAt: paid,
      byName: 'Demo accounts',
    );
  }
}
