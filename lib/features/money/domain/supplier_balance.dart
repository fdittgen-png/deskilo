// SPDX-License-Identifier: AGPL-3.0-or-later

import '../../../core/data/json_reader.dart';

/// A server-computed outstanding amount for one supplier and currency.
/// Unlike the paged payable list, this is a complete workspace aggregate.
class SupplierBalance {
  const SupplierBalance({
    required this.supplierId,
    required this.currency,
    required this.remainingCents,
  });

  factory SupplierBalance.fromJson(Object? raw) {
    final row = JsonReader.of(raw, context: 'supplier balance');
    return SupplierBalance(
      supplierId: row.string('supplier_id'),
      currency: row.string('currency'),
      remainingCents: row.integer('remaining_cents'),
    );
  }

  final String supplierId;
  final String currency;
  final int remainingCents;
}

/// One complete snapshot for the workspace, with separate currency rows.
abstract interface class SupplierBalanceRepository {
  Future<List<SupplierBalance>> fetchBalances(String workspaceId);
}
