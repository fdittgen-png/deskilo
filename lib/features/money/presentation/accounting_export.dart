// SPDX-License-Identifier: 0BSD
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/files/file_names.dart';
import '../../../core/time/clock.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_snack.dart';
import '../../../l10n/app_localizations.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/accountant_csv.dart';
import '../domain/accounting_format.dart';
import '../domain/accounting_view.dart';
import '../domain/audit_trail.dart';
import '../domain/datev.dart';
import '../domain/fec.dart';
import '../domain/invoice.dart';
import '../domain/saf_t.dart';
import '../domain/sage.dart';
import '../providers/money_providers.dart';
import 'e_invoice_identity.dart';
import 'invoice_actions.dart';
import 'invoice_line_text.dart';
import 'widgets/accounting_export_sheet.dart';
import 'widgets/export_accounts_dialogs.dart';

/// THE ACCOUNTING EXPORT (0074, extended by #669).
///
/// Its own file because it is its own concern — and because
/// invoice_actions.dart was at its length budget to the line, which is
/// the gate doing its job rather than an obstacle to route around.
///
/// Everything here is driven by the registry in
/// `domain/accounting_format.dart`, and that indirection earns its keep:
/// the registry is the single place that says what each file CLAIMS
/// about itself, so a new format cannot be added without someone
/// deciding whether it is a regulatory filing, an accountant exchange or
/// a declared subset. Wiring formats up ad hoc is how one eventually
/// ships claiming more than it can support.
///
/// The files go to Downloads: they are destined for someone else's
/// software.
Future<void> exportAccountingFile(
  BuildContext context,
  WidgetRef ref,
  List<Invoice> invoices, {
  required String label,
}) async {
  final l10n = AppLocalizations.of(context);
  final workspace = ref.read(currentWorkspaceProvider).value;
  if (workspace == null) return;
  if (invoices.isEmpty) {
    AppSnack.info(
      context,
      l10n?.invoiceAccountingExportEmpty ??
          'Nothing to export for this period.',
    );
    return;
  }
  // #831 — the accountant's view: settlements are transparent, their
  // payment allocated to the invoices they regroup.
  final view = accountingView(
      invoices, ref.read(invoiceMatchesProvider).value ?? const {});
  final exported = view.invoices;
  final matches = view.matches;
  final company = sellerOf(invoices.last, workspace);
  final country = workspace.countryCode.toUpperCase();

  final format = await showAccountingExportSheet(
    context,
    formats: formatsFor(country),
  );
  if (format == null || !context.mounted) return;

  // Refused BEFORE anything is built. A file the authority rejects on
  // its name alone wastes the owner's time in the worst possible place:
  // after they have sent it.
  if (format.needsLegalId &&
      company.legalId.replaceAll(RegExp('[^0-9]'), '').isEmpty) {
    AppSnack.error(
      context,
      l10n?.fecMissingSiren ??
          'This export is named after your registration number — fill it '
              'in under Legal identity first.',
    );
    return;
  }

  final now = ref.read(clockProvider).now();
  // The fiscal year closes on 31 December of the latest invoiced year —
  // the only close date the app can know.
  final year = invoices
      .map((invoice) => invoice.issuedAt.year)
      .reduce((a, b) => a > b ? a : b);

  Future<void> save(String content, String fileName) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    if (!context.mounted) return;
    await savePdfToDownloads(context, ref, bytes: bytes, fileName: fileName);
  }

  String named(String stem) =>
      '${safeFileSlug('$stem ${workspace.name} $label')}.${format.extension}';

  switch (format.id) {
    case 'fec':
      // The owner's own VAT account (0072) if they set one — the dialog
      // is where it can still be corrected.
      final accounts = await showFecAccountsDialog(
        context,
        initial: workspace.vatAccount.isEmpty
            ? const FecAccounts()
            : FecAccounts(vat: workspace.vatAccount),
      );
      if (accounts == null || !context.mounted) return;
      await runGuarded(
        context,
        domain: 'money',
        message: 'FEC export failed',
        errorText: l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
        action: () => save(
          buildFecFile(
            invoices: exported,
            matches: matches,
            company: company,
            accounts: accounts,
            lineText: (line) => invoiceLineText(l10n, line),
            customersLabel: l10n?.fecAccountCustomers ?? 'Clients',
            revenueLabel: l10n?.fecAccountRevenue ?? 'Ventes',
            bankLabel: l10n?.fecAccountBank ?? 'Banque',
            vatLabel: l10n?.fecAccountVat ?? 'TVA collectée',
          ),
          fecFileName(company.legalId, DateTime(year, 12, 31)),
        ),
      );

    case 'datev':
      // Beraternummer and Mandantennummer come from the accountant.
      // DATEV refuses an import whose numbers do not match the target
      // client, and that is a GOOD refusal: it stops a file landing in
      // the wrong company's books.
      final datev = await showDatevAccountsDialog(context);
      if (datev == null || !context.mounted) return;
      await runGuarded(
        context,
        domain: 'money',
        message: 'DATEV export failed',
        errorText: l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
        action: () => save(
          buildDatevFile(
            invoices: exported,
            matches: matches,
            accounts: datev.accounts,
            from: DateTime(year, 1, 1),
            to: DateTime(year, 12, 31),
            generatedAt: now,
            consultantNumber: datev.consultantNumber,
            clientNumber: datev.clientNumber,
            currency: workspace.currencyCode,
            batchName: workspace.name,
          ),
          datevFileName(year, invoices.last.issuedAt.month),
        ),
      );

    case 'sage50':
      final sage = await showSageAccountsDialog(context);
      if (sage == null || !context.mounted) return;
      await runGuarded(
        context,
        domain: 'money',
        message: 'Sage export failed',
        errorText: l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
        action: () => save(
          buildSageFile(
            invoices: exported,
            matches: matches,
            accounts: sage,
            // Sage keys a transaction to a customer by its Account
            // Reference, and the member id is the only stable one the
            // app owns. An accountant re-maps these once; a NAME would
            // silently split one customer into two the day they marry.
            customerRef: (invoice) => invoice.memberId,
          ),
          sageFileName(year, invoices.last.issuedAt.month),
        ),
      );

    case 'saft_pt':
    case 'saft':
      final portugal = format.id == 'saft_pt';
      // #669 — the generic file can carry derived postings, which is
      // what makes it importable rather than merely readable. Offered,
      // never assumed: it needs an account mapping, and inventing one
      // is the thing this whole feature refuses to do.
      //
      // NOT offered for Portugal. Under TaxAccountingBasis 'F' the
      // ledger sections are not part of the declaration at all, so
      // adding them would break the very thing that makes that file
      // valid.
      SafTLedgerAccounts? ledger;
      if (!portugal) {
        final accounts = await showSafTLedgerDialog(
          context,
          initial: workspace.vatAccount.isEmpty
              ? const FecAccounts()
              : FecAccounts(vat: workspace.vatAccount),
        );
        if (!context.mounted) return;
        // The dialog distinguishes "no postings" from "cancelled": a
        // dismissed dialog aborts, choosing documents-only proceeds.
        if (accounts case final chosen?) {
          ledger = chosen.withPostings
              ? SafTLedgerAccounts(
                  customers: chosen.accounts.customers,
                  revenue: chosen.accounts.revenue,
                  bank: chosen.accounts.bank,
                  vat: chosen.accounts.vat,
                )
              : null;
        } else {
          return;
        }
      }
      await runGuarded(
        context,
        domain: 'money',
        message: 'accounting export failed',
        errorText: l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
        action: () => save(
          buildSafTFile(
            invoices: exported,
            matches: matches,
            company: company,
            currency: workspace.currencyCode,
            softwareVersion: safTSoftwareVersion,
            createdAt: now,
            lineText: (line) => invoiceLineText(l10n, line),
            fallbackDescription: l10n?.invoicesTitle ?? 'Invoice',
            profile:
                portugal ? SafTProfile.portugal : SafTProfile.generic,
            ledgerAccounts: ledger,
          ),
          named(portugal ? 'saft pt' : 'saf-t'),
        ),
      );

    case 'accountant_csv':
      await runGuarded(
        context,
        domain: 'money',
        message: 'accountant CSV export failed',
        errorText: l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
        action: () => save(
          buildAccountantCsv(
            invoices: exported,
            matches: matches,
            generatedAt: now,
            workspaceName: workspace.name,
            currencyFallback: workspace.currencyCode,
          ),
          named('accounting'),
        ),
      );

    case 'audit_trail':
      await runGuarded(
        context,
        domain: 'money',
        message: 'audit trail export failed',
        errorText: l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
        action: () async {
          // The ledger is fetched HERE rather than read from a cached
          // provider: a trail assembled from a stale cache would be
          // missing exactly the recent movements someone is asking
          // about.
          final ledger = await ref
              .read(moneyRepositoryProvider)
              .fetchWorkspaceLedger(workspace.id);
          await save(
            buildAuditTrailCsv(
              events: buildAuditEvents(
                invoices: exported,
                matches: matches,
                ledger: ledger,
              ),
              generatedAt: now,
              workspaceName: workspace.name,
            ),
            named('audit trail'),
          );
        },
      );
  }
}
