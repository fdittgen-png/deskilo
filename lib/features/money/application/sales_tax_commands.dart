// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2362 -- what a member of a sales-tax space asks for: the worksheet of a
// period as a CSV, and the exemption certificates of a customer recorded or
// ended. The figures and the checks are the server's; nothing is filed.
import '../domain/sales_tax_repository.dart';
import '../domain/sales_tax_return.dart';
import '../domain/tax_exemption_certificate.dart';

class SalesTaxCommands {
  const SalesTaxCommands(this._repository);

  final SalesTaxRepository _repository;

  /// The worksheet of `[start, end]` as CSV text in [currency]'s grain, or
  /// null when the period has nothing to state.
  Future<String?> worksheetCsv({
    required String workspaceId,
    required String currency,
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await _repository.fetchReturn(
      workspaceId,
      start: start,
      end: end,
    );
    if (rows.isEmpty) return null;
    return salesTaxWorksheetCsv(
      rows,
      start: start,
      end: end,
      currency: currency,
    );
  }

  Future<void> saveCertificate(TaxExemptionCertificateDraft draft) =>
      _repository.saveCertificate(draft);

  Future<void> endCertificate(String id, DateTime on) =>
      _repository.endCertificate(id, on);
}
