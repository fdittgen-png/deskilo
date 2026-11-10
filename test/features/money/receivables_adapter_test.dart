// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 — the invoices read as receivables: each step of a payment, as the
// journey has it, becomes one fact the home says in words. The customer's own
// declaration carries its event (Confirm and Not received decide it) and the
// day they say they paid. A regrouped source says where it went, a credit
// note is a refund owed, and a hold, a rejected e-invoice, a finished
// reminder ladder and a missing due date reach the line.
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/application/receivables.dart';
import 'package:deskilo/features/money/domain/dunning.dart';
import 'package:deskilo/features/money/domain/einvoice_gateway.dart';
import 'package:deskilo/features/money/presentation/invoice_journey.dart';
import 'package:deskilo/features/money/presentation/invoicing/receivables_adapter.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';

final _issued = DateTime(2026, 11, 1, 9);
final _now = DateTime(2026, 11, 10, 12);

Invoice _invoice({
  String id = 'inv-1',
  int totalCents = 25000,
  String? settledBy,
  DateTime? dueOn,
}) => Invoice(
  id: id,
  workspaceId: 'ws-1',
  memberId: 'member-1',
  number: 'INV-${id.substring(4)}',
  dueOn: dueOn,
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

ReceivablesReader _reader({
  InvoiceMatch? match,
  List<WorkspaceEvent> events = const [],
  Map<String, ({int count, DateTime last})> reminders = const {},
  Map<String, InvoiceTransmission> transmissions = const {},
  Set<String> held = const {},
}) => ReceivablesReader(
  matches: {'inv-1': ?match},
  reminders: reminders,
  transmissions: transmissions,
  held: held,
  rules: const DunningRules(),
  now: _now,
  dayOf: (d) => DateTime(d.year, d.month, d.day),
  eventFactsOf: (invoice, m) => (
    journey: journeyFactsOf(invoice, m, events),
    declaration: declarationOf(invoice, events),
  ),
);

Receivable _read({
  Invoice? invoice,
  InvoiceMatch? match,
  List<WorkspaceEvent> events = const [],
}) =>
    _reader(match: match, events: events).read([invoice ?? _invoice()]).single;

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
      actionOf(r, DateTime(2026, 11, 10), ReminderMode.byHand),
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

  test('a regrouped source names its settlement; a credit note is a refund '
      'owed, always as a positive amount', () {
    final rs = _reader().read([
      _invoice(settledBy: 'inv-9'),
      _invoice(id: 'inv-9', totalCents: 50000),
      _invoice(id: 'inv-5', totalCents: -500),
    ]);
    final byId = {for (final r in rs) r.invoiceId: r};
    expect(byId['inv-1']!.stage, ReceivableStage.regrouped);
    expect(byId['inv-1']!.regroupedInto, 'INV-9');
    expect(byId['inv-5']!.stage, ReceivableStage.refundOwed);
    expect(byId['inv-5']!.openMinor, 500);
  });

  test('a hold, a rejected e-invoice, a finished ladder and a frozen due '
      'date reach the line', () {
    final rs = _reader(
      held: {'inv-1'},
      transmissions: {
        'inv-1': InvoiceTransmission(
          invoiceId: 'inv-1',
          status: EInvoiceSubmissionStatus.rejected,
          sentAt: _issued,
        ),
      },
      reminders: {'inv-1': (count: 3, last: _now)},
    ).read([_invoice(dueOn: DateTime(2026, 11, 5))]);
    final r = rs.single;
    expect(r.onHold, isTrue);
    expect(r.eInvoiceRejected, isTrue);
    expect(r.remindersExhausted, isTrue);
    expect(r.dueDateSet, isTrue);
    expect(_read().dueDateSet, isFalse);
    expect(_read().onHold, isFalse);
  });
}
