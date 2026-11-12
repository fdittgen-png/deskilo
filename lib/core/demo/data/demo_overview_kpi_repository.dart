// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3785 — the overview's own figures of a Demo space, read now from that
// space's members, requests and invoices with the server's rules:
//
//   * people.active_memberships_current (`kpi_memberships_current`, 0536):
//     the memberships of the space whose status is active, each role
//     included;
//   * operations.pending_actions_current (`kpi_pending_actions_current`,
//     0598): the requests whose status is still pending plus the people
//     whose membership is still pending, the whole space's, not one
//     reader's list;
//   * sales.overdue_receivables (`kpi_overdue_receivables`, 0536): the
//     collectible remainder of every issued invoice in the overdue phase of
//     `invoice_dunning_state_core` (0331) without a hold; an unknown due
//     date and a hold are counted apart; an overdue invoice in another
//     currency leaves the amount unknown (`currency_mix`).
//
// A period that is not the current month gets today's value, said as such
// (`not_recorded` / `current_state`): no history is kept.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../../../features/events/domain/workspace_event.dart';
import '../../../features/workspace/domain/kpi_contract.dart';
import '../../../features/workspace/domain/kpi_overview.dart';
import '../../../features/workspace/domain/member.dart';
import 'event_repository.dart';
import 'money_repository.dart';
import 'workspace_repository.dart';

/// Where an invoice stands in the dunning rules (0331), as far as the
/// overview reads it.
enum DunningPhase { settled, unknownMaturity, preDue, overdue }

/// One invoice's state by `invoice_dunning_state_core`.
typedef DunningFacts = ({
  DunningPhase phase,
  int collectible,
  String? hold,
  String currency,
});

/// The resolutions that settle an invoice whatever was paid (0331).
const _settling = {'exact', 'over_forced', 'over_credit_note', 'refunded'};

/// The credit notes that replace [invoice]: what they give back in its
/// currency, and how many are in another one (0331 `v_credits`, `v_foreign`).
({int credited, int foreign}) _creditsOf(
  Invoice invoice,
  FakeMoneyRepository money,
) {
  var credited = 0, foreign = 0;
  for (final c in money.invoices) {
    if (c.replacesInvoiceId != invoice.id ||
        c.totalCents >= 0 ||
        c.voidedAt != null) {
      continue;
    }
    if (c.currency == invoice.currency) {
      credited -= c.totalCents;
    } else {
      foreign++;
    }
  }
  return (credited: credited, foreign: foreign);
}

/// What is still collectible on [invoice] (0331 `v_collectible`): nothing
/// once voided, regrouped, written off or settled by its match; else the
/// total less the confirmed payment and the credits, never below 0.
int _collectible(Invoice invoice, InvoiceMatch? match, int credited) {
  final confirmed = match != null && !match.pending ? match : null;
  if (invoice.voidedAt != null ||
      invoice.settledByInvoiceId != null ||
      confirmed?.writeoffAt != null ||
      _settling.contains(confirmed?.resolution)) {
    return 0;
  }
  final left = invoice.totalCents - (confirmed?.paidCents ?? 0) - credited;
  return left > 0 ? left : 0;
}

/// The phase of an invoice with [collectible] left, due on [due], on
/// [today] (0331 `v_phase`): the due day itself is overdue.
DunningPhase _phase(int collectible, DateTime? due, DateTime today) {
  if (collectible == 0) return DunningPhase.settled;
  if (due == null) return DunningPhase.unknownMaturity;
  final day = DateTime(today.year, today.month, today.day);
  return day.isBefore(DateTime(due.year, due.month, due.day))
      ? DunningPhase.preDue
      : DunningPhase.overdue;
}

/// `invoice_dunning_state_core` (0331) over the Demo's money, as of [today]:
/// what is still collectible on [invoice], in which phase, and the hold
/// that keeps it from the reminders (a recorded one, else another
/// currency's credit, else a payment waiting for its validation).
DunningFacts dunningFactsOf(
  Invoice invoice,
  FakeMoneyRepository money,
  DateTime today,
) {
  final (:credited, :foreign) = _creditsOf(invoice, money);
  final match = money.invoiceMatchesStore[invoice.id];
  final collectible = _collectible(invoice, match, credited);
  final pending = match != null && match.pending && match.paidCents > 0;
  return (
    phase: _phase(collectible, invoice.dueOn, today),
    collectible: collectible,
    hold:
        money.dunningHolds[invoice.id] ??
        (foreign > 0 ? 'mixed_currency' : (pending ? 'pending_payment' : null)),
    currency: invoice.currency,
  );
}

class DemoOverviewKpiRepository implements OverviewKpiRepository {
  DemoOverviewKpiRepository({
    required this.workspaces,
    required this.events,
    required this.money,
    required this.now,
  });

  /// The space's record and its memberships.
  final FakeWorkspaceRepository workspaces;
  final FakeEventRepository events;
  final FakeMoneyRepository money;
  final DateTime now;

  @override
  Future<OverviewFigure> figure(
    String workspaceId,
    String kpiId, {
    required String fromMonth,
    required String toMonth,
  }) async {
    final month = yearMonth(now.year, now.month);
    final current =
        month.compareTo(fromMonth) >= 0 && month.compareTo(toMonth) <= 0;
    final members = [
      for (final m in await workspaces.fetchMembers(workspaceId))
        if (m.workspaceId == workspaceId) m,
    ];
    int count(bool Function(Member) where) => members.where(where).length;
    return switch (kpiId) {
      'people.active_memberships_current' => _count(
        count((m) => m.status == MemberStatus.active),
        current,
      ),
      'operations.pending_actions_current' => _count(
        events.events
                .where(
                  (e) =>
                      e.workspaceId == workspaceId &&
                      e.status == EventStatus.pending,
                )
                .length +
            count((m) => m.status == MemberStatus.pending),
        current,
      ),
      'sales.overdue_receivables' => _overdue(workspaceId, current),
      _ => throw KpiUnavailable('no overview figure $kpiId'),
    };
  }

  OverviewFigure _count(int n, bool current) => OverviewFigure(
    value: n,
    count: n,
    currency: '',
    quality: {if (!current) KpiQuality.notRecorded},
    reasons: [if (!current) 'current_state'],
    computedAt: now,
  );

  OverviewFigure _overdue(String workspaceId, bool current) {
    final currency =
        workspaces.workspaces
            .where((w) => w.id == workspaceId)
            .firstOrNull
            ?.currencyCode
            .trim()
            .toUpperCase() ??
        '';
    var amount = 0, overdue = 0, unknown = 0, held = 0;
    var mixed = false;
    for (final i in money.invoices) {
      if (i.workspaceId != workspaceId ||
          i.voidedAt != null ||
          i.kind == InvoiceKind.settlement ||
          i.totalCents <= 0) {
        continue;
      }
      final s = dunningFactsOf(i, money, now);
      if (s.phase == DunningPhase.unknownMaturity) unknown++;
      if (s.phase != DunningPhase.overdue) continue;
      if (s.currency.toUpperCase() != currency) mixed = true;
      if (s.hold != null) {
        held++;
      } else {
        amount += s.collectible;
        overdue++;
      }
    }
    return OverviewFigure(
      value: mixed ? null : amount,
      count: overdue,
      currency: currency,
      unknownDueCount: unknown,
      heldCount: held,
      quality: {
        if (mixed) KpiQuality.unavailable,
        if (!current) KpiQuality.notRecorded,
      },
      reasons: [if (mixed) 'currency_mix', if (!current) 'current_state'],
      computedAt: now,
    );
  }
}
