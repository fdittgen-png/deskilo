// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4167 (A) -- the Demo's receivables of a business, computed from the invoices
// and matches of that space's own money store, so the figures agree with the
// invoice pages of the same space. A space that keeps no store answers as a
// refusal, as a business the person may not read does.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

import '../../../features/money/domain/business_receivables.dart';
import 'money_repository.dart';

class FakeBusinessReceivablesRepository implements BusinessReceivablesRepository {
  const FakeBusinessReceivablesRepository(this._moneyOf);

  /// The money store of a space, or null when the Demo keeps none for it.
  final FakeMoneyRepository? Function(String workspaceId) _moneyOf;

  @override
  Future<BusinessReceivables> summary(String workspaceId) async {
    final money = _moneyOf(workspaceId);
    if (money == null) throw const BusinessReceivablesRefusal();
    final byCurrency = <String, ({int collect, int refund, int n})>{};
    for (final Invoice i in money.invoices) {
      if (i.isVoided || i.settledByInvoiceId != null) continue;
      final paid = money.invoiceMatchesStore[i.id]?.paidCents ?? 0;
      final owed = i.totalCents - paid;
      final cents = i.totalCents < 0 ? -i.totalCents : owed;
      if (cents <= 0) continue;
      final was = byCurrency[i.currency] ?? (collect: 0, refund: 0, n: 0);
      byCurrency[i.currency] = i.totalCents < 0
          ? (collect: was.collect, refund: was.refund + cents, n: was.n + 1)
          : (collect: was.collect + cents, refund: was.refund, n: was.n + 1);
    }
    return BusinessReceivables(
      workspaceId: workspaceId,
      rows: [
        for (final e in byCurrency.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
          BusinessReceivablesRow(
            currency: e.key,
            toCollectCents: e.value.collect,
            declaredCents: 0,
            receivedUnmatchedCents: 0,
            awaitingCents: 0,
            refundDueCents: e.value.refund,
            invoices: e.value.n,
          ),
      ],
    );
  }

  static const _pageSize = 50;

  @override
  Future<ReceivablesPage> page(
    String workspaceId,
    String currency, {
    ReceivableState? state,
    ReceivablesCursor? after,
  }) async {
    final money = _moneyOf(workspaceId);
    if (money == null) throw const BusinessReceivablesRefusal();
    final rows = <ReceivableInvoiceRow>[];
    for (final Invoice i in money.invoices) {
      if (i.isVoided || i.settledByInvoiceId != null || i.currency != currency) {
        continue;
      }
      final paid = money.invoiceMatchesStore[i.id]?.paidCents ?? 0;
      final credit = i.totalCents < 0;
      final cents = credit ? -i.totalCents : i.totalCents - paid;
      if (cents <= 0) continue;
      final rowState = credit ? ReceivableState.refundDue : ReceivableState.toCollect;
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
