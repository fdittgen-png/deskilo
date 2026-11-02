// SPDX-License-Identifier: AGPL-3.0-or-later

import '../../../features/money/domain/purchase.dart';
import '../../../features/money/domain/purchase_approval_reads.dart';
import 'purchase_exchange_rates.dart';
import 'purchase_repository.dart';

/// The Demo approver reviews bills submitted by another Demo member. Member
/// receipts belong to expense validation, not this decision flow.
class FakePurchaseApprovalReads implements PurchaseApprovalReads {
  FakePurchaseApprovalReads(this.purchases, {this.thresholdUnits});
  final FakePurchaseRepository purchases;
  final Future<int> Function(String workspaceId)? thresholdUnits;
  static const _cursorDate = '2000-01-01T00:00:00Z';
  static const _pageSize = 100;

  Future<List<PurchaseSummary>> _eligible(String workspaceId) async {
    if (workspaceId != 'ws-1') {
      throw StateError('purchase approvals are not available');
    }
    final rows = await purchases.fetchPurchases(workspaceId);
    final threshold = await thresholdUnits?.call(workspaceId) ?? 0;
    return [
      for (final d in rows)
        if (d.kind == PurchaseKind.bill &&
            d.state == PurchaseState.pending &&
            (!purchases.isDemoMaker(d.id) || d.grossCents < threshold * 100))
          d,
    ]..sort((a, b) => b.id.compareTo(a.id));
  }

  @override
  Future<PurchaseApprovalPage> page(
    String workspaceId, {
    PurchaseApprovalCursor? after,
  }) async {
    final rows = await _eligible(workspaceId);
    if (after != null && after.created != _cursorDate) {
      throw StateError('invalid cursor');
    }
    final rest = after == null
        ? rows
        : rows.where((d) => d.id.compareTo(after.id) < 0).toList();
    final page = rest.take(_pageSize).toList();
    final versions = <String>[];
    for (final row in rows) {
      final detail = await purchases.fetchDetail(workspaceId, row.id);
      versions.add(
        '${row.id}:${detail.revision}:${purchases.isDemoMaker(row.id)}',
      );
    }
    return PurchaseApprovalPage(
      rows: page,
      count: rows.length,
      version: versions.join(','),
      next: rest.length > page.length
          ? (created: _cursorDate, id: page.last.id)
          : null,
    );
  }

  @override
  Future<PurchaseApprovalDetail> detail(
    String workspaceId,
    String purchaseId,
  ) async {
    final rows = await _eligible(workspaceId);
    if (!rows.any((d) => d.id == purchaseId)) {
      throw StateError('purchase approval is not available');
    }
    final original = await purchases.fetchDetail(workspaceId, purchaseId);
    final detail = PurchaseDetail(
      summary: original.summary,
      revision: original.revision,
      lines: original.lines,
      sources: const [],
      supplierName: original.supplierName,
      supplierNumber: original.supplierNumber,
      dueOn: original.dueOn,
    );
    final currency = original.summary.currency;
    const space = DemoPurchaseExchangeRates.spaceCurrency;
    final held = currency == space
        ? null
        : await purchases.fetchExchangeRate(workspaceId, purchaseId);
    final fx = PurchaseApprovalFx(
      status: currency == space
          ? PurchaseApprovalFxStatus.sameCurrency
          : held == null
              ? PurchaseApprovalFxStatus.missing
              : PurchaseApprovalFxStatus.recorded,
      currency: currency,
      functionalCurrency: space,
      rate: held?.entry.rate.toString(),
      rateDate: held?.entry.rateDate,
      source: held?.entry.source,
    );
    return PurchaseApprovalDetail(
      fx: fx,
      detail: detail,
      canApprove: true,
      canReject: !purchases.isDemoMaker(purchaseId),
    );
  }
}
