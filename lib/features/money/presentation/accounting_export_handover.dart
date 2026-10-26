// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The readable handover of an archive (readable_handover.dart): the tables
// of the year's one export snapshot, described in English, for a country
// whose authority reads the records with its own audit software.
import '../../../core/vat/tax_reference.dart';
import '../domain/audit_trail.dart';
import '../domain/gobd_package.dart';
import '../domain/readable_handover.dart';
import 'accounting_export_run.dart';
import 'invoice_actions.dart';

extension ReadableHandoverExport on AccountingExportRun {
  /// The handover's files for the archive of [year], or none outside the
  /// countries that ask for it. [vouchers] are the archive's own invoice
  /// files by invoice id, [auditEvents] the audit trail the archive carries.
  Future<Map<String, List<int>>> readableHandover({
    required Map<String, Map<String, List<int>>> vouchers,
    required List<AuditEvent> auditEvents,
  }) async {
    if (!archiveCarriesReadableHandover(country)) return const {};
    // The rates of this workspace's own installation; an archive never
    // states another's.
    final reference = workspaceTaxReference(ref);
    if (reference == null) throw StateError('workspace context not ready');
    final sequences = await repo.fetchNumberSequences(workspace.id);
    return readableHandoverFiles(
      GobdRequest(
        supplierName: company.name,
        supplierLocation: workspace.address,
        dayOf: workspaceDayOf,
        from: DateTime(year),
        to: DateTime(year, 12, 31),
        invoices: exported,
        matches: matches,
        instalments: books.instalments,
        ledger: ledger,
        repartitions: repartitions,
        purchases: books.purchases,
        memberNames: memberNames,
        sequences: sequences,
        auditEvents: auditEvents,
        taxRates: [
          for (final row in reference.where(TaxDomain.rate))
            if (row.country == country) row,
        ],
        vouchers: vouchers,
      ),
    );
  }
}
