// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2373 — Sage 50's audit trail written from the documents, for an issuer
// that keeps no local book: each invoice's own VAT breakdown, one row per
// rate line on the nominal codes asked for at export time, its receipts and
// refunds, and a write-off journalled to the bad-debt nominal. The rows and
// the file are `sage.dart`'s.
import '../../../core/vat/place_of_supply.dart' show isEuCountry;
import 'billing_rules.dart';
import 'invoice.dart';
import 'invoice_line_cash.dart';
import 'sage.dart';
import 'vat_rate.dart';

/// Who each invoice's customer is in Sage.
class SageCustomers {
  const SageCustomers({
    required this.memberNumbers,
    required this.sellerCountry,
  });

  /// The member numbers held today, by member id: the fallback of a
  /// document that froze none.
  final Map<String, String> memberNumbers;

  /// The workspace's country: a customer in another EU member state is a
  /// cross-border supply.
  final String sellerCountry;

  /// The Account Reference of [invoice]'s customer: the member number the
  /// document froze, else the one held today; null when Sage cannot take
  /// it.
  String? accountOf(Invoice invoice) {
    final frozen = invoice.buyerParty?.memberNumber ?? '';
    return sageAccountReferenceRule.admit(
      frozen.isNotEmpty ? frozen : memberNumbers[invoice.memberId] ?? '',
    );
  }

  /// The customer's EU member state when it is not the seller's, else ''.
  String euCountryOf(Invoice invoice) {
    final buyer = (invoice.buyerParty?.country ?? '').toUpperCase();
    final seller = (invoice.sellerParty?.country ?? sellerCountry)
        .toUpperCase();
    return buyer.isNotEmpty && buyer != seller && isEuCountry(buyer)
        ? buyer
        : '';
  }
}

/// The audit trail of [invoices] and their [matches]. [groupOf] is the
/// rate group of a breakdown line; every amount must be in [baseCurrency].
SageAuditTrail sageRowsOfInvoices({
  required List<Invoice> invoices,
  required Map<String, InvoiceMatch> matches,
  required SageAccounts accounts,
  required SageCustomers customers,
  required String baseCurrency,
  required String Function(InvoiceVatTotal total) groupOf,
}) {
  final rows = <SageRow>[];
  final blockers = <SageBlocker>{};
  for (final invoice in invoices) {
    // A voided invoice was never booked; #831 a settlement regroups booked
    // revenue. Neither is a transaction.
    if (invoice.isVoided || invoice.kind == InvoiceKind.settlement) continue;
    final customer = customers.accountOf(invoice);
    if (customer == null) {
      blockers.add(SageBlocker(SageBlock.accountReference, invoice.memberName));
    } else if (invoice.currency.toUpperCase() != baseCurrency.toUpperCase()) {
      blockers.add(
        SageBlocker(
          SageBlock.currency,
          '${invoice.number} (${invoice.currency})',
        ),
      );
    } else {
      _Document(
        invoice,
        accounts,
        customer: customer,
        euCountry: customers.euCountryOf(invoice),
        currency: baseCurrency,
      ).write(rows, blockers, matches[invoice.id], groupOf);
    }
  }
  return sageAuditTrail(rows, blockers);
}

/// One invoice's rows.
class _Document {
  _Document(
    this.invoice,
    this.accounts, {
    required this.customer,
    required this.euCountry,
    required this.currency,
  });

  final Invoice invoice;
  final SageAccounts accounts;
  final String customer;
  final String euCountry;
  final String currency;

  SageRow _row(
    String type,
    String nominal,
    String details,
    int net, {
    DateTime? on,
    ({String code, int tax})? taxed,
  }) => SageRow(
    type: type,
    account: customer,
    nominal: nominal,
    date: on ?? invoice.issuedAt,
    reference: invoice.number,
    details: details,
    netMinor: net,
    taxCode: taxed?.code ?? accounts.noTax,
    taxMinor: taxed?.tax ?? 0,
    currency: currency,
    countryOfVat: taxed != null && sageCrossBorder(taxed.code) ? euCountry : '',
  );

  /// A journal row: no customer, no tax.
  SageRow _journal(String type, String nominal, DateTime on, int net) =>
      SageRow(
        type: type,
        nominal: nominal,
        date: on,
        reference: invoice.number,
        details: 'Write-off ${invoice.number}',
        netMinor: net,
        taxCode: accounts.noTax,
        currency: currency,
      );

  void write(
    List<SageRow> rows,
    Set<SageBlocker> blockers,
    InvoiceMatch? match,
    String Function(InvoiceVatTotal) groupOf,
  ) {
    _sales(rows, blockers, groupOf);
    // #2365 — the payments an invoice itself netted were money in on its
    // date. A receipt carries no tax (T9): the tax was the invoice's.
    if (!invoice.isCreditNote) {
      for (final line in invoice.lines.where((l) => l.isMoneyIn)) {
        rows.add(
          _row('SR', accounts.bank, 'Payment ${invoice.number}', -line.amountCents),
        );
      }
    }
    // A PENDING match is a settlement still awaiting validation (0067):
    // money the workspace has not agreed it received.
    if (match == null || match.pending) return;
    // #2365 — a refunded credit note is money OUT: SP, never a receipt.
    final refund = refundedCents(invoice, match) > 0;
    rows.add(
      _row(
        refund ? 'SP' : 'SR',
        accounts.bank,
        '${refund ? 'Refund' : 'Payment'} ${invoice.number}',
        match.paidCents,
        on: match.matchedAt,
      ),
    );
    // The rest the owner gave up, journalled from the debtors control to
    // the bad-debt nominal on the write-off day. The VAT bad debt relief
    // is the accountant's.
    final owed = invoice.totalCents - match.paidCents;
    if (match.writeoffAt case final day? when owed > 0) {
      rows
        ..add(_journal('JD', accounts.writeOff, day, owed))
        ..add(_journal('JC', accounts.debtors, day, owed));
    }
  }

  /// #2359 — one SI per rate line, each with its own code; a credit note
  /// is an SC with POSITIVE amounts (a negative SI moves the debtor the
  /// wrong way). The split is the document's own frozen breakdown.
  void _sales(
    List<SageRow> rows,
    Set<SageBlocker> blockers,
    String Function(InvoiceVatTotal) groupOf,
  ) {
    int amount(int cents) => invoice.isCreditNote ? cents.abs() : cents;
    final parts = invoice.vatTotals.isEmpty
        ? [(net: invoice.netCents, tax: invoice.vatCents, group: '', category: 'O')]
        : [
            for (final t in invoice.vatTotals)
              (
                net: t.netCents,
                tax: t.vatCents,
                group: groupOf(t),
                category: t.category,
              ),
          ];
    for (final p in parts) {
      final code = accounts.codeOf(
        p.group,
        p.category,
        euCustomer: euCountry.isNotEmpty,
      );
      if (code == null) {
        final what = p.group.isEmpty ? p.category : p.group;
        blockers.add(
          SageBlocker(SageBlock.taxCode, '${invoice.number} ($what)'),
        );
        continue;
      }
      rows.add(
        _row(
          invoice.isCreditNote ? 'SC' : 'SI',
          accounts.sales,
          invoice.title,
          amount(p.net),
          taxed: (code: code, tax: amount(p.tax)),
        ),
      );
    }
  }
}
