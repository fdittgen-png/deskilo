// SPDX-License-Identifier: AGPL-3.0-or-later
//
// One accounting export, once its books are read: each format is a
// method here, so the screen's entry point only gathers and asks.
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
import '../../../l10n/app_localizations.dart';
import '../../reservations/providers/reservation_providers.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/accountant_csv.dart';
import '../domain/accountant_handoff.dart';
import '../domain/accounting_format.dart';
import '../domain/accounting_view.dart';
import '../domain/archive_bundle.dart';
import '../domain/audit_trail.dart';
import '../domain/book_profile.dart';
import '../domain/datev.dart';
import '../domain/expense_repartition.dart';
import '../domain/export_year.dart';
import '../domain/fec.dart';
import '../domain/fr_ereporting.dart';
import '../domain/invoice.dart';
import '../domain/invoice_line_text.dart';
import '../domain/invoice_queries.dart';
import '../domain/ledger_entry.dart';
import '../domain/money_repository.dart';
import '../domain/posting.dart';
import '../domain/report_strings.dart';
import '../domain/saf_t.dart';
import '../domain/sage.dart';
import '../domain/swiss_kmu.dart';
import '../domain/vat_tax_point.dart';
import '../providers/book_period_providers.dart';
import '../providers/book_profile_providers.dart';
import '../providers/money_providers.dart';
import 'accounting_export_journal.dart';
import 'datev_profile.dart';
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

/// THE ACCOUNTING EXPORT, one run: [start] gathers the books and asks
/// which format, then the format's own method writes the file.
class AccountingExportRun {
  AccountingExportRun(
    this.context,
    this.ref,
    this.invoices, {
    required this.label,
  }) : l10n = context.l10n,
       words = reportStringsOf(context.l10n),
       association = ref.read(sellerIsAssociationProvider);

  final BuildContext context;
  final WidgetRef ref;
  final List<Invoice> invoices;
  final String label;
  final AppLocalizations l10n;
  final ReportStrings words;
  final bool association;

  late final workspace = ref.read(currentWorkspaceProvider).value!;
  late final AccountingFormat format;
  late final int year;
  late final Map<String, InvoiceMatch> matches;
  late final InvoiceParty company;
  late final String country;
  late final DateTime now;
  late final bool development;
  late final ExportSourceBooks books;
  late final List<VatTaxPointAmount> taxPoints;
  late final Map<String, String> memberNames;

  List<Invoice> get exported => books.invoices;
  List<LedgerEntry> get ledger => books.ledger;
  List<ExpenseRepartition> get repartitions => books.repartitions;
  List<BookProfile> get bookProfiles => books.bookProfiles;
  InvoiceQueries get invoiceQueries => ref.read(invoiceQueriesProvider);
  MoneyRepository get repo => ref.read(moneyRepositoryProvider);

  /// Gathers the books, asks which format and for its details, and
  /// exports.
  Future<void> start() async {
  if (ref.read(currentWorkspaceProvider).value == null) return;
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
  year = invoices
      .map((invoice) => invoice.issuedAt.year)
      .reduce((a, b) => a > b ? a : b);
  matches = view.matches;
  company = sellerOf(invoices.last, workspace);
  country = workspace.countryCode.toUpperCase();

  final chosen = await showAccountingExportSheet(
    context,
    formats: formatsFor(country),
  );
  if (chosen == null || !context.mounted) return;
  format = chosen;

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

  now = ref.read(clockProvider).now();
  // The fiscal year closes on 31 December of the latest invoiced year —
  // the only close date the app can know.
  // #936 — the purchases side travels with the sales side, and a
  // development workspace's books are marked as such.
  development = workspace.environment != 'prod';
  // #2365 — the books of the export year only.
  final read = await exportYearBooksOrSay(
    context,
    ref.read(accountingSourceQueriesProvider),
    workspace.id,
    year,
    view.invoices,
    loaded: invoices,
  );
  if (read == null) return;
  books = read;
  // #2355 — when each invoice's VAT falls due, on the basis the
  // declaration uses: the FEC's collected VAT and DATEV's tax periods
  // then agree with the return and the VAT report.
  taxPoints = vatTaxPointLedger(
    exported,
    matches: matches,
    instalments: await invoiceQueries.fetchInvoiceInstalments(workspace.id),
    basis: workspaceTaxPointBasis(workspace.invoiceLegal, workspace.countryCode),
  );
  memberNames =
      ref.read(memberNamesProvider).value ?? const <String, String>{};
  if (!context.mounted) return;
  noteDevelopmentBooks(context, development: development);
  await _perform();
}

  Future<void> _perform() async {
    switch (format.id) {
      case 'fec':
        await _fec();
      case 'datev':
        await _datev();
      case 'sage50':
        await _sage();
      case 'ch_kmu':
        await _swissKmu();
      case 'saft_pt':
      case 'saft':
        await _safT();
      case 'accountant_csv':
        await _accountantCsv();
      case 'bundle':
        await _bundle();
      case 'fr_ereporting':
        await _frEReporting();
      case 'audit_trail':
        await _auditTrail();
      case 'generic_journal_csv':
        final books = ref.read(genericJournalExportProvider);
        await exportGenericJournal(context, () => books.of(workspace.id, bookProfiles, year),
            save: (content) => save(content, named('journal')));
    }
  }

  Future<void> save(String content, String fileName) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    if (!context.mounted) return;
    await savePdfToDownloads(context, ref, bytes: bytes, fileName: fileName);
    await ref.read(bookPeriodCommandProvider).logExport(workspace.id, formatId: format.id,
        year: year, content: content, documents: exported.length);
  }

  String named(String stem) => '${safeFileSlug('$stem ${workspace.name} $label')}.${format.extension}';

  Future<void> _fec() async {
    // #2365 — a local book's FEC is its postings, on its own chart.
    if (localBookOf(bookProfiles, year) != null) {
      final books = ref.read(genericJournalExportProvider);
      return exportGenericJournal(context, () => books.fecOf(workspace.id, bookProfiles, year), save: (content) =>
          save(content, fecFileName(company.legalId, DateTime(year, 12, 31), development: development)));
    }
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
  }

  Future<void> _datev() async {
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
      action: () async => save(
        buildDatevFile(
          invoices: exported,
          matches: matches,
          accounts: datevAccountsFor(bookProfiles, datev.accounts, year),
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
  }

  Future<void> _sage() async {
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
  }

  Future<void> _swissKmu() async {
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
  }

  Future<void> _safT() async {
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
    String file({SafTLedgerAccounts? accounts, List<Posting>? posted}) => buildSafTFile(
          invoices: exported, matches: matches, company: company, currency: workspace.currencyCode,
          softwareVersion: safTSoftwareVersion, createdAt: now,
          lineText: (line) => invoiceLineText(words, line, association: association),
          fallbackDescription: l10n.invoicesTitle,
          profile: portugal ? SafTProfile.portugal : SafTProfile.generic,
          ledgerAccounts: accounts, bookPostings: posted);
    // #2365 — a local book's ledger is its postings; no mapping is asked.
    if (!portugal && localBookOf(bookProfiles, year) != null) {
      final books = ref.read(genericJournalExportProvider);
      return exportGenericJournal(context,
          () => books.postedFile(workspace.id, bookProfiles, year, (p) => file(posted: p)),
          save: (content) => save(content, named('saf-t')));
    }
    SafTLedgerAccounts? postings;
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
        postings = chosen.withPostings
            ? SafTLedgerAccounts(
                customers: chosen.accounts.customers,
                revenue: chosen.accounts.revenue,
                bank: chosen.accounts.bank,
                vat: chosen.accounts.vat, writeOff: chosen.accounts.writeOff,
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
      action: () => save(file(accounts: postings), named(portugal ? 'saft pt' : 'saf-t')),
    );
  }

  Future<void> _accountantCsv() async {
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
            for (final i in await invoiceQueries.fetchInvoices(workspace.id))
              if (ids.contains(i.id)) i,
          ],
          await invoiceQueries.fetchInvoiceMatches(workspace.id),
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
  }

  Future<void> _bundle() async {
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
        final verdicts = await Future.wait<String>(
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
          bytes: zipBundle(withRetentionNotice(files, country, year)),
          fileName: archiveBundleFileName(company.legalId, year, development: development),
        );
      },
    );
  }

  Future<void> _frEReporting() async {
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
          instalments: await invoiceQueries.fetchInvoiceInstalments(workspace.id),
          onReceipts: workspaceTaxPointBasis(
            workspace.invoiceLegal,
            workspace.countryCode,
          ).onReceipts,
          currency: workspace.currencyCode,
        ).toXml(),
        named('e-reporting'),
      ),
    );
  }

  Future<void> _auditTrail() async {
    await runGuarded(
      context,
      domain: 'money',
      message: 'audit trail export failed',
      errorText: l10n.workspaceGenericError,
      action: () async {
        // The ledger is the export year's, read with the invoices in
        // the one source response above: never a cached provider.
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
