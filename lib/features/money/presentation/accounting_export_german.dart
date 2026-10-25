// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The German exports of one accounting export run: the DATEV package (a
// Buchungsstapel per month and journal, the Stammdaten, the vouchers the
// rows link) and the GoBD data handover with its Verfahrensdokumentation.
// Both read the run's one snapshot; nothing here reads the period again.
import '../../../core/backend/schema_version.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_snack.dart';
import '../../../core/vat/tax_reference.dart';
import '../domain/archive_bundle.dart';
import '../domain/audit_trail.dart';
import '../domain/book_period.dart';
import '../domain/datev.dart';
import '../domain/datev_fields.dart';
import '../domain/datev_package.dart';
import '../domain/gobd_package.dart';
import '../domain/invoice.dart';
import '../domain/number_sequence.dart';
import '../providers/book_period_providers.dart';
import 'accounting_export_run.dart';
import 'datev_profile.dart';
import 'e_invoice_identity.dart';
import 'gobd_procedure_document.dart';
import 'invoice_actions.dart';
import 'invoice_documents.dart';
import 'widgets/export_accounts_dialogs.dart';

/// #2375 — the DATEV and GoBD exports of [AccountingExportRun].
/// The number series members are numbered in.
const _memberJournal = 'member';

extension GermanAccountingExports on AccountingExportRun {
  Future<void> datevExport() async {
    // Beraternummer and Mandantennummer come from the accountant.
    // DATEV refuses an import whose numbers do not match the target
    // client, and that is a GOOD refusal: it stops a file landing in
    // the wrong company's books.
    final datev = await showDatevAccountsDialog(
      context,
      costCentre: workspace.name,
    );
    if (datev == null || !context.mounted) return;
    await runGuarded(
      context,
      domain: 'money',
      message: 'DATEV export failed',
      action: () async {
        // Unreadable periods count as open: a Stapel is never made final
        // by mistake.
        var periods = const BookPeriodsOverview();
        try {
          periods = await ref.read(bookPeriodsProvider(workspace.id).future);
        } on Exception catch (e, st) {
          TraceLogger.instance.warn(
            'money',
            'book periods unreadable for DATEV',
            error: e,
            stackTrace: st,
          );
        }
        final sequences = await repo.fetchNumberSequences(workspace.id);
        final numbers = await memberNumbers();
        final package = buildDatevPackage(
          DatevPackageRequest(
            request: DatevRequest(
              invoices: exported,
              matches: matches,
              accounts: datevAccountsFor(bookProfiles, datev.accounts, year),
              from: DateTime(year),
              to: DateTime(year, 12, 31),
              generatedAt: now,
              consultantNumber: datev.consultantNumber,
              clientNumber: datev.clientNumber,
              accountLength: datev.accountLength,
              detail: DatevDetail(
                defaultCostCentre: datev.costCentre,
                voucherLinks: datev.voucherLinks,
              ),
              ledger: ledger,
              repartitions: repartitions,
              development: development,
              currency: workspace.currencyCode,
              batchName: workspace.name,
              taxPoints: taxPoints,
            ),
            bookProfiles: bookProfiles,
            closed: (from, to) => periods.closedOn(from)?.contains(to) ?? false,
            memberSequence: sequences.firstWhere(
              (s) => s.journal == _memberJournal,
              orElse: () => NumberSequence.defaultsFor(_memberJournal),
            ),
            debtorBase: datev.debtorBase,
            memberNumbers: numbers,
            memberNames: memberNames,
          ),
        );
        if (!context.mounted) return;
        if (package.problems.isNotEmpty) {
          return AppSnack.error(
            context,
            l10n.datevBlocked(datevProblemsText(l10n, package.problems)),
          );
        }
        // The vouchers the rows link, named by their Beleglink id.
        final vouchers = await _vouchers(
          package.vouchers,
          (i) => 'belege/${i.id}.pdf',
        );
        if (vouchers == null || !context.mounted) return;
        await _saveZip({
          for (final MapEntry(:key, :value) in package.files.entries)
            key: textBytes(value),
          ...vouchers,
        }, rows: package.rows);
      },
    );
  }

  /// #2375 — the GoBD data handover of the year: the tables of the one
  /// snapshot, every invoice's e-invoice and PDF/A-3, the
  /// Verfahrensdokumentation with the server's schema version.
  Future<void> gobdExport() async {
    await runGuarded(
      context,
      domain: 'money',
      message: 'GoBD export failed',
      action: () async {
        // The rates and clocks of this workspace's own installation; an
        // export never states another's.
        final reference = workspaceTaxReference(ref);
        if (reference == null) throw StateError('workspace context not ready');
        final sequences = await repo.fetchNumberSequences(workspace.id);
        int? schema;
        try {
          schema = await ref.read(schemaVersionSourceProvider).read();
        } on SchemaVersionUnavailable catch (e, st) {
          TraceLogger.instance.warn(
            'money',
            'schema version unreadable for the GoBD package',
            error: e,
            stackTrace: st,
          );
        }
        if (!context.mounted) return;
        final pdfs = await _vouchers(exported, (i) => 'belege/${i.id}.pdf');
        if (pdfs == null || !context.mounted) return;
        final vouchers = <String, Map<String, List<int>>>{
          for (final i in exported)
            i.id: {
              'belege/${i.id}.xml': textBytes(
                facturXmlOf(
                  context,
                  ref,
                  i,
                  seller: sellerOf(i, workspace),
                  buyer: buyerOf(i, workspace),
                  iban: workspaceIban(workspace),
                ),
              ),
              'belege/${i.id}.pdf': pdfs['belege/${i.id}.pdf']!,
            },
        };
        final from = DateTime(year);
        final to = DateTime(year, 12, 31);
        final files = buildGobdPackage(
          GobdRequest(
            supplierName: company.name,
            supplierLocation: workspace.address,
            from: from,
            to: to,
            invoices: exported,
            matches: matches,
            instalments: books.instalments,
            ledger: ledger,
            repartitions: repartitions,
            purchases: books.purchases,
            memberNames: memberNames,
            sequences: sequences,
            auditEvents: buildAuditEvents(
              invoices: exported,
              matches: matches,
              ledger: ledger,
            ),
            taxRates: [
              for (final row in reference.where(TaxDomain.rate))
                if (row.country == country) row,
            ],
            vouchers: vouchers,
            procedure: {
              gobdProcedureFileName: textBytes(
                buildGobdProcedureDocument(l10n, (
                  workspace: workspace.name,
                  country: country,
                  reference: reference,
                  from: from,
                  to: to,
                  generatedAt: now,
                  fiscalYearStart: datevProfileFiscalStart(
                    bookProfiles,
                    from,
                    to,
                  ),
                  serverSchema: schema,
                  sequences: sequences,
                )),
              ),
            },
          ),
        );
        await _saveZip(files, rows: exported.length);
      },
    );
  }

  /// The PDF/A-3 of each of [invoices] at [pathOf]; null when one did not
  /// render, which ends the export: a package missing a voucher is never
  /// saved as complete.
  Future<Map<String, List<int>>?> _vouchers(
    List<Invoice> invoices,
    String Function(Invoice invoice) pathOf,
  ) async {
    final files = <String, List<int>>{};
    for (final invoice in invoices) {
      if (!context.mounted) return null;
      final pdf = await buildFacturXFile(
        context,
        ref,
        invoice,
        seller: sellerOf(invoice, workspace),
        buyer: buyerOf(invoice, workspace),
        iban: workspaceIban(workspace),
      );
      if (pdf.bytes.isEmpty) return null;
      files[pathOf(invoice)] = pdf.bytes;
    }
    return files;
  }

  /// Saves [files] as one zip and logs it with its digest.
  Future<void> _saveZip(
    Map<String, List<int>> files, {
    required int rows,
  }) async {
    final bytes = zipBundle(files);
    if (!context.mounted) return;
    await savePdfToDownloads(
      context,
      ref,
      bytes: bytes,
      fileName: named(format.id),
    );
    await ref
        .read(bookPeriodCommandProvider)
        .logExportBytes(
          workspace.id,
          formatId: format.id,
          year: year,
          bytes: bytes,
          rows: rows,
          documents: exported.length,
        );
  }
}
