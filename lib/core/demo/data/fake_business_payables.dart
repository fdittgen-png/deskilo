// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4167 (B) -- the Demo's payables of a business, read from the same in-memory
// obligations its purchase flow mutates: the supplier balances exactly as the
// supplier reads answer them, and what it owes its members back (the member
// creditor kind), held counted as part of what remains. A space the Demo keeps
// no purchasing for answers as a refusal.
import '../../../features/money/domain/business_payables.dart';
import '../../../features/money/domain/purchase.dart';
import '../../../features/money/domain/supplier_balance.dart';
import '../../../features/money/domain/supplier_payables_page.dart';
import 'purchase_repository.dart';
import 'supplier_balance_repository.dart';

class FakeBusinessPayablesRepository implements BusinessPayablesRepository {
  const FakeBusinessPayablesRepository(this._purchasesOf);

  /// The purchases of a space, or null when the Demo keeps none for it.
  final FakePurchaseRepository? Function(String workspaceId) _purchasesOf;

  FakePurchaseRepository _of(String workspaceId) =>
      _purchasesOf(workspaceId) ?? (throw const BusinessPayablesRefusal());

  @override
  Future<List<SupplierBalance>> supplierBalances(String workspaceId) =>
      FakeSupplierBalanceRepository(
        workspaceId: workspaceId,
        purchases: _of(workspaceId),
      ).fetchBalances(workspaceId);

  @override
  Future<MemberReimbursements> memberReimbursements(String workspaceId) async {
    final remaining = <String, int>{};
    final held = <String, int>{};
    final open = <String, int>{};
    for (final row in _of(workspaceId).payables) {
      final o = row.obligation;
      if (o.creditorKind != CreditorKind.member ||
          o.state == ObligationState.cancelled) {
        continue;
      }
      remaining[o.currency] = (remaining[o.currency] ?? 0) + o.remainingCents;
      if (o.state == ObligationState.held) {
        held[o.currency] = (held[o.currency] ?? 0) + o.remainingCents;
      }
      if (o.remainingCents > 0) open[o.currency] = (open[o.currency] ?? 0) + 1;
    }
    return MemberReimbursements(
      workspaceId: workspaceId,
      rows: [
        for (final c in remaining.keys.toList()..sort())
          MemberReimbursementRow(
            currency: c,
            remainingCents: remaining[c]!,
            heldCents: held[c] ?? 0,
            obligations: open[c] ?? 0,
          ),
      ],
    );
  }

  static const _pageSize = 50;
  static const _cursorDate = '2000-01-01T00:00:00Z';

  @override
  Future<SupplierPayablesPage> payablesPage(
    String workspaceId,
    String currency, {
    String? creditorKind,
    SupplierPayablesCursor? after,
  }) async {
    final rows = [
      for (final row in _of(workspaceId).payables)
        if (row.obligation.currency == currency &&
            row.obligation.state != ObligationState.cancelled &&
            (creditorKind == null || row.obligation.creditorKind.name == creditorKind))
          row,
    ]..sort((a, b) => b.obligation.id.compareTo(a.obligation.id));
    final from = after == null
        ? 0
        : rows.indexWhere((r) => r.obligation.id == after.id) + 1;
    final shown = rows.skip(from).take(_pageSize).toList();
    final more = from + shown.length < rows.length;
    return SupplierPayablesPage(
      rows: shown,
      next: more ? (created: _cursorDate, id: shown.last.obligation.id) : null,
    );
  }
}
