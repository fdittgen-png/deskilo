// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 -- the national invoice mentions of a seller, asked of the installed
// add-ons through the resolver, with the vocabulary the tests have always used
// (the function the invoice model held until the add-ons took the rules).
import 'package:deskilo/core/jurisdiction/installed_invoice_mentions.dart';
import 'package:deskilo/core/jurisdiction/jurisdiction_resolver.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';

List<String> nationalInvoiceMentions({
  required String sellerCountry,
  required VatRegime regime,
  required String currency,
  required int untaxedCents,
  required bool correction,
  String rectifies = '',
  String correctionReason = '',
  String sellerVatId = '',
  String sellerLegalId = '',
  bool qstCharged = false,
  required TaxReferenceSet reference,
}) {
  final resolution = resolveInvoiceMentions(
    LegalContext(
      countryCode: euCountryCode(sellerCountry, reference: reference),
    ),
    installedInvoiceMentions,
  );
  return switch (resolution) {
    ResolvedMentions(:final contribution) => contribution.mentions(
      InvoiceMentionContext(
        sellerVatRegistered: regime == VatRegime.vatRegistered,
        currency: currency,
        untaxedMinor: untaxedCents,
        correction: correction,
        rectifies: rectifies,
        correctionReason: correctionReason,
        sellerVatId: sellerVatId,
        sellerLegalId: sellerLegalId,
        qstCharged: qstCharged,
      ),
    ),
    NoMentions() => const [],
    RefusedMentions(:final kind) => throw StateError(kind.name),
  };
}
