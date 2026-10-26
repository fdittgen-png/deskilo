// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Which open invoice a movement of money in may settle, and why. The
// strongest reason first: the structured reference the payer typed (the
// invoice's Swiss QR reference or its ISO 11649 `RF` creditor reference,
// both derived from the invoice number exactly as the invoice prints
// them), then the invoice number written in the remittance text, then the
// same amount from a payer whose name is the member's, issued within the
// space's window before the movement. A suggestion is only ever a
// suggestion: a person confirms it, and the server checks it again. Pure
// Dart.
import 'package:meta/meta.dart';

import '../invoice.dart';
import '../swiss_qr_bill.dart';
import 'bank_records.dart';
import 'structured_reference.dart';

/// Why an invoice is suggested for a movement, strongest first.
enum BankMatchBasis {
  /// The movement's reference is the invoice's QR reference.
  qrReference,

  /// The movement's reference is the invoice's `RF` creditor reference.
  creditorReference,

  /// The invoice number is written in the movement's text.
  invoiceNumber,

  /// Same amount, a payer named like the member, issued within the window.
  amount;

  /// A reference the payer copied from the invoice, not a resemblance.
  bool get isStructured => this == qrReference || this == creditorReference;
}

/// What is still owed on one invoice.
@immutable
class OpenInvoice {
  const OpenInvoice({
    required this.id,
    required this.number,
    required this.memberName,
    required this.currency,
    required this.issuedAt,
    required this.dueCents,
  });

  final String id;
  final String number;
  final String memberName;
  final String currency;
  final DateTime issuedAt;

  /// What is still due: the total, or the remainder of a standing partial
  /// payment.
  final int dueCents;
}

/// The invoices of [invoices] that still wait for money, with what each
/// still owes: not void, not a credit note, not carried by a settlement,
/// and either unmatched or standing on an accepted partial payment that
/// was not written off. A match awaiting the validators holds its invoice.
List<OpenInvoice> openInvoices(
  Iterable<Invoice> invoices,
  Map<String, InvoiceMatch> matches,
) => [
  for (final i in invoices)
    if (!i.isVoided && i.totalCents > 0 && i.settledByInvoiceId == null)
      if (_stillDue(i, matches[i.id]) case final due? when due > 0)
        OpenInvoice(
          id: i.id,
          number: i.number,
          memberName: i.memberName,
          currency: i.currency,
          issuedAt: i.issuedAt,
          dueCents: due,
        ),
];

int? _stillDue(Invoice invoice, InvoiceMatch? match) {
  if (match == null) return invoice.totalCents;
  final standingPartial =
      !match.pending &&
      match.resolution == 'under_accepted' &&
      match.writeoffAt == null;
  return standingPartial ? invoice.totalCents - match.paidCents : null;
}

/// One invoice a movement may settle, and why.
@immutable
class BankMatchSuggestion {
  const BankMatchSuggestion(this.invoice, this.basis);

  final OpenInvoice invoice;
  final BankMatchBasis basis;
}

/// The invoices [line] may settle, strongest reason first, each invoice
/// once. Only money in that settles nothing yet is matched; [windowDays]
/// is the setting `bank.match_window_days`.
List<BankMatchSuggestion> suggestMatches(
  StoredBankLine line,
  List<OpenInvoice> open, {
  required int windowDays,
}) {
  final matchable =
      line.isMoneyIn &&
      (line.status == BankLineStatus.open ||
          line.status == BankLineStatus.recorded);
  if (!matchable) return const [];
  final candidates = [
    for (final i in open)
      if (i.currency == line.currency) i,
  ];
  final reference = line.reference.isNotEmpty
      ? line.reference
      : structuredReferenceIn(line.remittance) ?? '';
  final found = <String, BankMatchSuggestion>{};
  void add(OpenInvoice invoice, BankMatchBasis basis) =>
      found.putIfAbsent(invoice.id, () => BankMatchSuggestion(invoice, basis));
  for (final i in candidates) {
    if (reference.isEmpty) break;
    if (isQrReference(reference) && qrrReferenceOf(i.number) == reference) {
      add(i, BankMatchBasis.qrReference);
    } else if (isCreditorReference(reference) &&
        scorReferenceOf(i.number) == reference) {
      add(i, BankMatchBasis.creditorReference);
    }
  }
  final text = '${line.remittance} ${line.reference} ${line.endToEndId}'
      .toUpperCase();
  for (final i in candidates) {
    if (_names(text, i.number)) add(i, BankMatchBasis.invoiceNumber);
  }
  final b = line.bookingDate;
  final earliest = DateTime.utc(b.year, b.month, b.day - windowDays);
  for (final i in candidates) {
    final issued = DateTime.utc(
      i.issuedAt.year,
      i.issuedAt.month,
      i.issuedAt.day,
    );
    if (i.dueCents == line.amountCents &&
        !issued.isBefore(earliest) &&
        !issued.isAfter(line.bookingDate) &&
        _samePayer(line.counterpartyName, i.memberName)) {
      add(i, BankMatchBasis.amount);
    }
  }
  return found.values.toList()
    ..sort((a, b) => a.basis.index.compareTo(b.basis.index));
}

/// The one invoice a structured reference names for the whole amount
/// still due: what a person may confirm for many movements at once. Null
/// when the reference names none, or the amount differs (then the
/// resolution is the person's to choose, one by one).
BankMatchSuggestion? referenceMatchOf(
  StoredBankLine line,
  List<OpenInvoice> open, {
  required int windowDays,
}) {
  final suggestions = suggestMatches(line, open, windowDays: windowDays);
  final structured = [
    for (final s in suggestions)
      if (s.basis.isStructured) s,
  ];
  if (structured.length != 1) return null;
  final only = structured.single;
  return only.invoice.dueCents == line.amountCents ? only : null;
}

/// Whether [text] (upper case) names [number] as a whole word: a number
/// inside a longer one ("2026-00421" for "2026-0042") does not count.
bool _names(String text, String number) {
  final n = number.trim().toUpperCase();
  if (n.isEmpty || !n.contains(RegExp('[0-9]'))) return false;
  return RegExp(
    '(?<![A-Z0-9])${RegExp.escape(n)}(?![A-Z0-9])',
  ).hasMatch(text);
}

/// The shortest word of a name that tells two people apart; shorter ones
/// ("de", "SA", initials) are shared by too many.
const int _nameWordMin = 3;

/// Whether a payer's name and a member's share a word of their names,
/// case aside: "M. DUPONT JEAN" and "Jean Dupont".
bool _samePayer(String payer, String member) {
  Set<String> words(String s) => {
    for (final w in s.toUpperCase().split(RegExp(r'[^\p{L}0-9]+', unicode: true)))
      if (w.length >= _nameWordMin) w,
  };
  final a = words(payer);
  return a.isNotEmpty && a.intersection(words(member)).isNotEmpty;
}
