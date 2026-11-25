// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4166 — what a quote's document prints: the customer in the address window,
// the quote's reference (never an invoice number: nothing was invoiced), its
// date and how long it is valid, its lines and what they come to as the issuer
// froze them when the revision was sent, the VAT per rate, the notes. Pure:
// the words and the formats come in; the amounts are the sent revision's own,
// never worked out again here.
library;

import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/money_format.dart';
import 'customer_quote.dart';
import 'customer_quote_lines.dart';
import 'previewed_document.dart';
import 'standalone_invoice.dart';

/// How the document writes an amount (minor units), a day, an exact decimal
/// (a quantity, a unit price) and the rate of a tax, in the reader's locale.
typedef QuoteFormats = ({
  String Function(int minor) money,
  String Function(DateTime day) date,
  String Function(String decimal) quantity,
  String Function(String decimal) price,
  String Function(double percent) percent,
});

/// The formats of a document written in [language] with the number
/// conventions of [formatLocale], amounts in [currency].
QuoteFormats quoteFormatsFor({
  required String language,
  required String formatLocale,
  required String currency,
}) {
  final money = moneyFormat(currency, locale: formatLocale);
  final day = DateFormat.yMMMd(language);
  // Exact decimals as entered on the quote: a quantity as it is, a price with
  // two places at least and six at most.
  final quantity = NumberFormat('#,##0.######', formatLocale);
  final price = NumberFormat('#,##0.00####', formatLocale);
  final rate = NumberFormat.percentPattern(formatLocale)
    ..minimumFractionDigits = 0
    ..maximumFractionDigits = 2;
  return (
    money: money.formatMinor,
    date: day.format,
    quantity: (text) => quantity.format(num.tryParse(text) ?? 0),
    price: (text) => price.format(num.tryParse(text) ?? 0),
    percent: (percent) => rate.format(percent / 100),
  );
}

/// The customer as the window and the address block print them.
typedef QuoteCustomer = ({String name, String address});

/// The data of [revision] of [quote] to its customer for the `quote` kind,
/// under [letterhead] (the space's name and address).
Map<String, Object?> quoteReportData(
  CustomerQuote quote,
  QuoteRevision revision, {
  required QuoteCustomer customer,
  required QuoteFormats format,
  required String issuedBy,
  Map<String, Object?> letterhead = const {},
}) {
  final lines = revision.lines;
  final amounts = revision.amounts;
  final rows = <Map<String, Object?>>[
    for (final (i, line) in lines.indexed)
      _row(line, i < amounts.length ? amounts[i] : null, format),
  ];
  final net = amounts.fold<int>(0, (sum, a) => sum + a.netCents);
  final tax = amounts.fold<int>(0, (sum, a) => sum + a.taxCents);
  final total = revision.totals?.totalCents ?? net + tax;
  return {
    ...letterhead,
    'number': quote.reference ?? '',
    'issued': format.date(revision.issuedOn),
    'valid_until': format.date(revision.validUntil),
    'issued_by': issuedBy,
    'client_name': customer.name,
    'client_address': customer.address,
    'purchase_order': revision.purchaseOrder,
    'buyer_reference': revision.buyerReference,
    'lines': rows,
    'net_total': format.money(net),
    'vat_total': format.money(tax),
    'has_vat': tax != 0,
    'vat': _vatRows(revision.frozen, format),
    'total': format.money(total),
    'note': revision.notes,
  };
}

Map<String, Object?> _row(
  StandaloneLine line,
  QuoteLineAmounts? amounts,
  QuoteFormats format,
) => {
  'label': line.description,
  'qty': [
    format.quantity(line.quantity),
    if (line.unitLabel.isNotEmpty) line.unitLabel,
  ].join(' '),
  'unit_price': format.price(line.unitPrice),
  'amount': amounts == null ? '' : format.money(amounts.netCents),
};

/// The sums per rate: what the lines freeze, grouped the way the invoice's
/// breakdown is (the highest rate first) -- the one function the conversion
/// preview uses too.
List<Map<String, Object?>> _vatRows(
  List<InvoiceLine> frozen,
  QuoteFormats format,
) => [
  for (final total in vatTotalsOfLines(frozen))
    {
      'rate': format.percent(total.percent),
      'net': format.money(total.netCents),
      'amount': format.money(total.vatCents),
    },
];
