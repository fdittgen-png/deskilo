// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2372 — Xero's sales-invoice import file of one accounting export run:
// the year's invoices on the sales account and the tax rates the person
// names, one file per 500 rows. Xero imports them as drafts; credit notes
// have their own template and are named, not written.
import '../../../core/ui/app_snack.dart';
import '../domain/vat_regime.dart';
import '../domain/xero_invoice_csv.dart';
import 'accounting_export_run.dart';
import 'widgets/xero_invoice_dialog.dart';

extension XeroAccountingExports on AccountingExportRun {
  Future<void> xeroInvoiceFileExport() async {
    final zero = vatRegimeFromWire(workspace.vatRegime).taxCategoryCode;
    final reference = taxReference;
    final rates = xeroRatesOf(exported, zeroCategory: zero, reference: reference);
    final settings = await showXeroInvoiceDialog(context, rates: rates);
    if (settings == null || !context.mounted) return;
    final export = xeroInvoiceExport(
      invoices: exported,
      settings: settings,
      zeroCategory: zero,
      reference: reference,
    );
    if (export.blockers.isNotEmpty) {
      final first = export.blockers.first;
      AppSnack.error(
        context,
        first.block == XeroInvoiceBlock.accountCode
            ? l10n.xeroInvoiceRefusedAccount
            : l10n.xeroInvoiceRefusedTaxType(first.subject),
      );
      return;
    }
    for (final (i, content) in export.files.indexed) {
      final part = export.files.length > 1 ? ' ${i + 1}' : '';
      await save(content, named('xero invoices $year$part'));
      if (!context.mounted) return;
    }
    if (export.creditNotes.isNotEmpty) {
      AppSnack.info(context, l10n.xeroInvoiceCreditNotesLeftOut(export.creditNotes.length));
    }
  }
}
