// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2477 -- how the tax reference screen names a value and a domain.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/text/number_text.dart';
import '../../../../core/vat/tax_reference.dart';
import 'tax_reference_component_fields.dart';

/// A one-line reading of a value, for lists.
String taxValueSummary(TaxValue v) => switch (v) {
  RateValue() => '${v.label} (${percentText(v.percent)} %)',
  EuMemberValue() => v.aliasOf,
  ExemptionTextValue() => v.text,
  VatIdPatternValue() => v.pattern,
  CatalogueNoteValue() => v.text,
  GroupExampleValue() => '${v.group}: ${v.text}',
  ThresholdValue() => '${v.cents} ${v.currency} (${v.effect})',
  TaxPointValue() => v.standard,
  MandateValue() => '${v.duty}: ${v.from}',
  IssuingGateValue() => v.issues ? v.currency : '-',
  FormBoxValue() => v.label,
  AccountMapValue() =>
    '${v.role}: ${v.account.isNotEmpty ? v.account : v.taxCode}',
  SalesTaxValue() => '${v.state} ${percentText(v.percent)} %',
  TaxabilityValue() => v.status,
  RateComponentValue() => rateComponentsText(v).replaceAll('\n', ' + '),
};

String taxDomainLabel(BuildContext context, TaxDomain d) => switch (d) {
  TaxDomain.rate => context.l10n.taxRefDomainRate,
  TaxDomain.euMember => context.l10n.taxRefDomainEuMember,
  TaxDomain.mention => context.l10n.taxRefDomainExemptionText,
  TaxDomain.vatIdPattern => context.l10n.taxRefDomainVatIdPattern,
  TaxDomain.catalogueNote => context.l10n.taxRefDomainCatalogueNote,
  TaxDomain.groupExample => context.l10n.taxRefDomainGroupExample,
  TaxDomain.threshold => context.l10n.taxRefDomainThreshold,
  TaxDomain.taxPoint => context.l10n.taxRefDomainTaxPoint,
  TaxDomain.mandate => context.l10n.taxRefDomainMandate,
  TaxDomain.issuingGate => context.l10n.taxRefDomainIssuingGate,
  TaxDomain.formBox => context.l10n.taxRefDomainFormBox,
  TaxDomain.accountMap => context.l10n.taxRefDomainAccountMap,
  TaxDomain.salesTax => context.l10n.taxRefDomainSalesTax,
  TaxDomain.taxability => context.l10n.taxRefDomainTaxability,
  TaxDomain.rateComponent => context.l10n.taxRefDomainRateComponent,
};
