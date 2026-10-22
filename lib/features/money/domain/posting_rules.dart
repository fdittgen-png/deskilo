// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 — the posting rules: how the documents of a period become entries of
// the books, resolved on the issuer's chart. One unit, pure, the reference
// the server engine (`compute_postings`) is held to.
//
//   * invoice: Dr customers the gross; Cr `revenue:<group>` the net and Cr
//     `vat_output:<group>` the tax, per rate group. A credit note is the
//     same entry mirrored. A payment netted on it (#2542) is its own entry
//     on the invoice day, Dr bank / Cr customers. A netted expense credit
//     books nothing (0524): the member's receipt booked the expense against
//     the member's account (posting_rules_purchases.dart).
//     A voided invoice and a settlement book nothing:
//     the settlement's payment is allocated to its sources
//     ([accountingView]).
//   * receipt (a confirmed match): Dr bank / Cr customers on the match day;
//     a negative match is a refund and mirrors it.
//   * write-off (`writeoffAt`): Dr `write_off` the net and Dr
//     `vat_output:<group>` the tax regularised of the open rest, split over
//     the rate groups by their gross; Cr customers that rest.
//   * tax point (0521): an invoice whose output tax is not exactly due on
//     its issue day credits it to `vat_pending`; each tax point releases
//     its share, Dr `vat_pending` / Cr `vat_output:<group>`.
//
// A qualified role resolves first and falls back to its base; a base with
// no mapping blocks with the role named. Nothing is guessed.

import 'accounting_amount.dart';
import 'accounting_view.dart';
import 'book_chart.dart';
import 'invoice.dart';
import 'posting.dart';
import 'vat_rate.dart';
import 'vat_tax_point.dart';

/// The issuer's chart a posting resolves on.
class PostingBook {
  PostingBook({
    required this.accounts,
    required this.mappings,
    required this.issuerSiteId,
  });

  final List<BookAccount> accounts;
  final List<BookMapping> mappings;
  final String issuerSiteId;
  final _blockers = <String, PostingBlocker>{};

  /// What stopped a role or an amount, each named once.
  List<PostingBlocker> get blockers => _blockers.values.toList();

  void block(PostingBlock block, String subject) =>
      _blockers.putIfAbsent('${block.name}:$subject', () {
        return PostingBlocker(block, subject);
      });

  /// The account [role] (qualified by [qualifier]) books to on [day].
  String? code(BookRole role, DateTime day, {String? qualifier}) {
    final m =
        (qualifier == null ? null : _qualified(role, qualifier, day)) ??
        mappingOn(mappings, issuerSiteId, role, day);
    if (m == null) {
      block(PostingBlock.unmappedRole, role.wire);
      return null;
    }
    final account = accounts.where((a) => a.id == m.accountId).firstOrNull;
    if (account == null ||
        mappingProblem(role, account, issuerSiteId) != null) {
      block(PostingBlock.badAccount, role.wire);
      return null;
    }
    return account.code;
  }

  BookMapping? _qualified(BookRole role, String qualifier, DateTime day) {
    BookMapping? best;
    for (final m in mappings) {
      if (m.issuerSiteId != issuerSiteId ||
          m.role != role ||
          m.qualifier != qualifier ||
          m.effectiveFrom.isAfter(day)) {
        continue;
      }
      if (best == null || m.effectiveFrom.isAfter(best.effectiveFrom)) {
        best = m;
      }
    }
    return best;
  }
}

/// The postings of [invoices] and their [matches], on [book]. [groupOf]
/// names the rate group of a VAT total (the tax reference's `rate` rows).
/// With [taxPoints], tax not due on the issue day waits on `vat_pending`.
PostingSet postingsOf({
  required List<Invoice> invoices,
  required Map<String, InvoiceMatch> matches,
  required PostingBook book,
  required String Function(InvoiceVatTotal total) groupOf,
  VatTaxPointIndex? taxPoints,
}) {
  final view = accountingView(invoices, matches);
  final postings = <Posting>[];
  for (final invoice in view.invoices) {
    if (invoice.isVoided) continue;
    try {
      exponentOf(invoice.currency);
    } on AccountingException {
      book.block(PostingBlock.unsupportedCurrency, invoice.currency);
      continue;
    }
    final deferred = _deferred(invoice, taxPoints);
    postings.addAll([
      ..._document(invoice, book, groupOf, deferred: deferred),
      ..._settled(
        invoice,
        view.matches[invoice.id],
        book,
        groupOf,
        deferred: deferred,
      ),
      if (deferred) ..._released(invoice, taxPoints!, book, groupOf),
    ]);
  }
  postings.sort(comparePostings);
  return PostingSet(postings, book.blockers);
}

/// The books' order: by date, then journal, then document number.
int comparePostings(Posting a, Posting b) {
  final byDate = a.date.compareTo(b.date);
  if (byDate != 0) return byDate;
  final byJournal = a.journal.index.compareTo(b.journal.index);
  if (byJournal != 0) return byJournal;
  return a.documentNumber.compareTo(b.documentNumber);
}

AccountingAmount _amount(Invoice i, int minor) =>
    AccountingAmount(i.currency, minor);

/// A line of [amount] on [role]: positive to [debitSide], negative
/// mirrored, zero dropped. The purchase rules (posting_rules_purchases.dart)
/// build theirs with it too.
PostingLine? postingLine(
  BookRole role,
  String? code,
  AccountingAmount amount, {
  required bool debitSide,
  String? qualifier,
}) {
  if (code == null || amount.minor == 0) return null;
  final zero = AccountingAmount(amount.currency, 0);
  final abs = amount.minor < 0 ? -amount : amount;
  final onDebit = (amount.minor > 0) == debitSide;
  return PostingLine(
    role: role,
    qualifier: qualifier,
    accountCode: code,
    debit: onDebit ? abs : zero,
    credit: onDebit ? zero : abs,
  );
}

/// One rate group of a document: its gross, net and tax, and the group
/// that qualifies its roles (null: the bases, for an untaxed document).
typedef _Part = ({int gross, int net, int vat, String? group});

/// The parts of [i]: one per VAT total, or one untaxed part of its amount.
List<_Part> _parts(Invoice i, String Function(InvoiceVatTotal) groupOf) =>
    i.vatTotals.isNotEmpty
    ? [
        for (final t in i.vatTotals)
          (
            gross: t.netCents + t.vatCents,
            net: t.netCents,
            vat: t.vatCents,
            group: groupOf(t),
          ),
      ]
    : [(gross: i.totalCents, net: i.totalCents, vat: 0, group: null)];

/// The untaxed credits netted on [i] (#2542): a payment the member made
/// and an expense advanced for the space, both reducing what is owed.
Iterable<InvoiceLine> _netted(Invoice i, String kind) => i.lines.where(
  (l) => l.kind == kind && l.vatPercent == 0 && l.amountCents < 0,
);

/// The taxed gross of [parts]: what a sales entry debits the customer.
int _gross(List<_Part> parts) => parts.fold<int>(0, (s, p) => s + p.gross);

List<Posting> _document(
  Invoice i,
  PostingBook book,
  String Function(InvoiceVatTotal) groupOf, {
  bool deferred = false,
}) {
  final day = i.issuedAt;
  final parts = _parts(i, groupOf);
  final gross = _gross(parts);
  final paid = _netted(i, 'payment').fold<int>(0, (s, l) => s - l.amountCents);
  final spent = _netted(i, 'expense').fold<int>(0, (s, l) => s - l.amountCents);
  if (gross - paid - spent != i.totalCents) {
    book.block(PostingBlock.unbalanced, i.number);
    return const [];
  }
  Posting netted(
    PostingJournal journal,
    PostingKind kind,
    BookRole role,
    int cents,
  ) => Posting(
    journal: journal,
    date: day,
    kind: kind,
    documentId: i.id,
    documentNumber: i.number,
    lines: [
      ?postingLine(role, book.code(role, day), _amount(i, cents), debitSide: true),
      ?postingLine(
        BookRole.customers,
        book.code(BookRole.customers, day),
        _amount(i, cents),
        debitSide: false,
      ),
    ],
  );
  final lines = <PostingLine>[
    ?postingLine(
      BookRole.customers,
      book.code(BookRole.customers, day),
      _amount(i, gross),
      debitSide: true,
    ),
    for (final p in parts) ...[
      ?postingLine(
        BookRole.revenue,
        book.code(BookRole.revenue, day, qualifier: p.group),
        _amount(i, p.net),
        debitSide: false,
        qualifier: p.group,
      ),
      if (p.vat != 0) ?_outputTax(i, p, book, day, deferred: deferred),
    ],
  ];
  return [
    Posting(
      journal: PostingJournal.sales,
      date: day,
      kind: i.isCreditNote ? PostingKind.creditNote : PostingKind.invoice,
      documentId: i.id,
      documentNumber: i.number,
      lines: lines,
    ),
    // A netted payment is money in on the bank (#2542); a netted expense
    // only settles the member's account its receipt credited (0524).
    if (paid != 0)
      netted(PostingJournal.bank, PostingKind.receipt, BookRole.bank, paid),
  ];
}

/// The output tax of part [p]: due now on `vat_output:<group>`, or waiting
/// on `vat_pending` for its tax point.
PostingLine? _outputTax(
  Invoice i,
  _Part p,
  PostingBook book,
  DateTime day, {
  required bool deferred,
}) => deferred
    ? postingLine(
        BookRole.vatPending,
        book.code(BookRole.vatPending, day),
        _amount(i, p.vat),
        debitSide: false,
      )
    : postingLine(
        BookRole.vatOutput,
        book.code(BookRole.vatOutput, day, qualifier: p.group),
        _amount(i, p.vat),
        debitSide: false,
        qualifier: p.group,
      );

/// Whether [i]'s output tax is not exactly due on its issue day.
bool _deferred(Invoice i, VatTaxPointIndex? taxPoints) {
  final vat = i.vatTotals.fold<int>(0, (s, t) => s + t.vatCents);
  final issued = DateTime(i.issuedAt.year, i.issuedAt.month, i.issuedAt.day);
  return taxPoints != null &&
      vat != 0 &&
      taxPoints.vatAwayFrom(i.id, issued, vat);
}

/// The tax of [i] released on each tax point, one entry per day and rate
/// group (as `compute_postings` groups them).
List<Posting> _released(
  Invoice i,
  VatTaxPointIndex taxPoints,
  PostingBook book,
  String Function(InvoiceVatTotal) groupOf,
) {
  final byDay = <DateTime, Map<String?, int>>{};
  for (final a in taxPoints.amountsOf(i.id)) {
    final group = groupOf(
      InvoiceVatTotal(
        percent: a.percent,
        category: 'S',
        grossCents: a.grossCents,
        netCents: a.netCents,
        vatCents: a.vatCents,
      ),
    );
    final day = byDay.putIfAbsent(a.on, () => {});
    final key = group.isEmpty ? null : group;
    day[key] = (day[key] ?? 0) + a.vatCents;
  }
  final days = byDay.keys.toList()..sort();
  return [
    for (final on in days)
      for (final MapEntry(key: group, value: vat) in byDay[on]!.entries)
        if (vat != 0)
          Posting(
            journal: PostingJournal.other,
            date: on,
            kind: PostingKind.vatRelease,
            documentId: i.id,
            documentNumber: i.number,
            lines: [
              ?postingLine(
                BookRole.vatPending,
                book.code(BookRole.vatPending, on),
                _amount(i, vat),
                debitSide: true,
              ),
              ?postingLine(
                BookRole.vatOutput,
                book.code(BookRole.vatOutput, on, qualifier: group),
                _amount(i, vat),
                debitSide: false,
                qualifier: group,
              ),
            ],
          ),
  ];
}

/// The receipt or refund of [m], and the write-off of what it left open.
List<Posting> _settled(
  Invoice i,
  InvoiceMatch? m,
  PostingBook book,
  String Function(InvoiceVatTotal) groupOf, {
  bool deferred = false,
}) {
  if (m == null || m.pending) return const [];
  return [
    if (m.paidCents != 0)
      Posting(
        journal: PostingJournal.bank,
        date: m.matchedAt,
        kind: m.paidCents < 0 ? PostingKind.refund : PostingKind.receipt,
        documentId: i.id,
        documentNumber: i.number,
        lines: [
          ?postingLine(
            BookRole.bank,
            book.code(BookRole.bank, m.matchedAt),
            _amount(i, m.paidCents),
            debitSide: true,
          ),
          ?postingLine(
            BookRole.customers,
            book.code(BookRole.customers, m.matchedAt),
            _amount(i, m.paidCents),
            debitSide: false,
          ),
        ],
      ),
    if (m.writeoffAt case final day? when i.totalCents - m.paidCents > 0)
      _writeOff(
        i,
        i.totalCents - m.paidCents,
        day,
        book,
        groupOf,
        deferred: deferred,
      ),
  ];
}

/// [rest] of [i] written off on [day]: split over the rate groups by their
/// gross (the last group takes the rounding), each part into net and tax by
/// its own ratio. The tax of a [deferred] invoice is cleared from
/// `vat_pending`, where its unpaid share still waits (0526).
Posting _writeOff(
  Invoice i,
  int rest,
  DateTime day,
  PostingBook book,
  String Function(InvoiceVatTotal) groupOf, {
  bool deferred = false,
}) {
  final parts = _parts(i, groupOf);
  final gross = _gross(parts);
  final lines = <PostingLine>[];
  var left = rest;
  for (var k = 0; k < parts.length; k++) {
    final t = parts[k];
    final part = k == parts.length - 1 || gross == 0
        ? left
        : rest * t.gross ~/ gross;
    left -= part;
    final tax = t.gross == 0 ? 0 : part * t.vat ~/ t.gross;
    lines.addAll([
      ?postingLine(
        BookRole.writeOff,
        book.code(BookRole.writeOff, day),
        _amount(i, part - tax),
        debitSide: true,
      ),
      // A deferred invoice's unpaid tax never left `vat_pending` (0526).
      if (deferred)
        ?postingLine(
          BookRole.vatPending,
          book.code(BookRole.vatPending, day),
          _amount(i, tax),
          debitSide: true,
        )
      else
        ?postingLine(
          BookRole.vatOutput,
          book.code(BookRole.vatOutput, day, qualifier: t.group),
          _amount(i, tax),
          debitSide: true,
          qualifier: t.group,
        ),
    ]);
  }
  final customers = postingLine(
    BookRole.customers,
    book.code(BookRole.customers, day),
    _amount(i, rest),
    debitSide: false,
  );
  if (customers != null) lines.add(customers);
  return Posting(
    journal: PostingJournal.other,
    date: day,
    kind: PostingKind.writeOff,
    documentId: i.id,
    documentNumber: i.number,
    lines: lines,
  );
}
