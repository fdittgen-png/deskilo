// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/time/date_text.dart';
import '../../../features/money/domain/sales_tax_repository.dart';
import '../../../features/money/domain/sales_tax_return.dart';
import '../../../features/money/domain/tax_exemption_certificate.dart';

/// #2362 -- the sales-tax summary and the certificates in memory. The demo
/// issues no sales-tax invoice, so it states nothing unless a test seeds [rows].
class FakeSalesTaxRepository implements SalesTaxRepository {
  final List<SalesTaxReturnRow> rows = [];

  /// memberId -> its certificates.
  final Map<String, List<TaxExemptionCertificate>> certificates = {};
  int _next = 0;

  @override
  Future<List<SalesTaxReturnRow>> fetchReturn(
    String workspaceId, {
    required DateTime start,
    required DateTime end,
  }) async => List.of(rows);

  @override
  Future<List<TaxExemptionCertificate>> fetchCertificates(
    String memberId,
  ) async => List.of(certificates[memberId] ?? const []);

  @override
  Future<void> saveCertificate(TaxExemptionCertificateDraft draft) async {
    (certificates[draft.memberId] ??= []).insert(
      0,
      TaxExemptionCertificate(
        id: 'cert-${_next++}',
        kind: draft.kind,
        state: draft.state.toUpperCase(),
        number: draft.number.trim(),
        validFrom: isoDay(draft.validFrom),
        validTo: draft.validTo == null ? null : isoDay(draft.validTo!),
      ),
    );
  }

  @override
  Future<void> endCertificate(String id, DateTime on) async {
    for (final list in certificates.values) {
      final i = list.indexWhere((c) => c.id == id);
      if (i < 0) continue;
      final c = list[i];
      final end = isoDay(on).compareTo(c.validFrom) < 0
          ? c.validFrom
          : isoDay(on);
      list[i] = TaxExemptionCertificate(
        id: c.id,
        kind: c.kind,
        state: c.state,
        number: c.number,
        validFrom: c.validFrom,
        validTo: end,
      );
    }
  }
}
