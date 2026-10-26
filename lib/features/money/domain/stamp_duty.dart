// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Italian stamp duty (imposta di bollo, DPR 642/1972, tariff art. 13): a
// document that charges no VAT because its operation is exempt or outside
// the scope of the tax owes it above a total; on an electronic invoice it is
// paid virtually (DM 17 June 2014) and the document says so. The total and
// the duty are the `threshold` row `stamp_duty` of the seller's country, read
// on the document's day; the FatturaPA (`DatiBollo`) and the PDF's statutory
// line read the same answer.
import 'package:meta/meta.dart';

import '../../../core/time/date_text.dart';
import '../../../core/vat/tax_reference.dart';
import '../../../core/vat/tax_reference_active.dart';
import 'invoice.dart';
import 'invoice_fatturapa.dart';
import 'vat_rate.dart';

/// The Natura codes stamp duty applies to: exempt or outside-scope
/// operations, not exports (N3.1), intra-EU supplies (N3.2) or a reverse
/// charge (N6.x, N2.1).
const _stampDutyNatures = {'N1', 'N2.2', 'N3.5', 'N4'};

/// What decides the duty of a document: the seller's country, its currency
/// and day, its VAT totals and their gross, the buyer's country.
typedef StampDutyDocument = ({
  String country,
  String currency,
  DateTime day,
  List<InvoiceVatTotal> totals,
  int grossCents,
  String buyerCountry,
});

/// The duty [doc] owes in its currency's minor units, or null: the seller's
/// country has a `stamp_duty` row in that currency on that day, the totals
/// charge no VAT, their gross passes the row's line (a credit note's
/// negative total never does) and one of them is of a Natura the duty
/// applies to.
int? stampDutyCents(StampDutyDocument doc, {TaxReferenceSet? reference}) {
  final row = (reference ?? ActiveTaxReference.current)
      .resolved(isoDay(doc.day))
      .lookup(TaxDomain.threshold, doc.country, 'stamp_duty');
  final line = row?.value;
  if (line is! ThresholdValue || line.currency != doc.currency) return null;
  if (doc.totals.any((t) => t.vatCents != 0) || doc.grossCents <= line.cents) {
    return null;
  }
  final owed = doc.totals.any(
    (t) => _stampDutyNatures.contains(
      fatturaPaNatura(t.category, buyerCountry: doc.buyerCountry),
    ),
  );
  return owed ? line.chargeCents : null;
}

/// [stampDutyCents] of an issued [invoice], from its frozen parties.
@visibleForTesting
int? stampDutyOf(Invoice invoice, {TaxReferenceSet? reference}) =>
    stampDutyCents((
      country: invoice.sellerParty?.country ?? '',
      currency: invoice.currency,
      day: invoice.issuedAt,
      totals: invoice.vatTotals,
      grossCents: invoice.vatTotals.fold(0, (sum, t) => sum + t.grossCents),
      buyerCountry: invoice.buyerParty?.country ?? '',
    ), reference: reference);

/// The statutory line of a document that owes the duty (the `exemption_text`
/// row `stamp_duty` of the seller's country), or null.
String? stampDutyMention(Invoice invoice, {TaxReferenceSet? reference}) {
  if (stampDutyOf(invoice, reference: reference) == null) return null;
  return (reference ?? ActiveTaxReference.current).mentionFor(
    'stamp_duty',
    invoice.sellerParty?.country ?? '',
    asOf: isoDay(invoice.issuedAt),
  );
}
