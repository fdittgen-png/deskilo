// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 — what the books receive: one posting per document event, each one
// journal, one date, one document, its lines balanced to the cent. Every
// exporter serialises the same postings (the posting contract of #2365);
// the rules that derive them are `posting_rules.dart`.
//
// Pure Dart; every amount is an [AccountingAmount], never a double.

import '../../../core/data/json_reader.dart';
import 'accounting_amount.dart';
import 'book_chart.dart';

enum PostingBlock {
  /// The currency has no reviewed exponent.
  unsupportedCurrency,

  /// A role the posting needs has no mapping for the document's day.
  unmappedRole,

  /// The mapped account is gone, not a posting account, or of a type
  /// that does not fit the role.
  badAccount,

  /// A tax component nobody classified.
  unclassifiedTax,

  /// Amounts in more than one currency met in one document.
  currencyMismatch,

  /// A sum past ±(2^53 − 1) minor units.
  outOfRange,

  /// #2365 — a document whose parts do not add up to its total.
  unbalanced,

  /// A document in another currency than the space's with no exchange
  /// rate recorded for it, named `reference (currency)`.
  missingRate,
}

class PostingBlocker {
  const PostingBlocker(this.block, this.subject);
  final PostingBlock block;

  /// The role, currency or tax the block is about.
  final String subject;

  @override
  String toString() => 'PostingBlocker(${block.name}: $subject)';
}

class PostingLine {
  const PostingLine({
    required this.role,
    required this.accountCode,
    required this.debit,
    required this.credit,
    this.qualifier,
    this.original,
  });

  final BookRole role;

  /// The rate group or provider of a qualified role (`revenue:standard`),
  /// null for the base.
  final String? qualifier;
  final String accountCode;

  /// Exactly one of the two is non-zero.
  final AccountingAmount debit;
  final AccountingAmount credit;

  /// The amount in the document's own currency this line was converted
  /// from at the document's recorded rate; null when the document is in
  /// the book's currency.
  final AccountingAmount? original;
}

/// The journal a posting belongs to, with its usual code.
enum PostingJournal {
  sales('VE'),
  bank('BQ'),
  purchases('HA'),
  other('OD');

  const PostingJournal(this.code);
  final String code;
}

/// The event of a document a posting books.
enum PostingKind {
  invoice('invoice'),
  creditNote('credit_note'),
  receipt('receipt'),
  refund('refund'),
  writeOff('write_off'),
  expense('expense'),
  supplierBill('supplier_bill'),
  supplierCreditNote('supplier_credit_note'),
  supplierPayment('supplier_payment'),

  /// #2365 (0521) — output tax leaving `vat_pending` on its tax point.
  vatRelease('vat_release'),

  /// #2365 (0524) — a member's approved receipt, credited to the member's
  /// account, and the money paid back to them.
  memberReceipt('member_receipt'),
  reimbursement('reimbursement'),

  /// #3152 (0622) — the acquisition tax of a service bought abroad: input
  /// VAT for its deductible share, output VAT for the tax owed.
  acquisitionTax('acquisition_tax');

  const PostingKind(this.wire);
  final String wire;
}

/// One entry of the books.
class Posting {
  const Posting({
    required this.journal,
    required this.date,
    required this.kind,
    required this.documentId,
    required this.documentNumber,
    required this.lines,
    this.valueDate,
    this.bankReference = '',
  });

  final PostingJournal journal;
  final DateTime date;
  final PostingKind kind;
  final String documentId;
  final String documentNumber;
  final List<PostingLine> lines;

  /// #2380 (0635) — the value date of the bank statement line an invoice's
  /// receipt was reconciled with: the day the money moved at the bank, a
  /// fact apart from [date] (the day the entry was booked). Null when no
  /// statement line is linked to the entry.
  final DateTime? valueDate;

  /// The reference the bank gave that line; '' when there is none.
  final String bankReference;

  /// Debits equal credits, exactly.
  bool get balanced {
    var debit = 0;
    var credit = 0;
    for (final l in lines) {
      debit += l.debit.minor;
      credit += l.credit.minor;
    }
    return lines.isNotEmpty && debit == credit;
  }
}

/// The postings of a period, or what stops them.
class PostingSet {
  const PostingSet(this.postings, this.blockers);

  /// The server's answer (`compute_postings`, 0518).
  factory PostingSet.fromJson(Map<String, Object?> json) {
    final r = JsonReader(json, context: 'compute_postings');
    return PostingSet(
      [for (final p in r.list('postings')) _postingFromJson(p)],
      [
        for (final b in r.list('blockers'))
          _blockerFromJson(JsonReader.of(b, context: 'posting blocker')),
      ],
    );
  }

  final List<Posting> postings;
  final List<PostingBlocker> blockers;
}

PostingBlocker _blockerFromJson(JsonReader r) => PostingBlocker(
  PostingBlock.values.byName(r.string('block')),
  r.string('subject'),
);

Posting _postingFromJson(Object? raw) {
  final r = JsonReader.of(raw, context: 'posting');
  final currency = r.string('currency');
  final original = r.stringOrNull('original_currency');
  return Posting(
    journal: PostingJournal.values.byName(r.string('journal')),
    date: r.dateTime('date'),
    kind: PostingKind.values.firstWhere((k) => k.wire == r.string('kind')),
    documentId: r.string('document_id'),
    documentNumber: r.string('document_number'),
    valueDate: r.dateTimeOrNull('value_date'),
    bankReference: r.stringOr('bank_reference'),
    lines: [
      for (final l in r.list('lines'))
        _lineFromJson(
          JsonReader.of(l, context: 'posting line'),
          currency,
          original,
        ),
    ],
  );
}

PostingLine _lineFromJson(JsonReader r, String currency, String? original) =>
    PostingLine(
      role: BookRole.fromWire(r.string('role')),
      qualifier: r.stringOrNull('qualifier'),
      accountCode: r.string('account_code'),
      debit: AccountingAmount(currency, r.integer('debit_cents')),
      credit: AccountingAmount(currency, r.integer('credit_cents')),
      original: original == null
          ? null
          : AccountingAmount(original, r.integer('original_cents')),
    );

/// #2376 (0525) — the third party of a posted document: the member of an
/// invoice or of a receipt, the supplier of a bill, by number and name. The
/// FEC's auxiliary account (CompAuxNum / CompAuxLib).
class PostingParty {
  const PostingParty({
    required this.kind,
    required this.number,
    required this.name,
  });

  factory PostingParty.fromJson(Map<String, Object?> json) {
    final r = JsonReader(json, context: 'posting_parties');
    return PostingParty(
      kind: r.string('kind'),
      number: r.stringOr('number'),
      name: r.stringOr('name'),
    );
  }

  /// `member` or `supplier`.
  final String kind;
  final String number;
  final String name;
}
