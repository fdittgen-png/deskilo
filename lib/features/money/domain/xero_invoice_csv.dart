// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2372 — Xero's sales-invoice import template, written from the documents:
// the template's own header in its own order, one row per VAT rate of an
// invoice under its one legal number, the rate's net and the VAT the
// invoice recorded for it (TaxAmount), at most 500
// rows per file, dates in the organisation's order. Xero imports the file
// as draft invoices, which the export says. Credit notes have a template
// of their own in Xero and are not written here; the export names them.
import 'package:meta/meta.dart';

import '../../../core/money/money_text.dart';
import '../../../core/text/csv.dart';
import '../../../core/text/number_text.dart';
import '../../../core/time/date_text.dart';
import 'billing_rules.dart';
import 'invoice.dart';
import 'vat_rate.dart';

/// The columns of Xero's sales-invoice import template as Xero documents
/// them, in their order (Import customer invoices). Xero asks that the
/// columns are not changed, and maps on these names (the leading `*` marks
/// a required column), so they are not free-form.
@visibleForTesting
const List<String> xeroInvoiceColumns = [
  '*ContactName',
  'EmailAddress',
  'POAddressLine1',
  'POAddressLine2',
  'POAddressLine3',
  'POAddressLine4',
  'POCity',
  'PORegion',
  'POPostalCode',
  'POCountry',
  '*InvoiceNumber',
  'Reference',
  '*InvoiceDate',
  '*DueDate',
  'Total',
  'InventoryItemCode',
  '*Description',
  '*Quantity',
  '*UnitAmount',
  'Discount',
  '*AccountCode',
  '*TaxType',
  'TaxAmount',
  'TrackingName1',
  'TrackingOption1',
  'TrackingName2',
  'TrackingOption2',
  'Currency',
  'BrandingTheme',
];

/// Xero's import takes at most this many rows in one file.
@visibleForTesting
const int xeroInvoiceRowsPerFile = 500;

/// The order an organisation writes its dates in (a Xero organisation
/// setting: day first outside the United States).
enum XeroDateOrder { dayFirst, monthFirst }

/// The rate as the person reads it: its percent and category.
String xeroRateLabel(InvoiceVatTotal t) => '${percentText(t.percent)} % ${t.category}';

/// The key of one VAT rate of the documents: its percent and category.
String xeroRateKey(InvoiceVatTotal total) => '${total.percent}|${total.category}';

/// What the person confirms before the file is written: the organisation's
/// sales account and the name of each tax rate as the organisation holds
/// it. Nothing is proposed — every organisation names its own.
class XeroInvoiceSettings {
  const XeroInvoiceSettings({
    required this.accountCode,
    required this.taxTypes,
    this.dateOrder = XeroDateOrder.dayFirst,
  });

  final String accountCode;

  /// The organisation's tax rate for each [xeroRateKey].
  final Map<String, String> taxTypes;

  final XeroDateOrder dateOrder;
}

/// Why the file cannot be written.
enum XeroInvoiceBlock { accountCode, taxType }

class XeroInvoiceBlocker {
  const XeroInvoiceBlocker(this.block, this.subject);

  final XeroInvoiceBlock block;

  /// The rate (percent and category) a tax rate is missing for; '' for the
  /// account code.
  final String subject;

  @override
  bool operator ==(Object other) =>
      other is XeroInvoiceBlocker && other.block == block && other.subject == subject;

  @override
  int get hashCode => Object.hash(block, subject);
}

/// The export: its files (each with the header), or why there is none.
class XeroInvoiceExport {
  const XeroInvoiceExport({required this.files, required this.blockers, required this.creditNotes});

  final List<String> files;
  final Set<XeroInvoiceBlocker> blockers;

  /// The numbers of the credit notes left out of the file.
  final List<String> creditNotes;
}

/// The sales the template takes: a voided invoice was never a sale, a
/// settlement regroups sales already exported (#831), and a credit note
/// is not an invoice in Xero.
bool _isSale(Invoice i) => !i.isVoided && i.kind != InvoiceKind.settlement && !i.isCreditNote;

/// The VAT rates [invoices] carry, once each, in the order first met: the
/// rows the person names a tax rate for.
List<InvoiceVatTotal> xeroRatesOf(List<Invoice> invoices, {required String zeroCategory}) {
  final seen = <String, InvoiceVatTotal>{};
  for (final invoice in invoices.where(_isSale)) {
    for (final t in invoice.vatBreakdown(zeroCategory: zeroCategory)) {
      seen.putIfAbsent(xeroRateKey(t), () => t);
    }
  }
  return seen.values.toList();
}

/// The template rows of [invoices], split into files of
/// [xeroInvoiceRowsPerFile] rows; an invoice never spans two files.
XeroInvoiceExport xeroInvoiceExport({
  required List<Invoice> invoices,
  required XeroInvoiceSettings settings,
  required String zeroCategory,
}) {
  final blockers = <XeroInvoiceBlocker>{
    if (settings.accountCode.trim().isEmpty) const XeroInvoiceBlocker(XeroInvoiceBlock.accountCode, ''),
  };
  final perInvoice = <List<String>>[];
  for (final invoice in invoices.where(_isSale)) {
    final rows = <String>[];
    for (final t in invoice.vatBreakdown(zeroCategory: zeroCategory)) {
      final taxType = settings.taxTypes[xeroRateKey(t)]?.trim() ?? '';
      if (taxType.isEmpty) {
        blockers.add(XeroInvoiceBlocker(XeroInvoiceBlock.taxType, xeroRateLabel(t)));
        continue;
      }
      rows.add(_row(invoice, t, settings, taxType));
    }
    perInvoice.add(rows);
  }
  final creditNotes = [
    for (final i in invoices)
      if (!i.isVoided && i.isCreditNote) i.number,
  ];
  if (blockers.isNotEmpty) return XeroInvoiceExport(files: const [], blockers: blockers, creditNotes: creditNotes);
  final files = <String>[];
  var current = <String>[];
  for (final rows in perInvoice) {
    if (current.isNotEmpty && current.length + rows.length > xeroInvoiceRowsPerFile) {
      files.add(_file(current));
      current = [];
    }
    current.addAll(rows);
  }
  if (current.isNotEmpty) files.add(_file(current));
  return XeroInvoiceExport(files: files, blockers: const {}, creditNotes: creditNotes);
}

String _file(List<String> rows) => '${[xeroInvoiceColumns.join(','), ...rows].join('\r\n')}\r\n';

String _cell(String text) => csvCell(text);

String _date(DateTime d, XeroDateOrder order) => switch (order) {
      XeroDateOrder.dayFirst => dmy(d),
      XeroDateOrder.monthFirst => '${twoDigits(d.month)}/${twoDigits(d.day)}/${d.year}',
    };

String _row(Invoice invoice, InvoiceVatTotal total, XeroInvoiceSettings settings, String taxType) {
  final buyer = invoice.buyerParty;
  final name = (buyer?.name ?? '').isNotEmpty ? buyer!.name : invoice.memberName;
  return [
    _cell(name),
    '',
    _cell(buyer?.street ?? ''),
    '',
    '',
    '',
    _cell(buyer?.city ?? ''),
    '',
    _cell(buyer?.postalCode ?? ''),
    _cell(buyer?.country ?? ''),
    _cell(invoice.number),
    _cell(invoice.period ?? ''),
    _date(invoice.issuedAt, settings.dateOrder),
    // No due date recorded: left blank, Xero applies the contact's terms.
    if (invoice.dueOn case final due?) _date(due, settings.dateOrder) else '',
    // Total: Xero computes it from the lines.
    '',
    '',
    _cell('${invoice.title} (${percentText(total.percent)} %)'),
    '1',
    // The rate's net: the file is tax-exclusive (chosen at Xero's import).
    minorToText(total.netCents, invoice.currency),
    '',
    _cell(settings.accountCode.trim()),
    _cell(taxType),
    // The VAT the invoice recorded for the rate, so Xero does not round it
    // again from the aggregated net.
    minorToText(total.vatCents, invoice.currency),
    '',
    '',
    '',
    '',
    invoice.currency.toUpperCase(),
    '',
  ].join(',');
}
