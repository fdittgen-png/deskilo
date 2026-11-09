// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- the payment-clause rules of a seller's country, asked of
// the installed invoice mentions add-on through the resolver: the family of the
// legal profile and the clauses its law makes automatic. A country with no
// add-on has none (the EU fallback applies); an ambiguous composition is a
// programming error.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

import '../../../core/jurisdiction/installed_invoice_mentions.dart';
import '../../../core/jurisdiction/jurisdiction_resolver.dart';

/// The rules of [sellerCountry], or null when its add-on declares no family.
ClauseRules? clauseRulesOf(String sellerCountry) {
  final resolution = resolveInvoiceMentions(
    LegalContext(countryCode: sellerCountry),
    installedInvoiceMentions,
  );
  return switch (resolution) {
    ResolvedMentions(:final contribution) when contribution.profileFamily.isNotEmpty =>
      ClauseRules(
        family: contribution.profileFamily,
        automaticClauses: contribution.automaticClauses,
      ),
    ResolvedMentions() || NoMentions() => null,
    RefusedMentions(:final kind) => throw StateError(
      'invoice mentions of $sellerCountry: ${kind.name}',
    ),
  };
}
