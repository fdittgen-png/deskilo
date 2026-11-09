// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- how a seller's registration numbers print on an invoice,
// asked of the installed invoice mentions add-on of the seller's country (a
// Swiss UID, a Canadian business number and its Quebec number). A country with
// no add-on, or whose add-on does not know the number, prints it as written.
import '../../../core/jurisdiction/installed_invoice_mentions.dart';
import '../../../core/jurisdiction/jurisdiction_resolver.dart';

/// The seller's [vatId] and [legalId] as [country] prints them.
({String vatId, String legalId}) sellerIdentityOf(
  String country, {
  required String vatId,
  required String legalId,
}) {
  final resolution = resolveInvoiceMentions(
    LegalContext(countryCode: country),
    installedInvoiceMentions,
  );
  return switch (resolution) {
    ResolvedMentions(:final contribution) => (
      vatId: contribution.formatSellerVatId(vatId),
      legalId: contribution.formatSellerLegalId(legalId),
    ),
    NoMentions() => (vatId: vatId, legalId: legalId),
    RefusedMentions(:final kind) => throw StateError(
      'invoice mentions of $country: ${kind.name}',
    ),
  };
}
