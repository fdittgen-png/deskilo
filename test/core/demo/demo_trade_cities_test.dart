// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3832 - Zurich (francs) and Milan (euros): two small businesses whose story
// is buying and selling. Every expected figure below is computed in the test
// from the facts the seed states (the catalogue's prices, the quantities'
// arithmetic, the membership percentages, the monthly bill amounts) and from
// nothing the code under test reads back.
import 'package:deskilo/core/demo/data/kpi_repositories.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_link.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/demo/seed/demo_city_purchase_seed.dart';
import 'package:deskilo/core/demo/seed/demo_trade_city_seed.dart';
import 'package:deskilo/features/money/domain/einvoice_gateway.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/plan/providers/floor_plan_providers.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/kpi_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The catalogue the members' monthly invoices are made of: unit price in
/// minor units, in the order the seed lists the items.
const _prices = [250, 200, 150, 200, 400, 15, 50, 20, 500];

/// The facts of one trade city, written out here from the issue and the seed;
/// netDivisor is the rate as a ratio: net = gross * 100 / netDivisor.
const _zurich = (
  id: 'ws-5',
  name: 'Limmat Cowork Zurich',
  country: 'CH',
  currency: 'CHF',
  zone: 'Europe/Zurich',
  prefix: 'ch',
  vat: 8.1,
  netDivisor: 10810,
  foreign: 'EUR',
  rate: '0.9383',
);
const _milan = (
  id: 'ws-6',
  name: 'Navigli Coworking Milano',
  country: 'IT',
  currency: 'EUR',
  zone: 'Europe/Rome',
  prefix: 'it',
  vat: 22,
  netDivisor: 12200,
  foreign: 'CHF',
  rate: '1.0657',
);

/// The people of a trade city in the order the seed lists them, with the
/// membership percentage each pays on: the cast first (Ada, Bruno, Chiara,
/// Dov, Elise: Bruno and Dov pay half), then sixteen full-time locals.
final _percent = [100, 50, 100, 50, 100, ...[for (var i = 0; i < 16; i++) 100]];

/// What a member's invoice of [month] (1..12) comes to, in minor units: the
/// membership (18000 half-time, 36000 full), plus the nine catalogue items
/// at the quantities the seed's rule gives, written out item by item.
int _invoiceCents(int index, int month, int percent) {
  final quantities = [
    (index + month) % 5,
    (index + month) % 3,
    (index * 2 + month) % 6,
    (index + month) % 4,
    (index + month) % 3,
    (index * 3 + month) % 25,
    (index + month) % 8,
    (index + month) % 6,
    (index + month) % 2,
  ];
  var cents = percent < 100 ? 18000 : 36000;
  for (var i = 0; i < _prices.length; i++) {
    cents += quantities[i] * _prices[i];
  }
  return cents;
}

/// The months a city of two years has invoiced on 2 November 2026: from
/// November 2024 to October 2026.
List<(int year, int month)> _months() => [
  for (var m = 0; m < 24; m++) (2024 + (10 + m) ~/ 12, (10 + m) % 12 + 1),
];

void main() {
  final now = DateTime.utc(2026, 11, 2, 10);
  final fixture = DemoFixture.build(now: now);
  final cities = [
    (facts: _zurich, data: fixture.zurich),
    (facts: _milan, data: fixture.milan),
  ];

  for (final (:facts, :data) in cities) {
    group(facts.name, () {
      test('is a space of its own country, currency, zone and people', () {
        final row = fixture.workspaces.workspaces.singleWhere(
          (w) => w.id == facts.id,
        );
        expect(row.name, facts.name);
        expect(row.countryCode, facts.country);
        expect(row.currencyCode, facts.currency);
        expect(row.timezone, facts.zone);
        // Twenty-one people: the five of the cast and sixteen locals.
        final members = [data.workspaces.myMember, ...data.workspaces.otherMembers];
        expect(members, hasLength(21));
        expect(
          members.take(5).map((m) => m.id),
          ['member-1', 'member-2', 'member-3', 'member-4', 'member-5'],
        );
        expect(
          members.where((m) => m.isOwner).map((m) => m.id),
          ['member-1'],
          reason: 'Ada owns it',
        );
        expect(
          members.map((m) => m.id),
          isNot(contains('member-kiosk')),
          reason: 'the wall tablet is a device, never a member of a business',
        );
        expect(
          members.every((m) => m.status.name == 'active'),
          isTrue,
        );
        expect(members.map((m) => m.id).toSet(), hasLength(21));
        for (final m in members) {
          expect(m.workspaceId, facts.id);
        }
        expect(
          members.skip(5).map((m) => m.userId),
          [for (var i = 1; i <= 16; i++) '${facts.prefix}-user-$i'],
        );
        expect(
          [for (final m in members) m.subscriptionPct],
          _percent,
        );
        expect(
          members.skip(5).every(
            (m) => data.workspaces.memberEmails[m.id]!.endsWith('@example.test'),
          ),
          isTrue,
          reason: 'every address is invented and reserved',
        );
      });

      test('its sales: every invoice is its issuer\'s currency, lines plus tax', () {
        final money = data.money;
        // 21 people x 24 months, nothing else.
        expect(money.invoices, hasLength(21 * 24));
        var billed = 0;
        for (final (index, member) in [
          data.workspaces.myMember,
          ...data.workspaces.otherMembers,
        ].indexed) {
          for (final (year, month) in _months()) {
            final period = '$year-${month.toString().padLeft(2, '0')}';
            final id = '${facts.prefix}-invoice-$period-$index';
            final invoice = money.invoices.singleWhere((i) => i.id == id);
            final expected = _invoiceCents(index, month, _percent[index]);
            billed += expected;
            expect(invoice.totalCents, expected, reason: id);
            expect(invoice.currency, facts.currency, reason: id);
            expect(invoice.memberId, member.id, reason: id);
            expect(invoice.workspaceId, facts.id, reason: id);
            // The total is the lines.
            expect(
              invoice.lines.fold<int>(0, (sum, l) => sum + l.amountCents),
              expected,
              reason: '$id: lines add up',
            );
            // The tax is extracted from each inclusive line, as the rate says.
            var net = 0;
            for (final line in invoice.lines) {
              expect(line.vatPercent, facts.vat, reason: id);
              net += (line.amountCents * 10000 / facts.netDivisor).round();
            }
            final vat = invoice.vatTotals.single;
            expect(vat.percent, facts.vat, reason: id);
            expect(vat.grossCents, expected, reason: id);
            expect((vat.netCents - net).abs(), lessThanOrEqualTo(invoice.lines.length),
                reason: '$id: net is the gross over (1 + rate), line by line');
            expect(vat.netCents + vat.vatCents, expected, reason: id);
          }
        }
        expect(
          money.invoices.fold<int>(0, (sum, i) => sum + i.totalCents),
          billed,
          reason: 'the whole book is the sum of the facts, in one currency',
        );
      });

      test('its payments match an invoice of the same party and currency', () {
        final money = data.money;
        // On 2 November the October invoices (issued 31 October, paid after 5
        // days) are not paid yet, and Bruno's September one stays overdue:
        // 21 + 1 open, every other invoice matched in full.
        final open = [
          for (final i in money.invoices)
            if (!money.invoiceMatchesStore.containsKey(i.id)) i,
        ];
        expect(open, hasLength(22));
        expect(
          {for (final i in open) i.issuedAt.month},
          {9, 10},
        );
        expect(
          open.where((i) => i.issuedAt.month == 9).single.memberId,
          'member-2',
          reason: 'Bruno\'s September invoice is the overdue one',
        );
        expect(
          money.invoiceReminders.keys,
          ['${facts.prefix}-invoice-2026-09-1'],
          reason: 'and only that one was chased',
        );
        for (final i in money.invoices) {
          final match = money.invoiceMatchesStore[i.id];
          if (match == null) continue;
          expect(match.paidCents, i.totalCents, reason: i.id);
          final payment = money.ledger.singleWhere(
            (l) => l.id == match.paymentLedgerId,
          );
          expect(payment.memberId, i.memberId, reason: 'the payer is the party');
          expect(payment.amountCents, i.totalCents, reason: i.id);
          expect(payment.createdAt.isAfter(i.issuedAt), isTrue, reason: i.id);
          expect(payment.createdAt.isAfter(now), isFalse, reason: 'no payment from the future');
        }
        // What Bruno still owes: September plus October, from the facts.
        final owed = _invoiceCents(1, 9, 50) + _invoiceCents(1, 10, 50);
        expect(owed, 41105, reason: 'the arithmetic, written out by hand');
        expect(
          open.where((i) => i.memberId == 'member-2').fold<int>(0, (s, i) => s + i.totalCents),
          owed,
        );
      });

      test('its purchases: bills in its currency, one abroad at its own rate', () async {
        final buying = tradeCityPurchasing(
          facts == _zurich ? demoZurich : demoMilan,
          now,
          actor: () => 'member-1',
        );
        final purchases = buying.purchases;
        final all = await purchases.fetchPurchases(facts.id);
        final approved = all.where((p) => p.state == PurchaseState.approved);
        // 24 months x two sites x (machine 4500, snacks 3500 + 200 s, drinks
        // 3500 + 300 s, print 1500 + 200 s) for s = 0, 1, plus the printers
        // (2200.00) each site bought in the first month.
        var expected = 2 * 220000;
        for (var month = 0; month < 24; month++) {
          for (final s in [0, 1]) {
            expected += 4500 + 3500 + 200 * s + 3500 + 300 * s + 1500 + 200 * s;
          }
        }
        expect(expected, 1080800, reason: 'by hand: 24 x 26700 + 440000');
        expect(approved.fold<int>(0, (sum, p) => sum + p.grossCents), expected);
        expect({for (final p in approved) p.currency}, {facts.currency});
        // All paid but one restock bill of 3500 (the last month's, first site).
        final payables = await purchases.fetchPayables(facts.id);
        expect(payables.fold<int>(0, (s, r) => s + r.obligation.remainingCents), 3500);
        expect(
          payables.fold<int>(0, (s, r) => s + r.obligation.paidCents),
          expected - 3500,
        );
        for (final row in payables) {
          expect(row.obligation.currency, facts.currency);
          expect(row.obligation.currency, row.purchase.currency);
        }
        // Two documents wait: a refreshment bill in the city's currency and
        // a licence in the other one, whose rate is kept apart from the bill.
        final pending = all.where((p) => p.state == PurchaseState.pending).toList();
        expect(pending.map((p) => (p.currency, p.grossCents)).toSet(), {
          (facts.currency, 6400),
          (facts.foreign, 48000),
        });
        final licence = pending.singleWhere((p) => p.currency == facts.foreign);
        final rate = (await purchases.fetchExchangeRate(facts.id, licence.id))!;
        expect(rate.currency, facts.foreign);
        expect(rate.functionalCurrency, facts.currency);
        expect(rate.entry.rate.toString(), facts.rate);
        expect(licence.grossCents, 48000, reason: 'the bill keeps its own amount');
        expect(await purchases.fetchExchangeRate(facts.id, 'unknown'), isNull);
        // The purchase figures never add the two currencies: the pending
        // amount is unknown, the count is not.
        final kpi = await DemoPurchaseKpiRepository(
          purchases: purchases,
          now: now,
          currency: facts.currency,
        ).summary(facts.id, fromMonth: '2024-11', toMonth: '2026-10');
        expect(kpi.currency, facts.currency);
        expect(kpi.pendingCount, 2);
        expect(kpi.pendingMinor, isNull);
        expect(kpi.reasons, contains('currency_mix'));
        expect(kpi.apOutstandingMinor, 3500, reason: 'the open bills are all in francs/euros of the space');
      });

      test('its purchase workflow refuses and recovers', () async {
        final purchases = tradeCityPurchasing(
          facts == _zurich ? demoZurich : demoMilan,
          now,
          actor: () => 'member-1',
        ).purchases;
        final id = '${facts.prefix}-bill-pending';
        final before = await purchases.fetchDetail(facts.id, id);
        // A decision made without the right to decide is refused, and the
        // bill stays as it was.
        purchases.mayDecide = (_) => false;
        await expectLater(
          purchases.decideBill(facts.id, id, before.revision,
              approve: true, reason: '', requestId: 'r-1'),
          throwsStateError,
        );
        expect((await purchases.fetchDetail(facts.id, id)).summary.state, PurchaseState.pending);
        // With the right it is approved and its payable keeps the currency.
        purchases.mayDecide = (_) => true;
        await purchases.decideBill(facts.id, id, before.revision,
            approve: true, reason: '', requestId: 'r-2');
        final after = await purchases.fetchDetail(facts.id, id);
        expect(after.summary.state, PurchaseState.approved);
        expect(after.obligations.single.currency, facts.currency);
        expect(after.obligations.single.remainingCents, 6400);
        // A second decision on the same bill is refused.
        await expectLater(
          purchases.decideBill(facts.id, id, before.revision,
              approve: false, reason: 'no', requestId: 'r-3'),
          throwsStateError,
        );
      });

      test('is reached through the Demo link and the scope answers its own stores', () async {
        final slug = facts == _zurich ? 'zurich' : 'milan';
        final link = DemoLink.parse({'space': slug, 'persona': 'owner'});
        expect(link.workspaceId, facts.id);
        expect(link.toQuery()['space'], slug);
        final workspace = fixture.workspaces.workspaces.singleWhere(
          (w) => w.id == facts.id,
        );
        final container = ProviderContainer(
          overrides: [
            ...demoOverrides(fixture),
            currentWorkspaceProvider.overrideWith((ref) async => workspace),
          ],
        );
        addTearDown(container.dispose);
        await container.read(currentWorkspaceProvider.future);
        expect(container.read(workspaceRepositoryProvider), same(data.workspaces));
        expect(container.read(floorPlanRepositoryProvider), same(data.floorPlan));
        expect(container.read(reservationRepositoryProvider), same(data.reservations));
        expect(container.read(moneyRepositoryProvider), same(data.money));
        final status = await data.money.fetchWorkspaceStatus(facts.id, '2024-11', '2026-10');
        expect(status.currency, facts.currency);
        final purchase = await container
            .read(purchaseKpiRepositoryProvider)
            .summary(facts.id, fromMonth: '2024-11', toMonth: '2026-10');
        expect(purchase.currency, facts.currency);
        expect(
          resolveEnabledFeatures(workspace.featureFlags),
          isNot(contains(WorkspaceFeature.mcpAccess)),
        );
      });
    });
  }

  // #3883 — Milan has issued through the SdI for years, so its test document
  // was accepted and the setup guide's card says the workspace issues; Zurich
  // routes nothing through a national channel and shows no card.
  test('Milan issues through the SdI, its test document accepted', () async {
    final milan = await fixture.milan.money.fetchEInvoiceTest('ws-6');
    expect(milan.available, isTrue);
    expect(milan.verdict, EInvoiceTestVerdict.accepted);
    expect(fixture.milan.money.invoices, isNotEmpty,
        reason: 'the accepted test is what lets it issue');
    final zurich = await fixture.zurich.money.fetchEInvoiceTest('ws-5');
    expect(zurich.available, isFalse);
  });

  test('a space nobody names is not Zurich or Milan', () {
    expect(DemoLink.parse({'space': 'basel'}).workspaceId, isNull);
  });

  test('each persona sees the trade cities as the member they are', () {
    final f = DemoFixture.build(now: now);
    for (final persona in [DemoPersona.owner, DemoPersona.member, DemoPersona.admin]) {
      f.becomePersona(persona);
      final listed = f.workspaces.workspaces.map((w) => w.id);
      expect(listed, containsAll(['ws-5', 'ws-6']), reason: persona.name);
      expect(f.zurich.workspaces.myMember.id, persona.memberId);
      expect(f.milan.workspaces.myMember.id, persona.memberId);
    }
    f.becomePersona(DemoPersona.kiosk);
    expect(f.workspaces.workspaces.map((w) => w.id), isNot(contains('ws-5')));
    expect(f.workspaces.workspaces.map((w) => w.id), isNot(contains('ws-6')));
  });
}
