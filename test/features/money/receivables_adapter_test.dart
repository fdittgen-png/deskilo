// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 — the invoices read as receivables: each step of a payment, as the
// journey has it, becomes one fact the home says in words. The customer's own
// declaration carries its event (Confirm and Not received decide it) and the
// day they say they paid.
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/application/receivables.dart';
import 'package:deskilo/features/money/domain/dunning.dart';
import 'package:deskilo/features/money/presentation/invoicing/receivables_adapter.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';

final _issued = DateTime(2026, 11, 1, 9);
final _now = DateTime(2026, 11, 10, 12);

Invoice _invoice({int totalCents = 25000, String? settledBy}) => Invoice(
  id: 'inv-1',
  workspaceId: 'ws-1',
  memberId: 'member-1',
  number: 'INV-1',
  issuedAt: _issued,
  period: '2026-10',
  title: '2026-10',
  lines: const [],
  totalCents: totalCents,
  currency: 'CHF',
  memberName: 'Flo',
  memberAddress: '',
  workspaceName: 'Space',
  workspaceAddress: '',
  issuerName: 'Owner',
  signature: 'sig',
  settledByInvoiceId: settledBy,
);

WorkspaceEvent _payment({
  String id = 'e1',
  EventStatus status = EventStatus.pending,
  String actor = 'member-1',
  String? paidOn,
  DateTime? createdAt,
}) => WorkspaceEvent(
  id: id,
  workspaceId: 'ws-1',
  type: EventType.payment,
  action: EventAction.created,
  actorMemberId: actor,
  subjectMemberId: 'member-1',
  payload: {'amount_cents': 25000, 'period': '2026-10', 'paid_on': ?paidOn},
  status: status,
  createdAt: createdAt ?? _issued.add(const Duration(days: 2)),
);

Receivable _read({
  Invoice? invoice,
  InvoiceMatch? match,
  List<WorkspaceEvent> events = const [],
}) {
  final rs = receivablesOf(
    invoices: [invoice ?? _invoice()],
    matches: {'inv-1': ?match},
    reminders: const {},
    rules: const DunningRules(),
    now: _now,
    dayOf: (d) => DateTime(d.year, d.month, d.day),
    events: events,
  );
  return rs.single;
}

void main() {
  test('a payment the customer declared: its event and the day they say '
      'they paid; the latest declaration is the one decided', () {
    final r = _read(
      events: [
        _payment(id: 'old', paidOn: '2026-11-03'),
        _payment(
          id: 'new',
          paidOn: '2026-11-08',
          createdAt: _issued.add(const Duration(days: 8)),
        ),
      ],
    );
    expect(r.paymentDeclared, isTrue);
    expect(r.declaredEventId, 'new');
    expect(r.declaredOn, DateTime(2026, 11, 8));
    expect(
      invoiceStatusOf(r, DateTime(2026, 11, 10)).kind,
      InvoiceStatusKind.paymentDeclared,
    );
  });

  test(
    'without a paid-on day the declaration is dated by when it was made',
    () {
      final r = _read(events: [_payment()]);
      expect(r.declaredOn, DateTime(2026, 11, 3));
    },
  );

  test('a payment an administrator recorded waits for the customer', () {
    final r = _read(events: [_payment(actor: 'admin-2')]);
    expect(r.awaitingCustomerConfirmation, isTrue);
    expect(r.paymentDeclared, isFalse);
    expect(r.declaredEventId, isNull);
  });

  test('a confirmed payment on the account is to match', () {
    final r = _read(events: [_payment(status: EventStatus.confirmed)]);
    expect(r.paymentToMatch, isTrue);
    expect(
      actionFor(invoiceStatusOf(r, DateTime(2026, 11, 10))),
      InvoiceAction.match,
    );
  });

  test('a match waiting for its quorum waits for a second approval', () {
    final r = _read(
      match: InvoiceMatch(
        invoiceId: 'inv-1',
        paidCents: 25000,
        resolution: 'exact',
        status: 'pending',
        matchedAt: _now,
      ),
    );
    expect(r.awaitingSecondApproval, isTrue);
  });

  test('a folded source and a credit note are not receivables', () {
    expect(
      receivablesOf(
        invoices: [
          _invoice(settledBy: 'inv-9'),
          _invoice(totalCents: -500),
        ],
        matches: const {},
        reminders: const {},
        rules: const DunningRules(),
        now: _now,
        dayOf: (d) => d,
      ),
      isEmpty,
    );
  });
}
