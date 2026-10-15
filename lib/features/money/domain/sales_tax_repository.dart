// SPDX-License-Identifier: AGPL-3.0-or-later
import 'sales_tax_return.dart';
import 'tax_exemption_certificate.dart';

/// #2362 -- where the sales-tax summary of a period and the customers'
/// exemption certificates are read and written.
abstract interface class SalesTaxRepository {
  /// `sales_tax_return`: the figures of the invoices issued from [start] to
  /// [end] (both included), per state and jurisdiction.
  Future<List<SalesTaxReturnRow>> fetchReturn(
    String workspaceId, {
    required DateTime start,
    required DateTime end,
  });

  /// The certificates of [memberId], the newest first.
  Future<List<TaxExemptionCertificate>> fetchCertificates(String memberId);

  /// Records a certificate (`set_tax_exemption_certificate`); [validTo] null
  /// leaves it open-ended. Whoever may manage billing; the server checks.
  Future<void> saveCertificate(TaxExemptionCertificateDraft draft);

  /// Ends a certificate on [on] (`end_tax_exemption_certificate`).
  Future<void> endCertificate(String id, DateTime on);
}
