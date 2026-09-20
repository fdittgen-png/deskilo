// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1246 — the words a tax authority reads are pinned, per language.
//
// `l10n_completeness_test` proves the five key sets are identical: it
// would pass on "Facture" translated as "Bill", and on a credit note
// that says "Note de crédit" where French accounting law says **avoir**.
// These are not preferences. A word on an issued invoice is part of the
// document's legal form, and an invoice is immutable once issued
// (`invoices_no_mutation`), so a wrong word cannot be corrected in place
// — it has to be voided and re-issued.
//
// The terms come from the ADRs that decided them: 0015 (the VAT
// compliance review), 0016 (intra-EU B2B reverse charge) and 0017 (cash
// -basis exigibility). The pin is exact-match on purpose: a reword is
// meant to fail here and be argued for, not to slip through as a tidy-up.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// key → locale → the term that is correct in that jurisdiction.
const Map<String, Map<String, String>> _terms = {
  // The heading of the document itself.
  'invoicePdfTitle': {
    'en': 'Invoice',
    'fr': 'Facture',
    'de': 'Rechnung',
    'es': 'Factura',
    'it': 'Fattura',
  },
  // French law says *avoir*; "note de crédit" is Belgian usage and reads
  // as a translation rather than a document. German *Gutschrift* is the
  // term the Umsatzsteuergesetz uses.
  'invoicePdfCreditNote': {
    'en': 'Credit note',
    'fr': 'Avoir',
    'de': 'Gutschrift',
    'es': 'Nota de crédito',
    'it': 'Nota di credito',
  },
  'vatPdfVat': {
    'en': 'VAT',
    'fr': 'TVA',
    'de': 'MwSt.',
    'es': 'IVA',
    'it': 'IVA',
  },
  // ADR 0016. Each of these is the phrase the directive's national
  // transposition requires ON THE INVOICE when the customer owes the
  // tax; "reverse charge" translated literally is not it.
  'vatTreatmentReverseCharge': {
    'en': 'Reverse charge',
    'fr': 'Autoliquidation',
    'de': 'Steuerschuldnerschaft des Empfängers',
    'es': 'Inversión del sujeto pasivo',
    'it': 'Inversione contabile',
  },
  'legalIdentityVatId': {
    'en': 'VAT number',
    'fr': 'Numéro de TVA',
    'de': 'Umsatzsteuer-ID',
    'es': 'Número de IVA',
    'it': 'Partita IVA',
  },
};

void main() {
  final arb = {
    for (final locale in ['en', 'fr', 'de', 'es', 'it'])
      locale: jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>,
  };

  for (final entry in _terms.entries) {
    test('${entry.key} says the legally correct word in all five languages',
        () {
      for (final locale in entry.value.entries) {
        expect(
          arb[locale.key]![entry.key],
          locale.value,
          reason: 'lib/l10n/_fragments/*_${locale.key}.arb: '
              '"${entry.key}" must be "${locale.value}" in '
              '${locale.key}. This word appears on an ISSUED invoice, '
              'which is immutable — a wrong one is corrected by voiding '
              'the document and re-issuing it, not by editing it. See '
              'docs/decisions/0015, 0016 and 0017. If the term is '
              'genuinely wrong, change it HERE in the same commit and '
              'say which authority says so.',
        );
      }
    });
  }
}
