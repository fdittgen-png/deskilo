// SPDX-License-Identifier: AGPL-3.0-or-later

import '../../../features/money/domain/purchase.dart';
import '../../../features/money/domain/supplier_balance.dart';
import '../../../features/money/domain/supplier_payables_page.dart';
import 'purchase_repository.dart';

/// Demo reads the same in-memory obligations its purchase flow mutates.
class FakeSupplierBalanceRepository implements SupplierBalanceRepository {
  FakeSupplierBalanceRepository({
    required this.workspaceId,
    required this.purchases,
  });

  final String workspaceId;
  final FakePurchaseRepository purchases;
  static const _pageSize = 100;
  static const _cursorDate = '2000-01-01T00:00:00Z';

  void _checkWorkspace(String requested) {
    if (requested != workspaceId) throw StateError('unknown workspace');
  }

  @override
  Future<List<SupplierBalance>> fetchBalances(String requested) async {
    _checkWorkspace(requested);
    final totals = <(String, String), int>{};
    for (final row in purchases.payables) {
      final obligation = row.obligation;
      if (obligation.creditorKind != CreditorKind.supplier ||
          obligation.state == ObligationState.cancelled) {
        continue;
      }
      final key = (obligation.creditorId, obligation.currency);
      totals[key] = (totals[key] ?? 0) + obligation.remainingCents;
    }
    return [
      for (final MapEntry(key: (supplier, currency), value: amount)
          in totals.entries)
        SupplierBalance(
          supplierId: supplier,
          currency: currency,
          remainingCents: amount,
        ),
    ];
  }

  @override
  Future<SupplierPayablesPage> fetchPayables(
    String requested,
    String supplierId, {
    SupplierPayablesCursor? after,
  }) async {
    _checkWorkspace(requested);
    final rows = [
      for (final row in purchases.payables)
        if (row.obligation.creditorKind == CreditorKind.supplier &&
            row.obligation.creditorId == supplierId)
          row,
    ]..sort((a, b) => a.obligation.id.compareTo(b.obligation.id));
    var start = 0;
    if (after != null) {
      if (after.created != _cursorDate) throw StateError('invalid cursor');
      final index = rows.indexWhere((row) => row.obligation.id == after.id);
      if (index < 0) throw StateError('stale cursor');
      start = index + 1;
    }
    final page = rows.skip(start).take(_pageSize).toList();
    return SupplierPayablesPage(
      rows: page,
      next: start + page.length < rows.length
          ? (created: _cursorDate, id: page.last.obligation.id)
          : null,
    );
  }
}
