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

/// The open invoices prepared once for many movements: their references
/// and numbers computed a single time, by currency.
class _OpenIndex {
  _OpenIndex(List<OpenInvoice> open) {
    for (final i in open) {
      (byCurrency[i.currency] ??= []).add(i);
      if (qrrReferenceOf(i.number) case final r?) (byQr[r] ??= []).add(i);
      if (scorReferenceOf(i.number) case final r?) (byRf[r] ??= []).add(i);
      final n = i.number.trim().toUpperCase();
      if (n.isNotEmpty && n.contains(RegExp('[0-9]'))) numbers[i.id] = n;
    }
  }

  final byCurrency = <String, List<OpenInvoice>>{};
  final byQr = <String, List<OpenInvoice>>{};
  final byRf = <String, List<OpenInvoice>>{};
  final numbers = <String, String>{};

  List<BankMatchSuggestion> suggest(StoredBankLine line, int windowDays) {
    final matchable =
        line.isMoneyIn &&
        (line.status == BankLineStatus.open ||
            line.status == BankLineStatus.recorded);
    if (!matchable) return const [];
    final candidates = byCurrency[line.currency] ?? const <OpenInvoice>[];
    if (candidates.isEmpty) return const [];
    final reference = line.reference.isNotEmpty
        ? line.reference
        : structuredReferenceIn(line.remittance) ?? '';
    final found = <String, BankMatchSuggestion>{};
    void add(OpenInvoice invoice, BankMatchBasis basis) => found.putIfAbsent(
      invoice.id,
      () => BankMatchSuggestion(invoice, basis),
    );
    if (reference.isNotEmpty) {
      final (named, basis) = isQrReference(reference)
          ? (byQr[reference], BankMatchBasis.qrReference)
          : isCreditorReference(reference)
          ? (byRf[reference], BankMatchBasis.creditorReference)
          : (null, BankMatchBasis.qrReference);
      for (final i in named ?? const <OpenInvoice>[]) {
        if (i.currency == line.currency) add(i, basis);
      }
    }
    final text = '${line.remittance} ${line.reference} ${line.endToEndId}'
        .toUpperCase();
    for (final i in candidates) {
      final n = numbers[i.id];
      if (n != null && _names(text, n)) add(i, BankMatchBasis.invoiceNumber);
    }
    final b = line.bookingDate;
    final earliest = DateTime.utc(b.year, b.month, b.day - windowDays);
    final payer = _nameWords(line.counterpartyName);
    for (final i in candidates) {
      final issued = DateTime.utc(
        i.issuedAt.year,
        i.issuedAt.month,
        i.issuedAt.day,
      );
      if (i.dueCents == line.amountCents &&
          !issued.isBefore(earliest) &&
          !issued.isAfter(line.bookingDate) &&
          payer.isNotEmpty &&
          payer.intersection(_nameWords(i.memberName)).isNotEmpty) {
        add(i, BankMatchBasis.amount);
      }
    }
    return found.values.toList()
      ..sort((a, b) => a.basis.index.compareTo(b.basis.index));
  }
}

/// The one invoice a structured reference names for the whole amount
/// still due: what a person may confirm for many movements at once. Null
/// when the reference names none or several, or the amount differs (then
/// the resolution is the person's to choose, one by one).
BankMatchSuggestion? _referenceMatch(
  StoredBankLine line,
  List<BankMatchSuggestion> suggestions,
) {
  final structured = [
    for (final s in suggestions)
      if (s.basis.isStructured) s,
  ];
  if (structured.length != 1) return null;
  final only = structured.single;
  return only.invoice.dueCents == line.amountCents ? only : null;
}

/// One movement of the work list with what it may settle, computed once
/// per load of its statement.
@immutable
class BankWorkItem {
  const BankWorkItem(this.line, this.suggestions, this.referenceMatch);

  final StoredBankLine line;
  final List<BankMatchSuggestion> suggestions;

  /// The one invoice its structured reference names for exactly what it
  /// owes, or null.
  final BankMatchSuggestion? referenceMatch;
}

/// The work list of a statement: every movement with its suggestions,
/// the open invoices prepared once; and [open] itself, the dialogs' list.
@immutable
class BankWorkList {
  BankWorkList(List<StoredBankLine> lines, this.open, {required int windowDays})
    : items = _items(lines, open, windowDays);

  final List<OpenInvoice> open;
  final List<BankWorkItem> items;

  static List<BankWorkItem> _items(
    List<StoredBankLine> lines,
    List<OpenInvoice> open,
    int windowDays,
  ) {
    final index = _OpenIndex(open);
    BankWorkItem item(StoredBankLine l) {
      final s = index.suggest(l, windowDays);
      return BankWorkItem(l, s, _referenceMatch(l, s));
    }

    return [for (final l in lines) item(l)];
  }

  /// The movements a person may confirm in one press: each invoice once,
  /// for the first movement naming it; a second movement carrying the
  /// same reference waits for its own decision.
  List<BankWorkItem> get referenceBatch {
    final taken = <String>{};
    return [
      for (final item in items)
        if (item.referenceMatch case final m?)
          if (taken.add(m.invoice.id)) item,
    ];
  }
}

/// Whether [text] (upper case) names [number] (upper case) as a whole
/// word: a number inside a longer one ("2026-00421" for "2026-0042") does
/// not count.
bool _names(String text, String number) {
  bool alnum(int c) =>
      (c >= 48 && c <= 57) || (c >= 65 && c <= 90);
  for (var at = text.indexOf(number); at >= 0; at = text.indexOf(number, at + 1)) {
    final end = at + number.length;
    final before = at == 0 || !alnum(text.codeUnitAt(at - 1));
    final after = end == text.length || !alnum(text.codeUnitAt(end));
    if (before && after) return true;
  }
  return false;
}

/// The shortest word of a name that tells two people apart; shorter ones
/// ("de", "SA", initials) are shared by too many.
const int _nameWordMin = 3;

/// A heuristic of the suggestion by amount, not configuration: words that
/// name a company's legal form, not who it is, so two companies sharing
/// one are not taken for one payer. A missed form only adds a suggestion a
/// person still confirms; it never matches anything by itself.
const Set<String> _legalFormWords = {
  'SARL', 'SAS', 'SASU', 'EURL', 'GMBH', 'LTD', 'LLC', 'INC', 'SRL', 'SPRL',
  'BVBA', 'SPA', 'SNC',
};

/// The words of a name that tell a payer apart, case aside: "M. DUPONT
/// JEAN" and "Jean Dupont" share DUPONT and JEAN.
Set<String> _nameWords(String name) => {
  for (final w in name.toUpperCase().split(RegExp(r'[^\p{L}0-9]+', unicode: true)))
    if (w.length >= _nameWordMin && !_legalFormWords.contains(w)) w,
};
