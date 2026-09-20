// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1279 — a carnet a workspace sells (0236 `credit_products`).
import '../../../core/data/system_columns.dart';

/// Prepaid half-days, spent across months when a member books beyond their
/// subscription; charged once, at the sale.
class CreditProduct implements SystemStamped {
  const CreditProduct({
    required this.id,
    required this.name,
    required this.halfDays,
    required this.priceCents,
    this.validityMonths,
    this.active = true,
    this.system = SystemColumns.none,
  });

  /// #992 — the server's stamp on this row.
  @override
  final SystemColumns system;

  final String id;
  final String name;
  final int halfDays;
  final int priceCents;

  /// Null: the carnet never expires.
  final int? validityMonths;
  final bool active;

  factory CreditProduct.fromRow(Map<String, dynamic> row) => CreditProduct(
        system: SystemColumns.fromRow(row),
        id: row['id'] as String,
        name: row['name'] as String? ?? '',
        halfDays: (row['half_days'] as num).toInt(),
        priceCents: (row['price_cents'] as num?)?.toInt() ?? 0,
        validityMonths: (row['validity_months'] as num?)?.toInt(),
        active: row['active'] as bool? ?? true,
      );
}

/// The seam over carnets. The server decides who may sell and read: the
/// catalogue is RLS like packages; a sale and a balance are guarded RPCs.
abstract class CreditRepository {
  Future<List<CreditProduct>> fetchCreditProducts(String workspaceId);

  Future<void> createCreditProduct(
    String workspaceId, {
    required String name,
    required int halfDays,
    required int priceCents,
    int? validityMonths,
  });

  Future<void> setCreditProductActive(String productId, bool active);

  /// Sells [productId] to [memberId]; returns the credit's id.
  Future<String> sellCredit(
      String workspaceId, String memberId, String productId);

  /// Half-days [memberId] can still spend.
  Future<int> memberCreditBalance(String memberId);
}
