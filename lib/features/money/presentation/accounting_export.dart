// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/files/file_names.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/time/clock.dart';
import '../../../core/time/workspace_time.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_snack.dart';
import '../../reservations/providers/reservation_providers.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/accountant_csv.dart';
import '../domain/accountant_handoff.dart';
import '../domain/accounting_format.dart';
import '../domain/accounting_view.dart';
import '../domain/archive_bundle.dart';
import '../domain/audit_trail.dart';
import '../domain/datev.dart';
import '../domain/fec.dart';
import '../domain/fr_ereporting.dart';
import '../domain/invoice.dart';
import '../domain/invoice_line_text.dart';
import '../domain/saf_t.dart';
import '../domain/sage.dart';
import '../domain/swiss_kmu.dart';
import '../domain/vat_tax_point.dart';
import '../providers/money_providers.dart';
import 'e_invoice_identity.dart';
import 'export_year_books.dart';
import 'invoice_actions.dart';
import 'invoice_documents.dart';
import 'report_strings_l10n.dart';
import 'vat_report_actions.dart';
import 'vat_tax_point_labels.dart';
import 'widgets/accountant_handoff_preflight.dart';
import 'widgets/accounting_export_sheet.dart';
import 'widgets/export_accounts_dialogs.dart';
import 'widgets/swiss_kmu_accounts_dialog.dart';

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
  final l10n = context.l10n;
  final words = reportStringsOf(l10n);
  final association = ref.read(sellerIsAssociationProvider);
  final workspace = ref.read(currentWorkspaceProvider).value;
  if (workspace == null) return;
  if (invoices.isEmpty) {
    AppSnack.info(
      context,
      l10n.invoiceAccountingExportEmpty,
    );
    return;
  }
  // #831 — the accountant's view: settlements are transparent, their
  // payment allocated to the invoices they regroup.
  final view = accountingView(
      invoices, ref.read(invoiceMatchesProvider).value ?? const {});
  final year = invoices
      .map((invoice) => invoice.issuedAt.year)
      .reduce((a, b) => a > b ? a : b);
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
      l10n.fecMissingSiren,
    );
    return;
  }

  final now = ref.read(clockProvider).now();
  // The fiscal year closes on 31 December of the latest invoiced year —
  // the only close date the app can know.
  // #936 — the purchases side travels with the sales side, and a
  // development workspace's books are marked as such.
  final development = workspace.environment != 'prod';
  final repo = ref.read(moneyRepositoryProvider);
  // #2365 — the books of the export year only.
  final (invoices: exported, :ledger, :repartitions) =
      await exportYearBooks(repo, workspace.id, year, view.invoices);
  // #2355 — when each invoice's VAT falls due, on the basis the
  // declaration uses: the FEC's collected VAT and DATEV's tax periods
  // then agree with the return and the VAT report.
  final taxPoints = vatTaxPointLedger(
    exported,
    matches: matches,
    instalments: await repo.fetchInvoiceInstalments(workspace.id),
    basis: workspaceTaxPointBasis(workspace.invoiceLegal, workspace.countryCode),
  );
  final memberNames =
      ref.read(memberNamesProvider).value ?? const <String, String>{};
  if (!context.mounted) return;
  if (development) {
    AppSnack.info(
      context,
      l10n.accountingExportDevelopment,
    );
  }

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
        errorText: l10n.workspaceGenericError,
        action: () => save(
          buildFecFile(
            invoices: exported,
            matches: matches,
            company: company,
            accounts: accounts,
            lineText: (line) => invoiceLineText(words, line,
                association: association),
            customersLabel: l10n.fecAccountCustomers,
            revenueLabel: l10n.fecAccountRevenue,
            bankLabel: l10n.fecAccountBank,
            vatLabel: l10n.fecAccountVat,
            ledger: ledger,
            memberNames: memberNames,
            repartitions: repartitions,
            expensesLabel: l10n.fecAccountExpenses,
            taxPoints: taxPoints,
            vatPendingLabel: vatWords(l10n).fecAccountVatPending,
          ),
          fecFileName(company.legalId, DateTime(year, 12, 31),
              development: development),
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
        errorText: l10n.workspaceGenericError,
        action: () => save(
          buildDatevFile(
            invoices: exported,
            matches: matches,
            accounts: datev.accounts,
            from: DateTime(year),
            to: DateTime(year, 12, 31),
            generatedAt: now,
            consultantNumber: datev.consultantNumber,
            clientNumber: datev.clientNumber,
            ledger: ledger,
            repartitions: repartitions,
            development: development,
            currency: workspace.currencyCode,
            batchName: workspace.name,
            taxPoints: taxPoints,
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
        errorText: l10n.workspaceGenericError,
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

    case 'ch_kmu':
      // #2360 — the Swiss journal: the KMU accounts are asked for.
      final kmu = await showSwissKmuAccountsDialog(context);
      if (kmu == null || !context.mounted) return;
      await runGuarded(
        context,
        domain: 'money',
        message: 'Swiss booking export failed',
        errorText: l10n.commonSaveFailed,
        action: () => save(
          buildSwissKmuFile(
            invoices: exported,
            matches: matches,
            accounts: kmu,
            customerRef: (invoice) => invoice.memberId,
          ),
          swissKmuFileName(year, invoices.last.issuedAt.month),
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
        errorText: l10n.workspaceGenericError,
        action: () => save(
          buildSafTFile(
            invoices: exported,
            matches: matches,
            company: company,
            currency: workspace.currencyCode,
            softwareVersion: safTSoftwareVersion,
            createdAt: now,
            lineText: (line) => invoiceLineText(words, line,
                association: association),
            fallbackDescription: l10n.invoicesTitle,
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
        errorText: l10n.workspaceGenericError,
        action: () async {
          // #1640 — the file and its report are built first, shown, and
          // saved only on an explicit Save with nothing blocking.
          final csv = buildAccountantCsv(
            invoices: exported,
            matches: matches,
            generatedAt: now,
            workspaceName: workspace.name,
            currencyFallback: workspace.currencyCode,
          );
          final report = buildAccountantHandoff(
            invoices: exported,
            matches: matches,
            csv: csv,
            generatedAt: now,
          );
          if (!await showAccountantHandoffPreflight(context, report)) return;
          // #1640 — a bounded recheck: the same documents read again from
          // the server must give the same fingerprint, in the same space,
          // or the reviewed file no longer describes the books.
          final ids = {for (final i in invoices) i.id};
          final fresh = accountingView(
            [
              for (final i in await repo.fetchInvoices(workspace.id))
                if (ids.contains(i.id)) i,
            ],
            await repo.fetchInvoiceMatches(workspace.id),
          );
          if (!context.mounted) return;
          if (ref.read(currentWorkspaceProvider).value?.id != workspace.id ||
              accountantSourceDigest(fresh.invoices, fresh.matches) !=
                  accountantSourceDigest(exported, matches)) {
            AppSnack.error(
              context,
              l10n.handoffChanged,
            );
            return;
          }
          // One archive: the CSV and the report that counts it travel
          // together, or not at all.
          final stem = safeFileSlug('accounting ${workspace.name} $label');
          final bytes = accountantHandoffArchive(
            csv: csv,
            csvName: '$stem.csv',
            report: report,
          );
          if (!context.mounted) return;
          await savePdfToDownloads(context, ref,
              bytes: bytes, fileName: '$stem.zip');
        },
      );

    case 'bundle':
      // #957 — the fiscal year in one download: every invoice as PDF/A-3
      // with its embedded e-invoice, the register with each document's
      // integrity word, the FEC on the default accounts, the audit trail.
      await runGuarded(
        context,
        domain: 'money',
        message: 'archive bundle failed',
        errorText: l10n.workspaceGenericError,
        action: () async {
          final yearInvoices = exported;
          // #1154 — the signature checks are independent server calls:
          // all of them in flight at once, not one round-trip per invoice.
          // The PDFs stay sequential: each needs the context and the
          // fonts, and a year of them is a memory question, not a
          // latency one.
          final verdicts = await Future.wait(
            yearInvoices.map((i) => repo.verifyInvoiceSignature(i.id)),
          );
          if (!context.mounted) return;
          final integrity = <String, String>{
            for (var i = 0; i < yearInvoices.length; i++)
              yearInvoices[i].id: verdicts[i],
          };
          final files = <String, List<int>>{};
          for (final invoice in yearInvoices) {
            final pdf = await buildFacturXFile(
              context,
              ref,
              invoice,
              seller: sellerOf(invoice, workspace),
              buyer: buyerOf(invoice, workspace),
              iban: workspaceIban(workspace),
            );
            // #1885 — a document that did not render ends the bundle: an
            // archive missing an invoice must never be saved as complete.
            if (pdf.bytes.isEmpty) return;
            files['invoices/${pdf.fileName}'] = pdf.bytes;
          }
          files['register.csv'] = textBytes(buildInvoiceRegisterCsv(yearInvoices, integrity: integrity));
          files['audit-trail.csv'] = textBytes(buildAuditTrailCsv(
            events: buildAuditEvents(invoices: yearInvoices, matches: matches, ledger: ledger),
            generatedAt: now,
            workspaceName: workspace.name,
          ));
          addArchiveFec(files, country, buildFecFile(
            invoices: yearInvoices,
            matches: matches,
            company: company,
            accounts: workspace.vatAccount.isEmpty
                ? const FecAccounts()
                : FecAccounts(vat: workspace.vatAccount),
            lineText: (line) => invoiceLineText(words, line, association: association),
            ledger: ledger,
            memberNames: memberNames,
            repartitions: repartitions,
            taxPoints: taxPoints,
          ));
          if (!context.mounted) return;
          await savePdfToDownloads(
            context,
            ref,
            bytes: zipBundle(files),
            fileName: archiveBundleFileName(company.legalId, year, development: development),
          );
        },
      );
    case 'fr_ereporting':
      // #2358 — the month of the latest invoice: transactions on the
      // invoice date, payments on receipts (the French default) unless
      // the workspace opted for the débits.
      final last = invoices.map((i) => i.issuedAt).reduce(
            (a, b) => a.isAfter(b) ? a : b,
          );
      final month = WorkspaceTime.dateOf(last);
      await runGuarded(
        context,
        domain: 'money',
        message: 'France e-reporting export failed',
        action: () async => save(
          frEReport(
            exported,
            start: DateTime(month.year, month.month),
            end: DateTime(month.year, month.month + 1, 0),
            matches: matches,
            instalments: await repo.fetchInvoiceInstalments(workspace.id),
            onReceipts: workspaceTaxPointBasis(
              workspace.invoiceLegal,
              workspace.countryCode,
            ).onReceipts,
            currency: workspace.currencyCode,
          ).toXml(),
          named('e-reporting'),
        ),
      );
    case 'audit_trail':
      await runGuarded(
        context,
        domain: 'money',
        message: 'audit trail export failed',
        errorText: l10n.workspaceGenericError,
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
