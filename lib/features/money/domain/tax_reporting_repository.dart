// SPDX-License-Identifier: AGPL-3.0-or-later
import 'vat_declaration.dart';
import 'vat_rate.dart';

/// #2591 C3 — the workspace's VAT: the rates it charges and the returns it
/// prepares and files. The server computes the figures; this port never
/// renders an invoice.
abstract interface class TaxReportingRepository {
  /// The workspace's VAT declarations (0107), newest period first.
  Future<List<VatDeclaration>> fetchVatDeclarations(String workspaceId);

  /// #2357 — prepares (or prepares again) the return of a period. The
  /// SERVER computes its figures (`compute_vat_return`, 0402); the client
  /// sends the period alone and then reads the stored row.
  Future<String> saveVatDeclaration({
    required String workspaceId,
    required DateTime periodStart,
    required DateTime periodEnd,
  });

  /// Records that the owner filed the prepared return with the tax
  /// authority ([channel] `manual` or `export`), with the [receipt]
  /// reference the authority gave — the only way a return is filed.
  Future<void> markVatDeclarationSubmitted({
    required String declarationId,
    required String channel,
    required String receipt,
  });

  /// The VAT rates the workspace charges (0072), member-readable: they
  /// appear on the bill and on every invoice.
  Future<List<VatRate>> fetchVatRates(String workspaceId);

  /// Owner-only (RPC `set_vat_rates`): replaces the whole rate set
  /// atomically. Exactly one rate must be the default. A rate a service
  /// still points at is deactivated rather than deleted, so no catalogue
  /// entry is ever silently re-taxed.
  Future<void> setVatRates(String workspaceId, List<VatRate> rates);
}
