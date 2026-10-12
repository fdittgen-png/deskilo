// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:meta/meta.dart';

/// #2358 — what a national e-invoicing mandate obliges a business to do.
enum MandateDuty {
  /// Every business must be able to RECEIVE structured e-invoices.
  receiveAll,

  /// Large and mid-sized businesses must ISSUE them (FR: GE/ETI; DE:
  /// turnover above EUR 800 000; PL: the large taxpayers).
  issueLarge,

  /// Every business must issue them.
  issueAll,

  /// Transactions outside the domestic B2B flow, and the payment data of
  /// services, must be reported (FR e-reporting).
  eReporting,

  /// Every invoice record must be hash-chained and reportable to the
  /// tax administration (ES Verifactu).
  invoiceRecords,
}

/// One dated obligation of one country.
class EInvoiceMandate {
  const EInvoiceMandate(this.country, this.duty, this.from);

  /// ISO 3166-1 alpha-2.
  final String country;
  final MandateDuty duty;

  /// The first day the duty applies.
  final DateTime from;

  bool inForceOn(DateTime day) => !day.isBefore(from);
}

/// The calendar, as the laws stand in October 2026: FR (loi de finances
/// 2024, art. 91), DE (Wachstumschancengesetz), BE (loi du 6 février
/// 2024), IT (2019), PL (KSeF, Ustawa of 5 August 2025), RO (OUG
/// 120/2021), ES (RD 1007/2023 as moved by RDL 15/2025). Dates slip —
/// DE moved twice, FR once, ES twice — so each entry names its law and a
/// change is a one-line edit with a test that says which dates are
/// pinned. e_invoice_routing.dart keeps the channels; this keeps the
/// dates, and only this.
final List<EInvoiceMandate> _eInvoiceMandates = [
  EInvoiceMandate('FR', MandateDuty.receiveAll, DateTime(2026, 9)),
  EInvoiceMandate('FR', MandateDuty.issueLarge, DateTime(2026, 9)),
  EInvoiceMandate('FR', MandateDuty.eReporting, DateTime(2026, 9)),
  EInvoiceMandate('FR', MandateDuty.issueAll, DateTime(2027, 9)),
  EInvoiceMandate('DE', MandateDuty.receiveAll, DateTime(2025)),
  EInvoiceMandate('DE', MandateDuty.issueLarge, DateTime(2027)),
  EInvoiceMandate('DE', MandateDuty.issueAll, DateTime(2028)),
  EInvoiceMandate('BE', MandateDuty.receiveAll, DateTime(2026)),
  EInvoiceMandate('BE', MandateDuty.issueAll, DateTime(2026)),
  EInvoiceMandate('IT', MandateDuty.issueAll, DateTime(2019)),
  EInvoiceMandate('PL', MandateDuty.issueLarge, DateTime(2026, 2)),
  EInvoiceMandate('PL', MandateDuty.issueAll, DateTime(2026, 4)),
  EInvoiceMandate('RO', MandateDuty.issueAll, DateTime(2024, 7)),
  EInvoiceMandate('ES', MandateDuty.invoiceRecords, DateTime(2027)),
];

/// [country]'s duties in date order — the ones in force on [today] and
/// the ones still ahead. Empty for a country with no mandate.
@visibleForTesting
List<EInvoiceMandate> mandatesFor(String country) {
  final code = country.trim().toUpperCase();
  return [
    for (final m in _eInvoiceMandates)
      if (m.country == code) m,
  ]..sort((a, b) => a.from.compareTo(b.from));
}

/// The countries whose sellers DesKilo lets issue (the legal clauses were
/// reviewed for them, #1917) and so warns, with dates, about what the
/// mandate asks next. Every other seller is refused at issue
/// (`seller_country_unsupported`) until its national channel exists:
/// IT (SdI), ES (Verifactu), PL (KSeF) and RO (e-Factura) among them.
@visibleForTesting
const mandateWarningCountries = {'FR', 'DE'};

/// The dated warning an FR or DE seller sees: every duty still ahead on
/// [today], and the ones that came into force in the last year (the
/// space may not be ready for them yet). Empty elsewhere.
List<EInvoiceMandate> mandateWarnings(String country, DateTime today) {
  if (!mandateWarningCountries.contains(country.trim().toUpperCase())) {
    return const [];
  }
  final lastYear = DateTime(today.year - 1, today.month, today.day);
  return [
    for (final m in mandatesFor(country))
      if (!m.from.isBefore(lastYear)) m,
  ];
}
