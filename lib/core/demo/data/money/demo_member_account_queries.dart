// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/core/time/date_text.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/domain/member_account.dart';
import 'package:deskilo/features/money/domain/member_account_queries.dart';
import 'package:deskilo/features/money/domain/statement.dart';
import 'package:deskilo/features/money/domain/usage_record.dart';

import '../money_repository.dart';
import 'demo_member_statement.dart';

/// #2591 — a member's account, statement, ledger and usage reads, in the demo:
/// answered from one space's in-memory money store ([FakeMoneyRepository]);
/// every other port of that space reads and writes the same store.
class DemoMemberAccountQueries implements MemberAccountQueries {
  DemoMemberAccountQueries(this._m);

  final FakeMoneyRepository _m;

  /// #3305 — set by the Demo: the statement is then each member's own, as the
  /// server computes it; unset, a test's canned [FakeMoneyRepository.statement].
  DemoStatementSource? statementSource;

  @override
  Future<Statement> fetchStatement(String memberId, String period) async {
    _m.fetchedPeriods.add(period);
    if (statementSource case final source?) {
      return demoMemberStatement(_m, source, memberId, period);
    }
    // #512 — months fully before the membership owe NOTHING.
    if (_m.memberJoinedPeriod != null &&
        period.compareTo(_m.memberJoinedPeriod!) < 0) {
      return Statement(
        period: period,
        subscriptionPct: _m.statement.subscriptionPct,
        feeCents: 0,
        includedHalfDays: 0,
        openDays: 0,
        usedHalfDays: 0,
        extraHalfDays: 0,
        overageCents: 0,
        creditsCents: 0,
        balanceCents: 0,
        overagePolicy: _m.statement.overagePolicy,
      );
    }
    return _m.statements[period] ?? _m.statement.copyWith(period: period);
  }

  @override
  Future<MemberAccount> fetchMemberAccount(String memberId) async {
    if (_m.accountFailure != null) throw _m.accountFailure!;
    // Mirrors the member_account RPC over the fake stores.
    bool consumed(LedgerEntry e) =>
        _m.consumedPaymentIds.contains(e.id) ||
        _m.invoiceMatchesStore.values.any((m) => m.paymentLedgerId == e.id);
    bool baked(LedgerEntry e) => _m.invoices.any(
      (i) =>
          i.memberId == memberId &&
          !i.isVoided &&
          i.period == e.period &&
          i.issuedAt.isAfter(e.createdAt),
    );
    // Spare credit only: an avoir of any month, or a payment left over
    // from a PAST month — running-month payments offset the upcoming
    // invoice and stay ordinary payments.
    // #3292 — the space's own day (the Demo's clock), not the tests' fixed one.
    final today = _m.clock();
    final nowPeriod = yearMonth(today.year, today.month);
    final credit = _m.ledger
        .where(
          (e) =>
              e.memberId == memberId &&
              e.kind == LedgerKind.credit &&
              (e.category == LedgerCategory.adjustment ||
                  (e.category == LedgerCategory.payment &&
                      e.period.compareTo(nowPeriod) < 0)) &&
              !consumed(e) &&
              !baked(e),
        )
        .fold(0, (sum, e) => sum + e.amountCents);
    final replaced = {for (final i in _m.invoices) ?i.replacesInvoiceId};
    final open = <OpenInvoicePosition>[];
    for (final invoice in _m.invoices) {
      if (invoice.memberId != memberId ||
          invoice.isVoided ||
          invoice.totalCents <= 0 ||
          replaced.contains(invoice.id)) {
        continue;
      }
      final match = _m.invoiceMatchesStore[invoice.id];
      final settledPartial =
          match != null &&
          !match.pending &&
          match.resolution == 'under_accepted' &&
          match.writeoffAt == null;
      if (match != null && !match.pending && !settledPartial) continue;
      final paid = settledPartial ? match.paidCents : 0;
      open.add((
        invoiceId: invoice.id,
        number: invoice.number,
        period: invoice.period ?? '',
        totalCents: invoice.totalCents,
        paidCents: paid,
        remainingCents: invoice.totalCents - paid,
      ));
    }
    final openTotal = open.fold(0, (sum, o) => sum + o.remainingCents);
    final refunds = _m.invoices
        .where(
          (i) =>
              i.memberId == memberId &&
              !i.isVoided &&
              i.totalCents < 0 &&
              _m.invoiceMatchesStore[i.id] == null,
        )
        .fold(0, (sum, i) => sum - i.totalCents);
    return MemberAccount(
      creditCents: credit,
      openInvoices: open,
      openTotalCents: openTotal,
      refundsDueCents: refunds,
      netPositionCents: credit + refunds - openTotal,
    );
  }

  @override
  Future<List<LedgerEntry>> fetchLedger(String memberId) async => [
    // #3292 — one member's entries, as the server's `member_id` filter reads.
    for (final e in _m.ledger)
      if (e.memberId == memberId) e,
  ];

  @override
  Future<List<LedgerEntry>> fetchWorkspaceLedger(String workspaceId) async =>
      List.of(_m.ledger);
  Future<List<UsageRecord>> _usageRecords({
    required String workspaceId,
    required String period,
    String? memberId,
  }) async => [
    for (final record in _m.usageRecords)
      if (record.period == period &&
          (memberId == null || record.memberId == memberId))
        record,
  ];

  @override
  Future<UsageRead> readUsageRecords({
    required String workspaceId,
    required String period,
    String? memberId,
  }) async => UsageRead(
    records: await _usageRecords(
      workspaceId: workspaceId,
      period: period,
      memberId: memberId,
    ),
  );

  @override
  Future<bool> hasRecordedMoney(String workspaceId) async =>
      _m.invoices.isNotEmpty || _m.ledger.isNotEmpty;
}
