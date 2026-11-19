// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4224 — a declared payment the business accepts is applied to the invoices
// it names in the Demo, as 0797 does on a server: they read paid, what the
// person owes in that currency falls by the amount and so do the business's
// receivables, the request leaves the business's waiting list, and the
// received payment is the business's own. A refusal frees the invoices and
// applies nothing. Nothing is added across currencies or businesses. The
// practice (EUR), the head (EUR) and a house in another currency (GBP).
import 'package:deskilo/core/demo/data/event_repository.dart';
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/core/demo/data/workspace_repository.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/payment_claims.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _House = ({
  String name,
  String workspace,
  FakeMoneyRepository money,
  FakeEventRepository events,
  FakeWorkspaceRepository space,
});

int _paid(FakeMoneyRepository m, String invoice) =>
    m.invoiceMatchesStore[invoice]?.paidCents ?? 0;

/// What a person still owes on invoices of one currency.
int _owed(FakeMoneyRepository m, String member) => [
  for (final i in m.invoices)
    if (i.memberId == member && !i.isVoided && i.totalCents > 0)
      i.totalCents - _paid(m, i.id),
].fold(0, (a, b) => a + b);

/// What the business is owed: the same sum over every customer.
int _receivable(FakeMoneyRepository m) => [
  for (final i in m.invoices)
    if (!i.isVoided && i.totalCents > 0) i.totalCents - _paid(m, i.id),
].fold(0, (a, b) => a + b);

int _waiting(FakeEventRepository e) => e.events
    .where(
      (x) => x.type == EventType.payment && x.status == EventStatus.pending,
    )
    .length;

/// A member with an open invoice of [m], and that invoice.
({String member, String id, String period, int due})? _open(
  FakeMoneyRepository m,
) {
  for (final i in m.invoices) {
    final period = i.period;
    if (period == null ||
        i.isVoided ||
        i.totalCents <= 0 ||
        _paid(m, i.id) > 0) {
      continue;
    }
    if (m.claims.values.any((c) => c.contains(i.id))) continue;
    return (member: i.memberId, id: i.id, period: period, due: i.totalCents);
  }
  return null;
}

/// The customer declares: the request is theirs (the viewer is the owner).
Future<String> _declare(
  _House h,
  ({String member, String id, String period, int due}) i,
) async {
  final id = await h.money.declareInvoicesPaid(
    workspaceId: h.workspace,
    memberId: i.member,
    claim: InvoiceClaim(
      period: i.period,
      amountCents: i.due,
      invoiceIds: [i.id],
    ),
  );
  final at = h.events.events.indexWhere((e) => e.id == id);
  h.events.events[at] = h.events.events[at].copyWith(actorMemberId: i.member);
  return id;
}

/// Every house, from a fixture of its own: one test never meets another's
/// declarations.
List<_House> _houses() {
  final f = DemoFixture.build(now: DateTime.utc(2026, 5, 13, 10));
  return [
    (
      name: 'the practice (EUR)',
      workspace: f.practice.workspaces.myMember.workspaceId,
      money: f.practice.money,
      events: f.practice.events,
      space: f.practice.workspaces,
    ),
    (
      name: 'the head (EUR)',
      workspace: f.money.invoices.first.workspaceId,
      money: f.money,
      events: f.events,
      space: f.workspaces,
    ),
    (
      name: 'London (GBP)',
      workspace: f.london.workspaces.myMember.workspaceId,
      money: f.london.money,
      events: f.london.events,
      space: f.london.workspaces,
    ),
  ];
}

/// The business's owner decides: the person who declared never decides their
/// own request, so the declaration is the customer's.
Future<void> _decide(_House h, String id, {required bool accept}) =>
    h.events.respond(id, accept: accept);

void main() {
  for (var n = 0; n < 3; n++) {
    final name = _houses()[n].name;
    test('$name: an accepted declaration pays the invoice it names; the '
        'person owes less and the business is owed less by the same amount, '
        'and the request leaves the waiting list', () async {
      final h = _houses()[n];
      final inv = _open(h.money);
      expect(inv, isNotNull, reason: 'the Demo holds an open invoice here');
      final owedBefore = _owed(h.money, inv!.member);
      final receivableBefore = _receivable(h.money);
      final id = await _declare(h, inv);
      final waiting = _waiting(h.events);
      expect(waiting, greaterThan(0));
      expect(
        _paid(h.money, inv.id),
        0,
        reason: 'nothing is paid until decided',
      );
      expect(h.money.claims[id], [inv.id]);

      await _decide(h, id, accept: true);

      expect(_paid(h.money, inv.id), inv.due, reason: 'the invoice reads paid');
      expect(_owed(h.money, inv.member), owedBefore - inv.due);
      expect(_receivable(h.money), receivableBefore - inv.due);
      expect(h.money.claims.containsKey(id), isFalse, reason: 'its claim ends');
      expect((await h.events.fetchEvent(id))!.status, EventStatus.confirmed);
      expect(
        _waiting(h.events),
        waiting - 1,
        reason: 'the waiting count falls when it is decided',
      );
    });

    test('$name: a refusal frees the invoice and applies nothing', () async {
      final h = _houses()[n];
      final inv = _open(h.money);
      expect(inv, isNotNull);
      final receivableBefore = _receivable(h.money);
      final credits = h.money.ledger.length;
      final id = await _declare(h, inv!);
      await _decide(h, id, accept: false);
      expect(_paid(h.money, inv.id), 0);
      expect(_receivable(h.money), receivableBefore);
      expect(h.money.claims.containsKey(id), isFalse, reason: 'freed');
      expect(h.money.ledger.length, credits, reason: 'no credit was booked');
      expect((await h.events.fetchEvent(id))!.status, EventStatus.rejected);
    });
  }
}
