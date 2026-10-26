// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Swiss journal of one accounting export run: the local book's postings
// of the fiscal year (the run's one postings read), as the KMU journal or as
// Banana's transactions import. The MWST codes come from the tax reference
// the workspace's context holds, the QR reference of each invoice from the
// QR-bill the invoice carries; nothing here reads the period again.
import '../../../core/ui/app_snack.dart';
import '../application/generic_journal_export.dart';
import '../domain/swiss_kmu.dart';
import '../domain/swiss_qr_bill_invoice.dart';
import 'accounting_export_journal.dart';
import 'accounting_export_run.dart';
import 'e_invoice_identity.dart';
import 'invoice_actions.dart';

extension SwissAccountingExports on AccountingExportRun {
  /// The Swiss journal in [layout], saved and logged under [stem].
  Future<void> swissJournalExport(
    SwissJournalLayout layout, {
    required String stem,
  }) async {
    final reference = workspaceTaxReference(ref);
    if (reference == null) {
      AppSnack.error(context, l10n.workspaceGenericError);
      return;
    }
    final instructions = workspace.paymentInstructions;
    // The reference the invoice's QR-bill carries (QRR on a QR-IBAN, SCOR
    // on an ordinary one); a document with no bill has none.
    final references = <String, String>{
      for (final i in exported)
        if (swissQrBillOf(
              i,
              iban: workspaceIban(workspace),
              qrIban: '${instructions['qr_iban'] ?? ''}',
              workspaceCountry: country,
            )
            case final bill? when bill.reference.isNotEmpty)
          i.id: bill.reference,
    };

    GenericJournal written(GenericJournal read) {
      if (read is! JournalPosted) return read;
      final journal = swissJournalOf(
        read.postings,
        reference: reference,
        paymentReferences: references,
        parties: read.parties,
      );
      return journal.missingCodes.isEmpty
          ? JournalFile(swissJournalFile(journal.rows, layout))
          : JournalTaxCodesMissing(journal.missingCodes);
    }

    await exportGenericJournal(
      context,
      () async => written(posted ?? const JournalNeedsLocalBook()),
      save: (content) => save(content, named(stem)),
    );
  }
}
