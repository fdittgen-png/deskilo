// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3837 — the one rule for a revoked pass's money: its invoice is voided,
// or its customer record holds a replacement or a credit note; until then
// it is not corrected, open or paid alike. A free pass has no invoice.
import 'package:deskilo/features/money/domain/guest_pass.dart';
import 'package:deskilo/features/money/domain/guest_pass_invoice.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';

GuestPassRecord _pass({String? invoiceId}) => GuestPassRecord(
  id: 'pass-1',
  memberId: 'guest-1',
  offerId: 'day',
  unit: GuestPassUnit.day,
  units: 2,
  amountCents: invoiceId == null ? 0 : 4800,
  startsAt: DateTime.utc(2026, 11, 2, 8),
  endsAt: DateTime.utc(2026, 11, 3, 17),
  revokedAt: DateTime.utc(2026, 11, 2, 12),
  invoiceId: invoiceId,
);

Invoice _invoice(
  String id, {
  String member = 'guest-1',
  int total = 4800,
  DateTime? voidedAt,
  String? replaces,
}) => Invoice(
  id: id,
  workspaceId: 'ws',
  memberId: member,
  number: 'F-$id',
  issuedAt: DateTime.utc(2026, 11, 2),
  title: 'Guest pass',
  lines: [InvoiceLine(label: 'Day pass', amountCents: total)],
  totalCents: total,
  currency: 'EUR',
  memberName: 'Guest',
  memberAddress: '',
  workspaceName: 'W',
  workspaceAddress: '',
  issuerName: 'O',
  signature: '',
  voidedAt: voidedAt,
  replacesInvoiceId: replaces,
);

PassInvoiceState _state(GuestPassRecord pass, List<Invoice> invoices) =>
    passInvoiceOf(pass, invoices).state;

void main() {
  final pass = _pass(invoiceId: 'inv-1');
  final own = _invoice('inv-1');

  test('a free pass has no invoice, so nothing to correct', () {
    expect(_state(_pass(), [own]), PassInvoiceState.free);
    expect(PassInvoiceState.free.corrected, isFalse);
  });

  test('the invoice as issued, open or paid, is not corrected yet', () {
    final read = passInvoiceOf(pass, [own, _invoice('x', member: 'other')]);
    expect(read.state, PassInvoiceState.notCorrected);
    expect(read.invoice?.number, 'F-inv-1');
    expect(read.state.corrected, isFalse);
  });

  test('a voided invoice is corrected', () {
    expect(
      _state(pass, [_invoice('inv-1', voidedAt: DateTime.utc(2026, 11, 4))]),
      PassInvoiceState.voided,
    );
  });

  test('a replacement in the customer record corrects it, voided or not', () {
    expect(
      _state(pass, [
        _invoice('inv-1', voidedAt: DateTime.utc(2026, 11, 4)),
        _invoice('inv-2', total: 2400, replaces: 'inv-1'),
      ]),
      PassInvoiceState.replaced,
    );
  });

  test('a credit note in the customer record corrects it', () {
    final state = _state(pass, [own, _invoice('cn-1', total: -4800)]);
    expect(state, PassInvoiceState.credited);
    expect(state.corrected, isTrue);
  });

  test("another customer's credit note corrects nothing", () {
    expect(
      _state(pass, [own, _invoice('cn-9', member: 'other', total: -4800)]),
      PassInvoiceState.notCorrected,
    );
  });

  test('an invoice not read says nothing either way', () {
    expect(_state(pass, const []), PassInvoiceState.unknown);
    expect(PassInvoiceState.unknown.corrected, isFalse);
  });
}
