// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant (#3305): in the Demo a member's statement is their own, per period,
// and is what the server's `member_statement` computes from that member's own
// seeded records — their subscription percentage
// and its band fee, the half-days their own reservations used against the
// entitlement of the month's open days, and the period's ledger: their credits
// not consumed by an invoice match, less their charges. Every figure is
// recomputed here from that member's seeded records, at four boundary clocks,
// in Pézenas and in Leipzig; a change to one member's ledger moves their
// statement by its amount and nobody else's.
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/core/demo/data/reservation_repository.dart';
import 'package:deskilo/core/demo/data/workspace_repository.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/seed/demo_london_seed.dart';
import 'package:deskilo/core/demo/seed/demo_new_york_seed.dart';
import 'package:deskilo/core/demo/seed/demo_second_space_seed.dart';
import 'package:deskilo/core/demo/seed/demo_twin_seed.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/domain/statement.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Space = ({
  String name,
  String workspaceId,
  FakeMoneyRepository money,
  FakeWorkspaceRepository workspaces,
  FakeReservationRepository reservations,
});

List<_Space> _spaces(DemoFixture f) => [
  (
    name: 'Pézenas',
    workspaceId: 'ws-1',
    money: f.money,
    workspaces: f.workspaces,
    reservations: f.reservations,
  ),
  (
    name: 'Leipzig',
    workspaceId: demoSecondSpaceId,
    money: f.secondSpace.money,
    workspaces: f.secondSpace.workspaces,
    reservations: f.secondSpace.reservations,
  ),
  // #3314 — the city spaces and the twin read their own statements too.
  (
    name: 'London',
    workspaceId: demoLondonSpaceId,
    money: f.london.money,
    workspaces: f.london.workspaces,
    reservations: f.london.reservations,
  ),
  (
    name: 'New York',
    workspaceId: demoNewYorkSpaceId,
    money: f.newYork.money,
    workspaces: f.newYork.workspaces,
    reservations: f.newYork.reservations,
  ),
  (
    name: 'the twin',
    workspaceId: demoTwinSpaceId,
    money: f.twin.money,
    workspaces: f.twin.workspaces,
    reservations: f.twin.reservations,
  ),
];

/// The period's ledger of [member]: unconsumed credits less charges.
int _ledgerOf(FakeMoneyRepository m, String member, String period) {
  final consumed = {
    ...m.consumedPaymentIds,
    for (final x in m.invoiceMatchesStore.values) ?x.paymentLedgerId,
  };
  var n = 0;
  for (final e in m.ledger) {
    if (e.memberId != member || e.period != period) continue;
    if (e.kind == LedgerKind.charge) {
      n -= e.amountCents;
    } else if (!consumed.contains(e.id)) {
      n += e.amountCents;
    }
  }
  return n;
}

/// The month's open days of [s]: its open weekdays (Monday to Friday unless
/// set), less its closure days.
int _openDaysOf(_Space s, String period) {
  final first = DateTime.parse('$period-01');
  final open = s.workspaces.openWeekdays[s.workspaceId] ?? const [1, 2, 3, 4, 5];
  var n = 0;
  for (var day = 1; day <= DateTime(first.year, first.month + 1, 0).day; day++) {
    final d = DateTime(first.year, first.month, day);
    final closed = s.workspaces.closureDays.any((c) =>
        c.workspaceId == s.workspaceId &&
        c.day.year == d.year &&
        c.day.month == d.month &&
        c.day.day == d.day);
    if (open.contains(d.weekday) && !closed) n++;
  }
  return n;
}

void main() {
  for (final now in [
    DateTime(2026, 5, 13, 10), // the Demo's own clock
    DateTime(2026, 3, 31, 23, 30), // the last half hour of a quarter
    DateTime(2026, 4, 1, 0, 30), // the first of the next
    DateTime(2027, 1, 1, 10), // a new year
  ]) {
    group('the Demo opened on $now', () {
      final fixture = DemoFixture.build(now: now);
      for (final s in _spaces(fixture)) {
        final members = <Member>[
          s.workspaces.myMember,
          ...s.workspaces.otherMembers,
        ];
        // Everyone's statement is the owner's to read (#3314): the session
        // acts as the space's owner.
        void asOwner() =>
            fixture.actor.memberId = members.firstWhere((m) => m.isOwner).id;
        final periods = {
          yearMonth(now.year, now.month),
          for (final e in s.money.ledger) e.period,
        };

        test('${s.name}: a member reads their own statement, not another '
            'member\'s; the owner reads both', () async {
          final plain = members.where((m) => !m.isAdmin && !m.isOwner).toList();
          expect(plain, isNotEmpty, reason: '${s.name} has a plain member');
          final other = members.firstWhere((m) => m.id != plain.first.id);
          final period = yearMonth(now.year, now.month);
          fixture.actor.memberId = plain.first.id;
          expect((await s.money.fetchStatement(plain.first.id, period)).period, period);
          await expectLater(s.money.fetchStatement(other.id, period), throwsStateError);
          asOwner();
          expect((await s.money.fetchStatement(other.id, period)).period, period);
        });

        test('${s.name}: each member\'s statement of each period is computed '
            'from their own percentage, reservations and ledger', () async {
          asOwner();
          var withLedger = 0;
          for (final member in members) {
            for (final period in periods) {
              final st = await s.money.fetchStatement(member.id, period);
              final joined = member.joinedAt;
              if (joined != null &&
                  period.compareTo(yearMonth(joined.year, joined.month)) < 0) {
                expect(st.balanceCents, 0, reason: '${member.id} $period');
                continue;
              }
              final pct = member.subscriptionPct;
              final band = s.money.feeBands
                  .where((b) => b.fromPct < pct && pct <= b.toPct)
                  .firstOrNull;
              final ledger = _ledgerOf(s.money, member.id, period);
              if (ledger != 0) withLedger++;
              // The count itself is pinned by hand below (#3314); here the
              // arithmetic around it.
              final used = st.usedHalfDays;
              final openDays = _openDaysOf(s, period);
              final included = (openDays * 2 * pct / 100).ceil();
              final extra = used > included ? used - included : 0;
              final overage = extra * (band?.overageFeeCents ?? 0);
              final reason = '${s.name} ${member.id} $period';
              expect(st.period, period, reason: reason);
              expect(st.subscriptionPct, pct, reason: reason);
              expect(st.feeCents, band?.feeCents ?? 0, reason: reason);
              expect(st.openDays, openDays, reason: reason);
              expect(st.includedHalfDays, included, reason: reason);
              expect(st.extraHalfDays, extra, reason: reason);
              expect(st.overageCents, overage, reason: reason);
              expect(st.creditsCents, ledger, reason: reason);
              expect(st.balanceCents,
                  ledger - (band?.feeCents ?? 0) - overage,
                  reason: reason);
            }
          }
          // The twin space holds no ledger; every other space has money to show.
          if (s.money.ledger.isNotEmpty) {
            expect(withLedger, greaterThan(0), reason: 'statements with money');
          }
        });

        test('${s.name}: two members read two statements; one member\'s new '
            'charge moves their statement by its amount and nobody else\'s',
            () async {
          asOwner();
          final period = yearMonth(now.year, now.month);
          Future<Map<String, Statement>> read() async => {
            for (final m in members)
              m.id: await s.money.fetchStatement(m.id, period),
          };
          final before = await read();
          final target = members.first.id;
          s.money.ledger.add(
            LedgerEntry(
              id: 'isolation-charge',
              memberId: target,
              kind: LedgerKind.charge,
              category: LedgerCategory.overage,
              amountCents: 1234,
              description: 'Isolation check',
              period: period,
              createdAt: now,
            ),
          );
          final after = await read();
          s.money.ledger.removeWhere((e) => e.id == 'isolation-charge');
          expect(after[target]!.creditsCents, before[target]!.creditsCents - 1234);
          expect(after[target]!.balanceCents, before[target]!.balanceCents - 1234);
          for (final m in members.skip(1)) {
            expect(after[m.id], before[m.id], reason: m.id);
          }
          expect(members.length, greaterThan(1));
        });
      }
    });
  }
}
