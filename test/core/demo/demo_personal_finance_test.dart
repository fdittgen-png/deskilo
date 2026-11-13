// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3832 - My Space in the Demo reads the persona's own documents from the
// same records the workspaces hold: the overview, the invoices, the payments
// and the usage agree; every human has documents in at least two currencies;
// currencies stay apart; the wall tablet owns nothing; a reset rebuilds the
// same data and one space's change never reaches another's.
//
// The expectations are literals taken from the seed's facts (how many months
// each business has billed) or sums taken straight from the spaces' records,
// never from the overview or the activity under test.
import 'package:deskilo/core/demo/data/workspace_repository.dart' show FakeWorkspaceMembership;
import 'package:deskilo/core/demo/demo_dataset.dart';
import 'package:deskilo/core/demo/demo_finances.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/features/money/domain/account_activity.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/providers/account_activity_providers.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Months each business has billed on 2 November 2026: London three years,
/// New York four, Zurich and Milan two.
const _monthsBilled = {'ws-3': 36, 'ws-4': 48, 'ws-5': 24, 'ws-6': 24};
const _currencyOf = {
  'ws-3': 'GBP',
  'ws-4': 'USD',
  'ws-5': 'CHF',
  'ws-6': 'EUR',
};

/// The currencies each human of the cast holds documents in, from the
/// membership facts: Ada, Bruno and Chiara work in all six spaces' countries;
/// Dov (pending) and Elise (paused) in the main space are active members of
/// the two trade cities only.
const _currenciesOf = {
  'member-1': {'EUR', 'GBP', 'USD', 'CHF'},
  'member-2': {'EUR', 'GBP', 'USD', 'CHF'},
  'member-3': {'EUR', 'GBP', 'USD', 'CHF'},
  'member-4': {'CHF', 'EUR'},
  'member-5': {'CHF', 'EUR'},
};

Future<List<AccountActivity>> _all(
  AccountActivityRepository repo,
  AccountActivityKind kind,
) => everyActivityPage((before) => repo.list(kind, before: before));

void main() {
  final fixture = DemoFixture.build(now: DateTime.utc(2026, 11, 2, 10));
  final container = ProviderContainer(overrides: demoOverrides(fixture));
  tearDownAll(container.dispose);
  final repo = container.read(accountActivityRepositoryProvider);

  for (final person in demoCast) {
    test('${person.name} has own documents in ${_currenciesOf[person.memberId]!.length} currencies, apart', () async {
      fixture.actor.memberId = person.memberId;
      final invoices = await _all(repo, AccountActivityKind.invoices);
      expect(
        {for (final i in invoices) i.currency},
        _currenciesOf[person.memberId],
      );
      // Each business bills its own people once a month, in its currency.
      // Dov and Elise work in the two trade cities only.
      final tradeOnly = person.memberId == 'member-4' || person.memberId == 'member-5';
      for (final entry in _monthsBilled.entries) {
        // The monthly invoices only: London also bills a few one-off stories.
        final rows = invoices
            .where((i) => i.workspaceId == entry.key && i.id.contains('-invoice-'))
            .toList();
        final here = !tradeOnly || entry.key == 'ws-5' || entry.key == 'ws-6';
        expect(rows, hasLength(here ? entry.value : 0), reason: '${person.name} in ${entry.key}');
        expect({for (final r in rows) r.currency}, here ? {_currencyOf[entry.key]} : <String>{});
      }
      // Nothing is another person's: the same invoices, read from the spaces'
      // own books by their member, are exactly these.
      final fromTheBooks = {
        for (final money in [
          fixture.money,
          fixture.secondSpace.money,
          fixture.london.money,
          fixture.newYork.money,
          fixture.zurich.money,
          fixture.milan.money,
        ])
          for (final i in money.invoices)
            if (i.memberId == person.memberId) i.id,
      };
      expect({for (final i in invoices) i.id}, fromTheBooks);
      // The overview lists the same documents, apart per currency.
      final overview = await repo.overview();
      expect(
        {for (final i in overview.invoices) i.id},
        {
          for (final i in invoices)
            if (i.status == 'issued' && (i.amountCents ?? 0) > 0) i.id,
        },
      );
      for (final i in overview.invoices) {
        final row = invoices.singleWhere((a) => a.id == i.id);
        expect(i.currency, row.currency, reason: i.number);
        expect(i.totalCents, row.amountCents, reason: i.number);
        expect(i.workspaceId, row.workspaceId, reason: i.number);
      }
    });
  }

  test('the payments listed are the persona\'s own receipts, per space and currency', () async {
    for (final memberId in ['member-2', 'member-4']) {
      fixture.actor.memberId = memberId;
      final payments = await _all(repo, AccountActivityKind.payments);
      final invoices = await _all(repo, AccountActivityKind.invoices);
      for (final city in ['ws-3', 'ws-4', 'ws-5', 'ws-6']) {
        final money = {
          'ws-3': fixture.london.money,
          'ws-4': fixture.newYork.money,
          'ws-5': fixture.zurich.money,
          'ws-6': fixture.milan.money,
        }[city]!;
        // Independently: what the books say this member paid in this space.
        var paid = 0;
        for (final l in money.ledger) {
          if (l.memberId == memberId &&
              l.category == LedgerCategory.payment &&
              l.kind == LedgerKind.credit) {
            paid += l.amountCents;
          }
        }
        final listed = payments.where((p) => p.workspaceId == city).toList();
        expect(listed.every((p) => p.currency == _currencyOf[city]), isTrue);
        expect(listed.fold<int>(0, (s, p) => s + p.amountCents!), paid, reason: '$memberId $city');
        // In these businesses a payment settles exactly one invoice in full:
        // what was paid is what the matched invoices total.
        var matched = 0;
        for (final i in money.invoices) {
          if (i.memberId == memberId && money.invoiceMatchesStore.containsKey(i.id)) {
            matched += i.totalCents;
          }
        }
        expect(paid, matched, reason: '$memberId $city: payments = matched invoices');
        // And every payment is dated after the invoice month began.
        final issued = {for (final i in invoices) i.id: i.occurredAt};
        for (final p in listed) {
          final invoiceId = p.id.substring(0, p.id.length - '-payment'.length);
          expect(p.occurredAt.isAfter(issued[invoiceId]!), isTrue, reason: p.id);
        }
      }
    }
  });

  test('the history agrees before and after a persona switch', () async {
    fixture.actor.memberId = 'member-2';
    final bruno = await _all(repo, AccountActivityKind.invoices);
    fixture.becomePersona(DemoPersona.admin);
    final chiara = await _all(repo, AccountActivityKind.invoices);
    fixture.becomePersona(DemoPersona.member);
    final again = await _all(repo, AccountActivityKind.invoices);
    expect(again.map((r) => r.id), bruno.map((r) => r.id));
    expect(chiara.map((r) => r.id).toSet().intersection(bruno.map((r) => r.id).toSet()), isEmpty,
        reason: 'two people never share an invoice');
    final overview = demoFinanceOverview(fixture);
    expect({for (final i in overview.invoices) i.id}, isNotEmpty);
    expect(overview.invoices.every((i) => bruno.any((r) => r.id == i.id)), isTrue);
  });

  test('usage is the persona\'s own booked time, in each space\'s currency', () async {
    fixture.actor.memberId = 'member-4';
    final usage = await _all(repo, AccountActivityKind.usage);
    expect(usage, isNotEmpty);
    for (final u in usage) {
      expect(u.minutes, greaterThan(0));
      expect(u.amountCents, isNull);
    }
    // Dov books only in the trade cities, never the main space.
    expect({for (final u in usage) u.workspaceId}, {'ws-5', 'ws-6'});
    // Independently: the minutes of his completed bookings in Zurich.
    var minutes = 0;
    for (final b in fixture.zurich.reservations.reservations) {
      if (b.memberId == 'member-4' && b.status.name == 'completed' && b.seatId != null) {
        minutes += b.endsAt.difference(b.startsAt).inMinutes;
      }
    }
    expect(
      usage.where((u) => u.workspaceId == 'ws-5').fold<int>(0, (s, u) => s + u.minutes!),
      minutes,
    );
  });

  test('pending and paused memberships stay as they are, with nothing issued', () {
    final main = fixture.workspaces;
    expect(main.memberOf('member-4')?.status, MemberStatus.pending);
    expect(main.memberOf('member-5')?.status, MemberStatus.paused);
    for (final id in ['member-4', 'member-5']) {
      expect(fixture.money.invoices.where((i) => i.memberId == id), isEmpty,
          reason: '$id has been billed nothing in the main space');
    }
  });

  test('the wall tablet owns no finance', () async {
    fixture.actor.memberId = 'member-kiosk';
    for (final kind in AccountActivityKind.values) {
      expect(await _all(repo, kind), isEmpty, reason: kind.name);
    }
    expect((await repo.overview()).invoices, isEmpty);
  });

  test('a reset rebuilds the same data and one space\'s change reaches no other', () {
    final now = DateTime.utc(2026, 11, 2, 10);
    String digest(DemoFixture f) => [
      for (final (id, money) in [
        ('main', f.money),
        ('de', f.secondSpace.money),
        ('uk', f.london.money),
        ('ny', f.newYork.money),
        ('ch', f.zurich.money),
        ('it', f.milan.money),
      ])
        '$id:${money.invoices.length}:${money.invoices.fold<int>(0, (s, i) => s + i.totalCents)}:${money.ledger.length}',
      for (final (id, r) in [
        ('ch', f.zurich.reservations),
        ('it', f.milan.reservations),
      ])
        '$id:${r.reservations.length}',
    ].join('|');

    final a = DemoFixture.build(now: now);
    final b = DemoFixture.build(now: now);
    expect(digest(a), digest(b), reason: 'the same clock seeds the same Demo');
    final before = digest(a);
    // A change in Zurich: a booking cancelled, an invoice and a payment gone.
    a.zurich.reservations.reservations.removeLast();
    a.zurich.money.invoices.removeLast();
    a.zurich.money.ledger.removeLast();
    expect(digest(a), isNot(before));
    expect(digest(b), before, reason: 'a new session is untouched');
    // Milan, the main space and the others are as they were.
    String without(String d, String id) =>
        d.split('|').where((p) => !p.startsWith('$id:')).join('|');
    expect(without(digest(a), 'ch'), without(before, 'ch'));
  });
}
