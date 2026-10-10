// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';

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
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

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
