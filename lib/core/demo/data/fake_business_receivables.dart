// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4167 (A) -- the Demo's receivables of a business, computed from the invoices
// and matches of that space's own money store, so the figures agree with the
// invoice pages of the same space. A space that keeps no store answers as a
// refusal, as a business the person may not read does.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

import '../../../features/money/domain/business_receivables.dart';
import '../../../features/workspace/domain/workspace_permission.dart';
import 'money_repository.dart';

class FakeBusinessReceivablesRepository implements BusinessReceivablesRepository {
  const FakeBusinessReceivablesRepository(this._moneyOf);

  /// The money store of a space, or null when the Demo keeps none for it.
  final FakeMoneyRepository? Function(String workspaceId) _moneyOf;

  /// The space's money, when the person reads finances there as the server asks
  /// (`viewFinances`, 0830): a business with no store, or one where the person
  /// does not hold it, refuses.
  FakeMoneyRepository _readable(String workspaceId) {
    final money = _moneyOf(workspaceId);
    final held = money?.eventRepository?.viewerPermissions?.call();
    if (money == null ||
        (held != null && !held.contains(WorkspacePermission.viewFinances))) {
      throw const BusinessReceivablesRefusal();
    }
    return money;
  }

  @override
  Future<BusinessReceivables> summary(String workspaceId) async {
    final money = _readable(workspaceId);
    final byCurrency = <String, ({int collect, int declared, int refund, int n})>{};
    final claimed = _claimedInvoiceIds(money);
    for (final Invoice i in money.invoices) {
      if (i.isVoided || i.settledByInvoiceId != null) continue;
      final paid = money.invoiceMatchesStore[i.id]?.paidCents ?? 0;
      final owed = i.totalCents - paid;
      final cents = i.totalCents < 0 ? -i.totalCents : owed;
      if (cents <= 0) continue;
      final was = byCurrency[i.currency] ?? (collect: 0, declared: 0, refund: 0, n: 0);
      final isClaimed = i.totalCents >= 0 && claimed.contains(i.id);
      byCurrency[i.currency] = i.totalCents < 0
          ? (collect: was.collect, declared: was.declared, refund: was.refund + cents, n: was.n + 1)
          : (
              collect: was.collect + (isClaimed ? 0 : cents),
              declared: was.declared + (isClaimed ? cents : 0),
              refund: was.refund,
              n: was.n + 1,
            );
    }
    return BusinessReceivables(
      workspaceId: workspaceId,
      rows: [
        for (final e in byCurrency.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
          BusinessReceivablesRow(
            currency: e.key,
            toCollectCents: e.value.collect,
            declaredCents: e.value.declared,
            receivedUnmatchedCents: 0,
            awaitingCents: 0,
            refundDueCents: e.value.refund,
            invoices: e.value.n,
          ),
      ],
    );
  }

  /// The invoices a payment declared and not withdrawn names: the server buckets
  /// them as declared, not to collect (0830).
  static Set<String> _claimedInvoiceIds(FakeMoneyRepository money) => {
    for (final e in money.claims.entries)
      if (!money.withdrawnClaims.contains(e.key)) ...e.value,
  };

  static const _pageSize = 50;

  @override
  Future<ReceivablesPage> page(
    String workspaceId,
    String currency, {
    ReceivableState? state,
    ReceivablesCursor? after,
  }) async {
    final money = _readable(workspaceId);
    final rows = <ReceivableInvoiceRow>[];
    final claimed = _claimedInvoiceIds(money);
    for (final Invoice i in money.invoices) {
      if (i.isVoided || i.settledByInvoiceId != null || i.currency != currency) {
        continue;
      }
      final paid = money.invoiceMatchesStore[i.id]?.paidCents ?? 0;
      final credit = i.totalCents < 0;
      final cents = credit ? -i.totalCents : i.totalCents - paid;
      if (cents <= 0) continue;
      final rowState = credit
          ? ReceivableState.refundDue
          : claimed.contains(i.id)
          ? ReceivableState.declared
          : ReceivableState.toCollect;
      if (state != null && state != rowState) continue;
      rows.add(
        ReceivableInvoiceRow(
          invoiceId: i.id,
          number: i.number,
          issuedAt: i.issuedAt,
          dueOn: null,
          memberName: i.memberName,
          currency: i.currency,
          totalCents: i.totalCents,
          stillDueCents: cents,
          awaitingCents: 0,
          state: rowState,
        ),
      );
    }
    rows.sort((a, b) {
      final byDate = b.issuedAt.compareTo(a.issuedAt);
      return byDate != 0 ? byDate : b.invoiceId.compareTo(a.invoiceId);
    });
    final from = after == null
        ? 0
        : rows.indexWhere((r) => r.invoiceId == after.id) + 1;
    final shown = rows.skip(from).take(_pageSize).toList();
    final more = from + shown.length < rows.length;
    return ReceivablesPage(
      rows: shown,
      next: more
          ? (issuedAt: shown.last.issuedAt.toIso8601String(), id: shown.last.invoiceId)
          : null,
    );
  }
}
