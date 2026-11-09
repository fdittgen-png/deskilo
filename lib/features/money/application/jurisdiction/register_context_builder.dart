// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- what a registers add-on is given: the issued documents
// as neutral data, who keeps the register, the period, the EU member states of
// the workspace's tax reference and, for a kind that draws a line, that
// `threshold` row of the reference. The host reads the reference; the add-on
// holds no figure.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';
import 'package:meta/meta.dart';

import '../../domain/vat_filing_files.dart' show VatFilingParty;

/// The register's view of [invoice].
@visibleForTesting
RegisterDocument registerDocumentOf(Invoice invoice) {
  final buyer = invoice.buyerParty;
  return RegisterDocument(
    number: invoice.number,
    issuedAt: invoice.issuedAt,
    currency: invoice.currency,
    totalCents: invoice.totalCents,
    title: invoice.title,
    memberName: invoice.memberName,
    replacesNumber: invoice.replacesNumber,
    correctionReason: invoice.correctionReason,
    voided: invoice.isVoided,
    vatTotals: [
      for (final t in invoice.vatTotals)
        RegisterVatLine(
          percent: t.percent,
          category: t.category,
          grossCents: t.grossCents,
          netCents: t.netCents,
          vatCents: t.vatCents,
        ),
    ],
    buyerParty: buyer == null
        ? null
        : RegisterParty(
            name: buyer.name,
            company: buyer.company,
            country: buyer.country,
            vatId: buyer.vatId,
            legalId: buyer.legalId,
            postalCode: buyer.postalCode,
          ),
  );
}

/// The context of a register of the space [party] keeps, for `[from, to)`.
/// [thresholdKey] names the `threshold` row of the party's country to read,
/// in force on the last day of the period; null for a kind with no line.
RegisterContext registerContextOf(
  Iterable<Invoice> invoices, {
  required TaxReferenceSet reference,
  required VatFilingParty party,
  required DateTime from,
  required DateTime to,
  String? thresholdKey,
  String activity = '',
  bool monthly = false,
  bool immediateSupply = false,
}) {
  RegisterThreshold? threshold;
  if (thresholdKey != null) {
    final last = DateTime(to.year, to.month, to.day - 1);
    final value = reference
        .resolved(isoDay(last))
        .lookup(TaxDomain.threshold, party.countryCode, thresholdKey)
        ?.value;
    if (value is ThresholdValue) {
      threshold = RegisterThreshold(
        cents: value.cents,
        currency: value.currency,
      );
    }
  }
  return RegisterContext(
    documents: [for (final i in invoices) registerDocumentOf(i)],
    from: from,
    to: to,
    sellerVatId: party.vatId,
    sellerName: party.name,
    activity: activity,
    monthly: monthly,
    immediateSupply: immediateSupply,
    threshold: threshold,
    euMemberStates: reference.euMembers(),
    euCodeAliases: reference.euAliases(),
  );
}
