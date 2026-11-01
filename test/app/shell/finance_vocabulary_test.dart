// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3071 — one name per finance thing, in the five languages: the member's
// own statement, the manager's invoice pipeline, the two drawer groups and
// the three kinds of documents. A label that drifts back to a second
// meaning fails here, with the sentence that says which.
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The agreed vocabulary, per language: member statement, invoice
/// pipeline, sales group, cash group, document library.
const _agreed = <String, ({
  String mine,
  String invoices,
  String sales,
  String cash,
  String library,
})>{
  'en': (
    mine: 'My finances',
    invoices: 'Invoices',
    sales: 'Sales & collections',
    cash: 'Cash & accounting',
    library: 'Document library',
  ),
  'fr': (
    mine: 'Mes finances',
    invoices: 'Factures',
    sales: 'Ventes et encaissements',
    cash: 'Trésorerie et comptabilité',
    library: 'Bibliothèque de documents',
  ),
  'de': (
    mine: 'Meine Finanzen',
    invoices: 'Rechnungen',
    sales: 'Verkauf & Zahlungseingang',
    cash: 'Geld & Buchhaltung',
    library: 'Dokumentbibliothek',
  ),
  'es': (
    mine: 'Mis finanzas',
    invoices: 'Facturas',
    sales: 'Ventas y cobros',
    cash: 'Tesorería y contabilidad',
    library: 'Biblioteca de documentos',
  ),
  'it': (
    mine: 'Le mie finanze',
    invoices: 'Fatture',
    sales: 'Vendite e incassi',
    cash: 'Cassa e contabilità',
    library: 'Biblioteca documenti',
  ),
};

void main() {
  for (final locale in _agreed.keys) {
    final want = _agreed[locale]!;
    test('finance vocabulary, $locale', () async {
      final l = await AppLocalizations.delegate.load(Locale(locale));

      // The member's statement has one name wherever it is named.
      expect(l.financesTitle, want.mine);
      expect(l.tabMoney, want.mine);
      expect(l.invoicingMyFinances, want.mine);

      // The manager's invoice pipeline: the drawer entry and the screen.
      expect(l.invoicesManage, want.invoices);
      expect(l.invoicingHubTitle, want.invoices);

      // The two finance groups of the drawer.
      expect(l.uxNavSales, want.sales);
      expect(l.uxNavFinance, want.cash);

      // Three kinds of documents, three names.
      expect(l.documentsTitle, want.library);

      // No two sidebar labels of the finance area are alike: groups,
      // entries and the sub-group together.
      final labels = <String, String>{
        'group sales': l.uxNavSales,
        'group cash': l.uxNavFinance,
        'sub-group accounting': l.hubAccountingTitle,
        'sales hub': l.hubSalesTitle,
        'purchases': l.hubPurchasesTitle,
        'cash': l.hubCashTitle,
        'invoices': l.invoicesManage,
        'pricing': l.billingTitle,
        'payment instructions': l.paymentInstructionsTitle,
        'online payments': l.payConfigTitle,
        'accounting export': l.invoiceAccountingExport,
        'vat': l.vatTitle,
        'vat declaration': l.vatDeclTitle,
        'legal identity': l.legalIdentityTitle,
        'financial reports': l.uxReportsFinance,
        'workspace documents': l.uxReportsWorkspace,
        'document library': l.documentsTitle,
        'my finances': l.financesTitle,
      };
      final seen = <String, String>{};
      for (final e in labels.entries) {
        final other = seen[e.value];
        expect(other, isNull,
            reason: '"${e.value}" names both $other and ${e.key} ($locale)');
        seen[e.value] = e.key;
      }
      // The documents inside My finances are not the library.
      expect(l.moneyFaceDocuments, isNot(l.documentsTitle));
      expect(l.moneyFaceDocuments, isNot(l.uxReportsWorkspace));
    });
  }
}
