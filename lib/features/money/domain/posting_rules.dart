// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 — the posting rules: how the documents of a period become entries of
// the books, resolved on the issuer's chart. One unit, pure, the reference
// the server engine (`compute_postings`) is held to.
//
//   * invoice: Dr customers the gross; Cr `revenue:<group>` the net and Cr
//     `vat_output:<group>` the tax, per rate group. A credit note is the
//     same entry mirrored. A credit netted on it (#2542) is its own entry
//     on the invoice day: a payment Dr bank / Cr customers, an expense the
//     one purchase entry Dr expenses / Cr customers, never a bank movement.
//     A voided invoice and a settlement book nothing:
//     the settlement's payment is allocated to its sources
//     ([accountingView]).
//   * receipt (a confirmed match): Dr bank / Cr customers on the match day;
//     a negative match is a refund and mirrors it.
//   * write-off (`writeoffAt`): Dr `write_off` the net and Dr
//     `vat_output:<group>` the tax regularised of the open rest, split over
//     the rate groups by their gross; Cr customers that rest.
//
// A qualified role resolves first and falls back to its base; a base with
// no mapping blocks with the role named. Nothing is guessed.

import 'accounting_amount.dart';
import 'accounting_view.dart';
import 'book_chart.dart';
import 'invoice.dart';
import 'posting.dart';
import 'vat_rate.dart';

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
PostingSet postingsOf({
  required List<Invoice> invoices,
  required Map<String, InvoiceMatch> matches,
  required PostingBook book,
  required String Function(InvoiceVatTotal total) groupOf,
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
    postings.addAll([
      ..._document(invoice, book, groupOf),
      ..._settled(invoice, view.matches[invoice.id], book, groupOf),
    ]);
  }
  postings.sort(_order);
  return PostingSet(postings, book.blockers);
}

int _order(Posting a, Posting b) {
  final byDate = a.date.compareTo(b.date);
  if (byDate != 0) return byDate;
  final byJournal = a.journal.index.compareTo(b.journal.index);
  if (byJournal != 0) return byJournal;
  return a.documentNumber.compareTo(b.documentNumber);
}

AccountingAmount _amount(Invoice i, int minor) =>
    AccountingAmount(i.currency, minor);

/// A line for [minor] on [role]: positive to [debitSide], negative mirrored,
/// zero dropped.
PostingLine? _line(
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
  String Function(InvoiceVatTotal) groupOf,
) {
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
      ?_line(role, book.code(role, day), _amount(i, cents), debitSide: true),
      ?_line(
        BookRole.customers,
        book.code(BookRole.customers, day),
        _amount(i, cents),
        debitSide: false,
      ),
    ],
  );
  final lines = <PostingLine>[
    ?_line(
      BookRole.customers,
      book.code(BookRole.customers, day),
      _amount(i, gross),
      debitSide: true,
    ),
    for (final p in parts) ...[
      ?_line(
        BookRole.revenue,
        book.code(BookRole.revenue, day, qualifier: p.group),
        _amount(i, p.net),
        debitSide: false,
        qualifier: p.group,
      ),
      if (p.vat != 0)
        ?_line(
          BookRole.vatOutput,
          book.code(BookRole.vatOutput, day, qualifier: p.group),
          _amount(i, p.vat),
          debitSide: false,
          qualifier: p.group,
        ),
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
    // A netted payment is money in on the bank; a netted expense is the
    // one purchase entry, never a bank movement (#2542).
    if (paid != 0)
      netted(PostingJournal.bank, PostingKind.receipt, BookRole.bank, paid),
    if (spent != 0)
      netted(
        PostingJournal.purchases,
        PostingKind.expense,
        BookRole.expenses,
        spent,
      ),
  ];
}

/// The receipt or refund of [m], and the write-off of what it left open.
List<Posting> _settled(
  Invoice i,
  InvoiceMatch? m,
  PostingBook book,
  String Function(InvoiceVatTotal) groupOf,
) {
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
          ?_line(
            BookRole.bank,
            book.code(BookRole.bank, m.matchedAt),
            _amount(i, m.paidCents),
            debitSide: true,
          ),
          ?_line(
            BookRole.customers,
            book.code(BookRole.customers, m.matchedAt),
            _amount(i, m.paidCents),
            debitSide: false,
          ),
        ],
      ),
    if (m.writeoffAt case final day? when i.totalCents - m.paidCents > 0)
      _writeOff(i, i.totalCents - m.paidCents, day, book, groupOf),
  ];
}

/// [rest] of [i] written off on [day]: split over the rate groups by their
/// gross (the last group takes the rounding), each part into net and tax by
/// its own ratio.
Posting _writeOff(
  Invoice i,
  int rest,
  DateTime day,
  PostingBook book,
  String Function(InvoiceVatTotal) groupOf,
) {
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
      ?_line(
        BookRole.writeOff,
        book.code(BookRole.writeOff, day),
        _amount(i, part - tax),
        debitSide: true,
      ),
      ?_line(
        BookRole.vatOutput,
        book.code(BookRole.vatOutput, day, qualifier: t.group),
        _amount(i, tax),
        debitSide: true,
        qualifier: t.group,
      ),
    ]);
  }
  final customers = _line(
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
