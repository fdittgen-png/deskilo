// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:meta/meta.dart';

import '../../../core/vat/place_of_supply.dart';
import '../../../core/vat/tax_reference.dart';
import '../../../core/vat/tax_reference_active.dart';

/// #2358 — what a national e-invoicing mandate obliges a business to do.
enum MandateDuty {
  /// Every business must be able to RECEIVE structured e-invoices.
  receiveAll('receive_all'),

  /// Large and mid-sized businesses must ISSUE them (FR: GE/ETI; DE:
  /// turnover above EUR 800 000; PL: the large taxpayers).
  issueLarge('issue_large'),

  /// Every business must issue them.
  issueAll('issue_all'),

  /// Transactions outside the domestic B2B flow, and the payment data of
  /// services, must be reported (FR e-reporting).
  eReporting('e_reporting'),

  /// Every invoice record must be hash-chained and reportable to the
  /// tax administration (ES Verifactu).
  invoiceRecords('invoice_records');

  const MandateDuty(this.wire);

  /// The duty's name in a `mandate` row.
  final String wire;
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

/// The calendar: the `mandate` rows of the tax reference store, each naming
/// its law and a duty's first day (#2479). Dates slip -- DE moved twice, FR
/// once, ES twice -- so a change is a new version of a row, not a release.
/// e_invoice_routing.dart keeps the channels; this keeps the dates, and only
/// this.
///
/// [country]'s duties in date order -- the ones in force on [today] and
/// the ones still ahead. Empty for a country with no mandate.
@visibleForTesting
List<EInvoiceMandate> mandatesFor(
  String country, {
  String? asOf,
  TaxReferenceSet? reference,
}) =>
    [
      for (final row in (reference ?? ActiveTaxReference.current)
          .ownRows(TaxDomain.mandate, country, asOf: asOf))
        EInvoiceMandate(
          row.country,
          MandateDuty.values.firstWhere(
            (d) => d.wire == (row.value as MandateValue).duty,
          ),
          DateTime.parse((row.value as MandateValue).from),
        ),
    ]..sort((a, b) {
        final byDay = a.from.compareTo(b.from);
        return byDay != 0 ? byDay : a.duty.index.compareTo(b.duty.index);
      });

/// #2356 -- the member states whose law routes every invoice through a
/// national channel DesKilo does not speak yet: their sellers stay refused
/// at issue (`seller_country_unsupported`, the `issuing_gate` rows the SQL
/// gate reads too) until it exists.
Set<String> get nationalChannelRequired =>
    ActiveTaxReference.current.nationalChannelCountries();

/// The countries whose sellers DesKilo lets issue — every member state of
/// the Union (#2356) but [nationalChannelRequired] — and so warns, with
/// dates, about what the mandate asks next.
@visibleForTesting
Set<String> get mandateWarningCountries => {
  for (final c in euMemberStates)
    if (!nationalChannelRequired.contains(c)) c,
};

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
