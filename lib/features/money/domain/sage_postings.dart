// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2373 — Sage 50's audit trail written from a local book's postings (the
// posting engine's `compute_postings`, read once for the export), on the
// book's own chart. The transaction type follows the posting's event:
//
//   invoice SI, credit note SC (one row per revenue line, net and tax with
//   the code of its rate group), receipt SR and refund SP (the bank line),
//   supplier bill PI, supplier credit note PC (one row per expense line with
//   its recoverable input tax), supplier payment PP; every other event (a
//   write-off, a member's receipt and its reimbursement) one JD or JC per
//   line, without tax (T9).
//
// It serialises the postings and decides nothing: an entry the engine
// blocked never reaches it. Output tax waiting for its tax point
// (`vat_pending`) and an amount in another currency than the book's stop
// the file, named; so does a party with no number Sage can key it to.
import 'book_chart.dart';
import 'invoice.dart';
import 'posting.dart';
import 'sage.dart';
import 'sage_documents.dart';
import 'vat_rate.dart';

/// What the posted audit trail is written on: the tax codes of
/// [accounts], the customers' countries of [customers], and the book's
/// currency, the only one Sage is given.
typedef SageBook = ({
  SageAccounts accounts,
  SageCustomers customers,
  String baseCurrency,
});

/// The audit trail of [postings] in their order, on [book]. [parties]
/// names each document's customer or supplier, [documents] the sales
/// documents by id (their VAT categories and their customer's country),
/// [kindText] each event in the Details column.
SageAuditTrail sageRowsOfPostings(
  List<Posting> postings, {
  required SageBook book,
  required Map<String, PostingParty> parties,
  required Map<String, Invoice> documents,
  required String Function(PostingKind kind) kindText,
}) {
  final (:accounts, :customers, :baseCurrency) = book;
  final rows = <SageRow>[];
  final blockers = <SageBlocker>{};
  for (final p in postings) {
    final currencies = {
      for (final l in p.lines) ...[l.debit.currency, l.credit.currency],
    };
    if (currencies.any((c) => c.toUpperCase() != baseCurrency.toUpperCase())) {
      blockers.add(
        SageBlocker(
          SageBlock.currency,
          '${p.documentNumber} (${currencies.join(', ')})',
        ),
      );
      continue;
    }
    if (p.lines.any((l) => l.role == BookRole.vatPending)) {
      blockers.add(SageBlocker(SageBlock.deferredTax, p.documentNumber));
      continue;
    }
    final entry = _Entry(
      p,
      accounts,
      currency: baseCurrency,
      details: '${p.documentNumber} ${kindText(p.kind)}',
    );
    final type = _ledgerType[p.kind];
    if (type == null) {
      entry.journal(rows);
      continue;
    }
    final party = parties[p.documentId];
    final account = sageAccountReferenceRule.admit(party?.number ?? '');
    if (account == null) {
      blockers.add(
        SageBlocker(
          SageBlock.accountReference,
          party?.name.isNotEmpty ?? false ? party!.name : p.documentNumber,
        ),
      );
      continue;
    }
    entry.ledger(
      rows,
      blockers,
      type,
      account: account,
      document: documents[p.documentId],
      customers: customers,
    );
  }
  return sageAuditTrail(rows, blockers);
}

/// The Sage type of each event booked on a customer's or supplier's
/// ledger; every other event is a journal.
const Map<PostingKind, String> _ledgerType = {
  PostingKind.invoice: 'SI',
  PostingKind.creditNote: 'SC',
  PostingKind.receipt: 'SR',
  PostingKind.refund: 'SP',
  PostingKind.supplierBill: 'PI',
  PostingKind.supplierCreditNote: 'PC',
  PostingKind.supplierPayment: 'PP',
};

bool _onDebit(PostingLine l) => l.debit.minor != 0;

int _amount(PostingLine l) => _onDebit(l) ? l.debit.minor : l.credit.minor;

bool _isTax(PostingLine l) =>
    l.role == BookRole.vatOutput || l.role == BookRole.vatInput;

bool _isParty(PostingLine l) =>
    l.role == BookRole.customers || l.role == BookRole.suppliers;

/// One posting's rows.
class _Entry {
  _Entry(
    this.p,
    this.accounts, {
    required this.currency,
    required this.details,
  });

  final Posting p;
  final SageAccounts accounts;
  final String currency;
  final String details;

  SageRow _row(
    String type,
    PostingLine line, {
    String account = '',
    String? code,
    int tax = 0,
    String country = '',
  }) => SageRow(
    type: type,
    account: account,
    nominal: line.accountCode,
    date: p.date,
    reference: p.documentNumber,
    details: details,
    netMinor: _amount(line),
    taxCode: code ?? accounts.noTax,
    taxMinor: tax,
    currency: currency,
    countryOfVat: country,
  );

  /// One JD or JC per line, without tax.
  void journal(List<SageRow> rows) {
    for (final l in p.lines) {
      rows.add(_row(_onDebit(l) ? 'JD' : 'JC', l));
    }
  }

  void ledger(
    List<SageRow> rows,
    Set<SageBlocker> blockers,
    String type, {
    required String account,
    required Invoice? document,
    required SageCustomers customers,
  }) {
    switch (type) {
      case 'SR' || 'SP' || 'PP':
        // The money: the bank line, without tax.
        for (final l in p.lines.where((l) => l.role == BookRole.bank)) {
          rows.add(_row(type, l, account: account));
        }
      default:
        _documentRows(
          rows,
          blockers,
          type,
          account: account,
          document: document,
          euCountry: document == null ? '' : customers.euCountryOf(document),
        );
    }
  }

  /// An invoice's, a credit note's or a bill's rows: each line that is not
  /// the party's or a tax line, with the tax line booked right after it on
  /// the same side, as the posting rules write them.
  void _documentRows(
    List<SageRow> rows,
    Set<SageBlocker> blockers,
    String type, {
    required String account,
    required Invoice? document,
    required String euCountry,
  }) {
    final lines = p.lines;
    for (var i = 0; i < lines.length; i++) {
      final base = lines[i];
      if (_isParty(base)) continue;
      if (_isTax(base)) {
        // A tax line no base line carries cannot be stated in Sage.
        blockers.add(SageBlocker(SageBlock.taxCode, p.documentNumber));
        continue;
      }
      final next = i + 1 < lines.length ? lines[i + 1] : null;
      final tax = next != null && _isTax(next) && _onDebit(next) == _onDebit(base)
          ? next
          : null;
      if (tax != null) i++;
      final group = tax?.qualifier ?? base.qualifier ?? '';
      final category = group.isEmpty ? _untaxedCategory(document) : 'S';
      final code = category == null
          ? null
          : accounts.codeOf(group, category, euCustomer: euCountry.isNotEmpty);
      if (code == null) {
        final what = category == null ? 'mixed' : group;
        blockers.add(
          SageBlocker(SageBlock.taxCode, '${p.documentNumber} ($what)'),
        );
        continue;
      }
      rows.add(
        _row(
          type,
          base,
          account: account,
          code: code,
          tax: tax == null ? 0 : _amount(tax),
          country: accounts.crossBorder(code) ? euCountry : '',
        ),
      );
    }
  }

  /// The one VAT category of [document]'s untaxed breakdown lines (a
  /// revenue line the engine books with no rate group): out of scope when
  /// it has none or is no sales document; null when its untaxed lines are
  /// of several categories, which one Sage row per line cannot tell apart.
  String? _untaxedCategory(Invoice? document) {
    final categories = {
      for (final t in document?.vatTotals ?? const <InvoiceVatTotal>[])
        if (t.vatCents == 0) t.category,
    };
    return switch (categories.length) {
      0 => 'O',
      1 => categories.single,
      _ => null,
    };
  }
}
