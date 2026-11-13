// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3850 -- the language and the number and date conventions an invoice is
// rendered in: the ones the server froze when it was issued (0753), never
// those of the person printing it. An invoice issued before 0753, or a draft,
// renders in the business's document language and its country's conventions.
// The ref-reading forms live beside the builder (`invoice_documents.dart`).
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';
import 'package:flutter/widgets.dart';

import '../../../core/i18n/app_format.dart';
import '../../../core/locale/report_language.dart';
import '../../../l10n/app_localizations.dart';
import 'report_strings_l10n.dart';

/// The language of a document and the `intl` locale its amounts and dates
/// are written with.
typedef DocumentLocale = ({String language, String formatLocale});

/// The business's document locale: its document language [locale] (else its
/// [country]'s first shipped one, by the workspace's own [reference]), in its
/// country's conventions.
DocumentLocale businessDocumentLocaleOf({
  required String country,
  String locale = '',
  TaxReferenceSet? reference,
}) {
  final language = businessDocumentLanguage(
    workspaceLocale: locale,
    countryLanguages:
        reference?.documentLanguagesOf(country)?.languages ?? const [],
  );
  return (
    language: language,
    formatLocale: defaultFormatLocale(language, country),
  );
}

/// The locale [invoice] renders in: frozen at issue, else the business's.
DocumentLocale invoiceDocumentLocaleOf(
  Invoice invoice, {
  required String country,
  String locale = '',
  TaxReferenceSet? reference,
}) {
  final language = invoice.documentLanguage;
  if (language == null || !documentLanguagesShipped.contains(language)) {
    return businessDocumentLocaleOf(
      country: country,
      locale: locale,
      reference: reference,
    );
  }
  final frozen = invoice.formatLocale ?? '';
  final region = frozen.length == 5 ? frozen.substring(3) : country;
  return (
    language: language,
    formatLocale: defaultFormatLocale(language, region),
  );
}

/// The words and formats a document in [locale] is built with: its own
/// language's bundle, its dates in that language and its amounts in its
/// conventions. Nothing of the person printing it.
ReportStrings documentStringsOf(DocumentLocale locale) => reportStringsOf(
  lookupAppLocalizations(Locale(locale.language)),
  dateLocale: locale.language,
  formatLocale: locale.formatLocale,
);
