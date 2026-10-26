// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Which open invoice a movement of money in is suggested for, and which
// movements may be confirmed together (#2380): the invoice's QR or RF
// reference first, its number in the text next, the same amount from a
// payer named like the member within the window last; a reference two
// invoices share confirms nothing at once, and money out, a duplicate or a
// settled movement is suggested nothing.
import 'package:deskilo/features/money/domain/bank/bank_match.dart';
import 'package:deskilo/features/money/domain/bank/bank_records.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/swiss_qr_bill.dart';
import 'package:flutter_test/flutter_test.dart';

Invoice _invoice(
  String number, {
  int total = 12000,
  String currency = 'CHF',
  String member = 'Jean Dupont',
  DateTime? issued,
}) => Invoice(
  id: 'id-$number',
  workspaceId: 'ws',
  memberId: 'm-$member',
  number: number,
  issuedAt: issued ?? DateTime.utc(2026, 10, 2),
  title: number,
  lines: const [],
  totalCents: total,
  currency: currency,
  memberName: member,
  memberAddress: '',
  workspaceName: 'Space',
  workspaceAddress: '',
  issuerName: 'Space',
  signature: '',
);

StoredBankLine _line({
  int amount = 12000,
  String reference = '',
  String remittance = '',
  String payer = '',
  BankLineStatus status = BankLineStatus.open,
  String currency = 'CHF',
}) => StoredBankLine(
  id: 'l',
  position: 1,
  bookingDate: DateTime.utc(2026, 10, 20),
  valueDate: DateTime.utc(2026, 10, 20),
  amountCents: amount,
  currency: currency,
  status: status,
  reference: reference,
  remittance: remittance,
  counterpartyName: payer,
);

void main() {
  final a = _invoice('INV-2026-0042');
  final b = _invoice('INV-2026-0043', total: 8050, member: 'Studio Lumen');
  final open = openInvoices([a, b], const {});

  test('the QR reference of the invoice number names it', () {
    final s = suggestMatches(
      _line(reference: qrrReferenceOf(a.number)!),
      open,
      windowDays: 60,
    );
    expect(s.first.invoice.id, a.id);
    expect(s.first.basis, BankMatchBasis.qrReference);
  });

  test('the RF creditor reference names it, and is confirmable when the '
      'amount is what is still due', () {
    final line = _line(amount: 8050, reference: scorReferenceOf(b.number)!);
    expect(
      suggestMatches(line, open, windowDays: 60).first.basis,
      BankMatchBasis.creditorReference,
    );
    expect(referenceMatchOf(line, open, windowDays: 60)?.invoice.id, b.id);
    expect(
      referenceMatchOf(
        _line(amount: 8000, reference: scorReferenceOf(b.number)!),
        open,
        windowDays: 60,
      ),
      isNull,
      reason: 'an amount that differs is the person\'s resolution to choose',
    );
  });

  test('a reference in the free text counts like a structured one', () {
    final s = suggestMatches(
      _line(remittance: 'Facture ${scorReferenceOf(a.number)} merci'),
      open,
      windowDays: 60,
    );
    expect(s.first.basis, BankMatchBasis.creditorReference);
  });

  test('the invoice number as a whole word, never inside a longer one', () {
    expect(
      suggestMatches(_line(remittance: 'payment inv-2026-0042'), open, windowDays: 60)
          .single
          .basis,
      BankMatchBasis.invoiceNumber,
    );
    expect(
      suggestMatches(_line(remittance: 'INV-2026-00421'), open, windowDays: 60),
      isEmpty,
    );
  });

  test('the same amount from a payer named like the member, within the '
      'window only', () {
    final line = _line(amount: 8050, payer: 'STUDIO LUMEN SARL');
    expect(
      suggestMatches(line, open, windowDays: 60).single.basis,
      BankMatchBasis.amount,
    );
    expect(suggestMatches(line, open, windowDays: 10), isEmpty);
    expect(
      suggestMatches(_line(amount: 8050, payer: 'Someone Else'), open, windowDays: 60),
      isEmpty,
    );
    expect(referenceMatchOf(line, open, windowDays: 60), isNull);
  });

  test('two invoices whose numbers share their digits share a QR reference: '
      'both are suggested, none is confirmed at once', () {
    final f = _invoice('F-2026-0402');
    final u = _invoice('U-2026-04-02');
    final both = openInvoices([f, u], const {});
    final line = _line(reference: qrrReferenceOf(f.number)!);
    expect(suggestMatches(line, both, windowDays: 60), hasLength(2));
    expect(referenceMatchOf(line, both, windowDays: 60), isNull);
  });

  test('money out, another currency, a duplicate or a settled movement is '
      'suggested nothing', () {
    final ref = qrrReferenceOf(a.number)!;
    for (final line in [
      _line(amount: -12000, reference: ref),
      _line(reference: ref, currency: 'EUR'),
      _line(reference: ref, status: BankLineStatus.duplicate),
      _line(reference: ref, status: BankLineStatus.matched),
      _line(reference: ref, status: BankLineStatus.review),
    ]) {
      expect(suggestMatches(line, open, windowDays: 60), isEmpty);
    }
    expect(
      suggestMatches(_line(reference: ref, status: BankLineStatus.recorded), open, windowDays: 60),
      isNotEmpty,
      reason: 'a recorded payment is matched again after a rejection',
    );
  });

  test('what is still open: a partial owes its remainder; a void, a credit '
      'note, a pending or full match owes nothing here', () {
    InvoiceMatch m(String id, String res, int paid, {String status = 'confirmed'}) =>
        InvoiceMatch(
          invoiceId: id,
          paidCents: paid,
          resolution: res,
          status: status,
          matchedAt: DateTime.utc(2026, 10, 2),
        );
    final partial = _invoice('P-1');
    final pending = _invoice('P-2');
    final paid = _invoice('P-3');
    final credit = _invoice('C-1', total: -500);
    final result = openInvoices(
      [partial, pending, paid, credit],
      {
        partial.id: m(partial.id, 'under_accepted', 2000),
        pending.id: m(pending.id, 'exact', 12000, status: 'pending'),
        paid.id: m(paid.id, 'exact', 12000),
      },
    );
    expect(result.single.id, partial.id);
    expect(result.single.dueCents, 10000);
  });
}
