// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- the lines a seller's own law adds to an invoice, asked of
// the installed add-on of the seller's country through the resolver. A country
// with no add-on adds none; an ambiguous composition is a programming error.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart'
    show InvoiceMentionContext;
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';

import '../../../core/jurisdiction/installed_invoice_mentions.dart';
import '../../../core/jurisdiction/jurisdiction_resolver.dart';

/// The payment clauses of a document under its seller's country's rules.
export 'clause_rules.dart' show qualifyWithRules;

/// How a seller's registration numbers print, by the add-on of its country.
export 'seller_identity.dart' show sellerIdentityOf;

/// #3429 -- what the seller's own law adds, from the installed add-on of the seller's
/// country (none for a country with no add-on).
List<String> nationalMentionsOf(
  Invoice invoice,
  TaxReferenceSet reference, {
  String workspaceCountry = '',
  String workspaceVatRegime = 'not_subject',
  String workspaceVatId = '',
  String workspaceLegalId = '',
}) {
  final country = euCountryCode(
    invoice.sellerParty?.country ?? workspaceCountry,
    reference: reference,
  );
  final resolution = resolveInvoiceMentions(
    LegalContext(countryCode: country),
    installedInvoiceMentions,
  );
  return switch (resolution) {
    ResolvedMentions(:final contribution) => contribution.mentions(
      InvoiceMentionContext(
        sellerVatRegistered:
            vatRegimeFromWire(
              invoice.sellerParty?.vatRegime ?? workspaceVatRegime,
            ) ==
            VatRegime.vatRegistered,
        currency: invoice.currency,
        untaxedMinor: invoice.vatTotals
            .where((t) => t.vatCents == 0 && t.category != 'AE')
            .fold(0, (sum, t) => sum + t.grossCents),
        correction: invoice.isCreditNote || invoice.replacesNumber.isNotEmpty,
        rectifies: invoice.replacesNumber,
        correctionReason: invoice.correctionReason,
        sellerVatId: invoice.sellerParty?.vatId ?? workspaceVatId,
        sellerLegalId: invoice.sellerParty?.legalId ?? workspaceLegalId,
        qstCharged: invoice.vatTotals.any(
          (t) => t.components.any((c) => c.scheme == 'QST' && c.taxCents != 0),
        ),
      ),
    ),
    NoMentions() => const [],
    RefusedMentions(:final kind) => throw StateError(
      'invoice mentions of $country: ${kind.name}',
    ),
  };
}
