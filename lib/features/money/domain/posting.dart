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
  });

  final BookRole role;

  /// The rate group or provider of a qualified role (`revenue:standard`),
  /// null for the base.
  final String? qualifier;
  final String accountCode;

  /// Exactly one of the two is non-zero.
  final AccountingAmount debit;
  final AccountingAmount credit;
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
  supplierPayment('supplier_payment');

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
  });

  final PostingJournal journal;
  final DateTime date;
  final PostingKind kind;
  final String documentId;
  final String documentNumber;
  final List<PostingLine> lines;

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
  return Posting(
    journal: PostingJournal.values.byName(r.string('journal')),
    date: r.dateTime('date'),
    kind: PostingKind.values.firstWhere((k) => k.wire == r.string('kind')),
    documentId: r.string('document_id'),
    documentNumber: r.string('document_number'),
    lines: [
      for (final l in r.list('lines'))
        _lineFromJson(JsonReader.of(l, context: 'posting line'), currency),
    ],
  );
}

PostingLine _lineFromJson(JsonReader r, String currency) => PostingLine(
  role: BookRole.fromWire(r.string('role')),
  qualifier: r.stringOrNull('qualifier'),
  accountCode: r.string('account_code'),
  debit: AccountingAmount(currency, r.integer('debit_cents')),
  credit: AccountingAmount(currency, r.integer('credit_cents')),
);
