// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The demo's third space: a small coworking in London, VAT-registered, that
// files its quarterly return through Making Tax Digital (#2470). It exists so
// the HMRC submission has a UK space to be shown in WITHOUT touching the
// French and German spaces or defeating a country gate: Ada owns it, Chiara
// runs the day (and may NOT file), Bruno is a member.
//
// Everything is synthetic: the VAT number is obviously fake (it passes HMRC's
// own check digits, as a real one would), the invoices are invented, and the
// prepared return is made by the same engine every demo space uses
// (`saveVatDeclaration`), so its nine boxes come from the invoices and not
// from a number typed here.
import 'package:meta/meta.dart';

import '../../../features/money/domain/invoice.dart';
import '../../../features/money/domain/vat_rate.dart';
import '../../../features/workspace/domain/member.dart';
import '../../../features/workspace/domain/site.dart';
import '../../../features/workspace/domain/workspace.dart';
import '../../../features/workspace/domain/workspace_feature.dart';
import '../../../features/workspace/domain/workspace_permission.dart';
import '../../time/date_text.dart';
import '../data/money_repository.dart';
import '../data/workspace_repository.dart';
import '../demo_dataset.dart';
import 'demo_city_people_seed.dart';

const demoLondonSpaceId = 'ws-3';
const _spaceName = 'Camden Yard Cowork';
const demoLondonSiteId = 'uk-site-camden';

/// A synthetic UK VAT registration (nine digits; the last two are HMRC's check
/// digits for 9999041, so it validates like a real one and is nobody's).
@visibleForTesting
const demoLondonVrn = '999904143';

/// The features of the London space: a new space's, plus VAT returns and the
/// MTD submission. Accounting connectors stay off: MTD does not need them.
final Map<String, bool> _featureFlags = {
  for (final feature in featureManifest.keys) feature.dbKey: true,
};

Workspace demoLondonSpace() => Workspace(
  id: demoLondonSpaceId,
  rolePermissions: everydayMatrix(),
  name: _spaceName,
  countryCode: 'GB',
  currencyCode: 'GBP',
  timezone: 'Europe/London',
  inviteCode: 'CAMDEN2026',
  featureFlags: _featureFlags,
  environment: 'prod',
  address: '12 Chalk Farm Road\nLondon NW1 8AA',
  street: '12 Chalk Farm Road',
  postalCode: 'NW1 8AA',
  city: 'London',
  vatRegime: 'vat_registered',
  vatId: 'GB$demoLondonVrn',
  legalId: '00000000',
  branding: const {
    'seed_color': '#1D4ED8',
    'pattern': 'dots',
    'symbol_text': 'CY',
    'symbol_color': '#1D4ED8',
  },
);

/// Ada (owner), Chiara (administrator) and Bruno (member) of the demo's cast
/// hold the same roles here that their personas show.
void seedLondonPeople(FakeWorkspaceRepository space) {
  Member row(DemoPerson p, {bool owner = false, bool admin = false}) => Member(
    id: p.memberId,
    workspaceId: demoLondonSpaceId,
    userId: p.userId,
    isAdmin: admin,
    isOwner: owner,
    status: p.status,
    subscriptionPct: p.subscriptionPct,
  );
  final ada = demoCast[0];
  final bruno = demoCast[1];
  final chiara = demoCast[2];
  final rows = [
    row(ada, owner: true, admin: true),
    row(chiara, admin: true),
    row(bruno),
  ];
  space
    ..myMember = rows.first
    ..memberNames = {
      for (final p in [ada, bruno, chiara]) p.memberId: p.name,
    }
    ..memberEmails = {
      for (final p in [ada, bruno, chiara]) p.memberId: p.email,
    }
    ..otherMembers.addAll(rows.skip(1))
    ..sites.add(
      const Site(
        id: demoLondonSiteId,
        workspaceId: demoLondonSpaceId,
        name: 'Camden Yard',
        street: '12 Chalk Farm Road',
        postalCode: 'NW1 8AA',
        city: 'London',
        countryCode: 'GB',
        isDefault: true,
      ),
    );
  for (var i = 0; i < 82; i++) {
    final id = 'uk-member-${i + 1}';
    space.otherMembers.add(
      Member(
        id: id,
        workspaceId: demoLondonSpaceId,
        userId: 'uk-user-${i + 1}',
        isAdmin: false,
        isOwner: false,
        status: MemberStatus.active,
        subscriptionPct: i < 19 ? 50 : 100,
        homeSiteId: [
          demoLondonSiteId,
          'uk-site-islington',
          'uk-site-hackney',
        ][i % 3],
      ),
    );
    space.memberNames[id] = demoCityPersonName(i);
    space.memberEmails[id] = 'london.member${i + 1}@example.test';
  }
  space.memberNames['uk-member-82'] = 'Northstar Studio Ltd (Demo)';
  space.sites.addAll(const [
    Site(
      id: 'uk-site-islington',
      workspaceId: demoLondonSpaceId,
      name: 'Islington Studio',
      city: 'London',
      countryCode: 'GB',
      sortOrder: 1,
    ),
    Site(
      id: 'uk-site-hackney',
      workspaceId: demoLondonSpaceId,
      name: 'Hackney Studio',
      city: 'London',
      countryCode: 'GB',
      sortOrder: 2,
    ),
  ]);
}

/// The last full calendar quarter before [now]: the quarter whose return is
/// ready to file. It follows the injected clock, so it never goes stale.
({DateTime start, DateTime end}) demoLondonQuarter(DateTime now) {
  final thisQuarter = DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1);
  final start = DateTime(thisQuarter.year, thisQuarter.month - 3);
  return (start: start, end: DateTime(thisQuarter.year, thisQuarter.month, 0));
}

/// Four invoices in the closed quarter: three at 20 % and one zero-rated.
/// Their figures are fixed so the nine boxes read the same on every day.
void seedLondonMoney(FakeMoneyRepository money, DateTime now) {
  final quarter = demoLondonQuarter(now);
  Invoice invoice(
    String id,
    String memberId,
    String name,
    int month,
    int netCents,
    double percent,
  ) {
    final vat = (netCents * percent / 100).round();
    final period =
        '${quarter.start.year}-${twoDigits(quarter.start.month + month)}';
    return Invoice(
      id: id,
      workspaceId: demoLondonSpaceId,
      memberId: memberId,
      number: 'CY-${quarter.start.year}-${id.split('-').last}',
      issuedAt: DateTime(quarter.start.year, quarter.start.month + month, 10),
      period: period,
      title: period,
      lines: [
        InvoiceLine(
          label: period,
          amountCents: netCents + vat,
          vatPercent: percent,
        ),
      ],
      totalCents: netCents + vat,
      currency: 'GBP',
      memberName: name,
      memberAddress: '',
      workspaceName: _spaceName,
      workspaceAddress: '12 Chalk Farm Road, London NW1 8AA',
      issuerName: 'Ada Lindqvist',
      signature: 'demo',
      vatTotals: [
        InvoiceVatTotal(
          percent: percent,
          category: percent > 0 ? 'S' : 'Z',
          grossCents: netCents + vat,
          netCents: netCents,
          vatCents: vat,
        ),
      ],
    );
  }

  money
    ..invoices.clear()
    ..invoices.addAll([
      invoice('uk-inv-001', 'member-2', 'Bruno Kessler', 0, 125000, 20),
      invoice('uk-inv-002', 'member-3', 'Chiara Rossi', 1, 96050, 20),
      invoice('uk-inv-003', 'member-2', 'Bruno Kessler', 2, 133399, 20),
      invoice('uk-inv-004', 'member-3', 'Chiara Rossi', 2, 33300, 0),
    ]);
}
