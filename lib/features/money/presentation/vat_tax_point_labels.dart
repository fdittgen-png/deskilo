// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2355 — the words for the tax-point engine's rules and options: the
// legal-identity choice, and the one sentence the declaration and the
// VAT report say before their figures, so a reader knows WHICH dates a
// period holds.
import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/vat_tax_point.dart';

/// [l10n], or English when there is no localization in scope.
AppLocalizations vatWords(AppLocalizations? l10n) =>
    l10n ?? lookupAppLocalizations(const Locale('en'));

/// The rule, as an owner reads it.
String vatTaxPointRuleLabel(AppLocalizations? l10n, VatTaxPointRule rule) {
  final words = vatWords(l10n);
  return switch (rule) {
    VatTaxPointRule.invoiceDate => words.vatExigibilityInvoice,
    VatTaxPointRule.receipt => words.vatExigibilityPayment,
    VatTaxPointRule.servicePeriod => words.vatTaxPointServicePeriod,
    VatTaxPointRule.earlierOf => words.vatTaxPointEarlierOf,
  };
}

/// One option of [policy], the legal default marked as such.
String vatTaxPointOptionLabel(
  AppLocalizations? l10n,
  VatTaxPointPolicy policy,
  VatTaxPointOption option,
) {
  final rule = vatTaxPointRuleLabel(l10n, policy.ruleOf(option));
  if (option != VatTaxPointOption.standard) return rule;
  return vatWords(l10n).vatTaxPointLegalDefault(rule);
}

/// The sentence naming the basis a period is declared on.
String vatTaxPointBasisNote(AppLocalizations? l10n, VatTaxPointBasis basis) {
  final words = vatWords(l10n);
  return switch (basis.rule) {
    VatTaxPointRule.receipt => words.vatDeclarationBasisPayment,
    VatTaxPointRule.invoiceDate => words.vatDeclarationBasisInvoice,
    VatTaxPointRule.servicePeriod => words.vatDeclarationBasisServicePeriod,
    VatTaxPointRule.earlierOf => words.vatDeclarationBasisEarlierOf,
  };
}
