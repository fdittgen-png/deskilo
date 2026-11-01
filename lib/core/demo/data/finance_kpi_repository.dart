// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/core/settings/setting_defaults.g.dart';
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/recorded_payments.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';

import '../../time/date_text.dart';
import 'money_repository.dart';
import 'workspace_repository.dart';

/// The finance KPIs over the demo's own invoices and matches, with the
/// predicates of `kpi_finance_summary` (0351): invoiced = non-void,
/// non-settlement invoices of the months with a positive total, credit
/// notes named apart; collected = what the matches consumed, by the
/// month of the match on the workspace clock. The demo used to answer
/// "no server in this mode", so the Activity analysis showed nothing.
class DemoFinanceKpiRepository implements FinanceKpiRepository {
  DemoFinanceKpiRepository({
    required this.money,
    required this.workspaces,
    required this.now,
  });

  final FakeMoneyRepository money;
  final FakeWorkspaceRepository workspaces;
  final DateTime now;

  static String _month(DateTime d) =>
      yearMonth(d.year, d.month);

  @override
  Future<FinanceSummaryKpi> summary(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async {
    final workspace = workspaces.workspaces
        .where((w) => w.id == workspaceId)
        .firstOrNull;
    final currency = workspace?.currencyCode.trim().toUpperCase() ?? '';
    if (currency.isEmpty) {
      throw const KpiUnavailable('the workspace has no currency');
    }
    bool inRange(String? month) =>
        month != null &&
        month.compareTo(fromMonth) >= 0 &&
        month.compareTo(toMonth) <= 0;

    var invoiced = 0, creditNotes = 0, invoices = 0;
    var mixed = false;
    for (final i in money.invoices) {
      if (i.workspaceId != workspaceId ||
          i.voidedAt != null ||
          i.kind == InvoiceKind.settlement ||
          !inRange(i.period)) {
        continue;
      }
      if (i.currency.isNotEmpty && i.currency.toUpperCase() != currency) {
        mixed = true;
      }
      if (i.totalCents > 0) {
        invoiced += i.totalCents;
        invoices++;
      } else if (i.totalCents < 0) {
        creditNotes -= i.totalCents;
      }
    }

    final byId = {for (final i in money.invoices) i.id: i};
    var collected = 0, matches = 0;
    for (final m in money.invoiceMatchesStore.values) {
      final invoice = byId[m.invoiceId];
      // A match that consumed no payment (a refunded credit note) holds
      // no row in invoice_match_payments.
      if (m.paymentLedgerId == null || invoice?.workspaceId != workspaceId) {
        continue;
      }
      if (!inRange(_month(WorkspaceTime.wall(m.matchedAt)))) continue;
      collected += m.paidCents;
      matches++;
      if (invoice!.currency.isNotEmpty &&
          invoice.currency.toUpperCase() != currency) {
        mixed = true;
      }
    }

    final partial = toMonth.compareTo(_month(WorkspaceTime.wall(now))) >= 0;
    return FinanceSummaryKpi(
      fromMonth: fromMonth,
      toMonth: toMonth,
      currency: currency,
      invoicedMinor: invoiced,
      creditNotesMinor: creditNotes,
      collectedMinor: collected,
      invoices: invoices,
      matches: matches,
      quality: {
        if (mixed) KpiQuality.unavailable,
        if (partial) KpiQuality.partial,
      },
      reasons: [if (mixed) 'currency_mix', if (partial) 'period_not_over'],
      computedAt: now,
    );
  }
}

/// #2578 — the payments behind the collected figure over the demo's own
/// matches, with the predicates of `workspace_recorded_payments_v1` (0643)
/// and of [DemoFinanceKpiRepository]: a match that consumed a payment, by
/// the local day of the match, newest first, a page of the registry's
/// default size continued by the last row's keys.
class DemoRecordedPaymentsRepository implements RecordedPaymentsRepository {
  DemoRecordedPaymentsRepository({
    required this.money,
    required this.workspaces,
    this.pageSize = SettingDefaults.biDetailPageSize,
  });

  final FakeMoneyRepository money;
  final FakeWorkspaceRepository workspaces;
  final int pageSize;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Future<RecordedPaymentsPage> page(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
    RecordedPaymentsCursor? after,
    int? limit,
  }) async {
    final workspace = workspaces.workspaces
        .where((w) => w.id == workspaceId)
        .firstOrNull;
    final currency = workspace?.currencyCode.trim().toUpperCase() ?? '';
    final first = _day(from), last = _day(to);
    final byId = {for (final i in money.invoices) i.id: i};
    final ledger = {for (final e in money.ledger) e.id: e};
    final rows = <RecordedPayment>[];
    for (final m in money.invoiceMatchesStore.values) {
      final invoice = byId[m.invoiceId];
      final paymentId = m.paymentLedgerId;
      if (paymentId == null ||
          invoice == null ||
          invoice.workspaceId != workspaceId) {
        continue;
      }
      final day = _day(WorkspaceTime.wall(m.matchedAt));
      if (day.isBefore(first) || day.isAfter(last)) continue;
      final entry = ledger[paymentId];
      rows.add(
        RecordedPayment(
          id: paymentId,
          matchedAt: m.matchedAt,
          paidOn: entry?.occurredOn,
          amountMinor: m.paidCents,
          currency: invoice.currency.isEmpty
              ? currency
              : invoice.currency.toUpperCase(),
          invoiceId: invoice.id,
          invoiceNumber: invoice.number,
          payerName: invoice.memberName,
          resolution: m.resolution,
          label: entry?.description,
        ),
      );
    }
    int newestFirst(RecordedPayment a, RecordedPayment b) {
      final at = b.matchedAt.compareTo(a.matchedAt);
      return at != 0 ? at : b.id.compareTo(a.id);
    }

    rows.sort(newestFirst);
    final start = after == null
        ? 0
        : rows.indexWhere((r) {
            final at = DateTime.parse(after.matchedAt);
            return r.matchedAt.isBefore(at) ||
                (r.matchedAt.isAtSameMomentAs(at) &&
                    r.id.compareTo(after.id) < 0);
          });
    final size = limit == null || limit > pageSize ? pageSize : limit;
    final rest = start < 0 ? const <RecordedPayment>[] : rows.sublist(start);
    final items = rest.take(size).toList();
    return RecordedPaymentsPage(
      items: items,
      pageSize: size,
      nextCursor: rest.length > size
          ? RecordedPaymentsCursor(
              matchedAt: items.last.matchedAt.toUtc().toIso8601String(),
              id: items.last.id,
            )
          : null,
    );
  }
}
