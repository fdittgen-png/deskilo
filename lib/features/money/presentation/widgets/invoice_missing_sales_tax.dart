// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2362 -- the words for what a seller in the United States is missing before
// an invoice can be issued (stable server keys, 0434). Every other key is its
// own text: `invoiceMissingLabel` falls through to this and then to the key.
import '../../../../l10n/app_localizations.dart';

String salesTaxMissingLabel(AppLocalizations l10n, String key) => switch (key) {
  'sales_tax_rate_unset' => l10n.invoiceMissingSalesTaxRate,
  'sales_tax_taxability_unset' => l10n.invoiceMissingSalesTaxTaxability,
  _ => key,
};
