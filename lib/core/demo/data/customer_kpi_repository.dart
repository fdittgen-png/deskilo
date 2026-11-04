// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 — `kpi_customer_quality` over a demo space's own invoices, matches,
// reminders and holds, by the server's rules (0669): a payment is dated by
// the day it was reported paid (the bank's value date, else the ledger's),
// never by the match; amounts in the space's currency, another currency
// leaving them unknown; names only for a reader of personal data.
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:deskilo/features/workspace/domain/kpi_customers.dart';

import '../../time/date_text.dart';
import 'money_repository.dart';

class DemoCustomerKpiRepository implements CustomerKpiRepository {
  DemoCustomerKpiRepository({
    required this.money,
    required this.now,
    required this.namesVisible,
    required this.dunningEnabled,
    this.currency = 'EUR',
  });

  final FakeMoneyRepository money;
  final DateTime now;

  /// Whether the reader holds `viewPersonalData` (the server's decision).
  final bool Function() namesVisible;
  final bool Function() dunningEnabled;

  /// The space's currency: a US space does not read in euros.
  final String currency;

  /// The server's definition of the concentration and its listing bound.
  static const _top = 5;
  static const _rows = 10;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _month(Invoice i) =>
      i.period ?? yearMonth(i.issuedAt.year, i.issuedAt.month);

  static int _net(Invoice i) => i.vatTotals.isEmpty
      ? i.totalCents
      : i.vatTotals.fold(0, (s, t) => s + t.netCents);

  /// The day the invoice's last payment was reported paid; null when no
  /// recorded payment explains it.
  DateTime? _paidOn(Invoice i) {
    final payments = [
      ...?money.invoiceMatchPaymentsStore[i.id],
      if (money.invoiceMatchPaymentsStore[i.id] == null)
        ?money.invoiceMatchesStore[i.id],
    ];
    DateTime? last;
    for (final p in payments) {
      if (p.pending) continue;
      final ledger = money.ledger
          .where((e) => e.id == p.paymentLedgerId)
          .firstOrNull;
      final day = p.valueDate ?? ledger?.on;
      if (day == null) continue;
      if (last == null || _day(day).isAfter(last)) last = _day(day);
    }
    return last;
  }

  @override
  Future<CustomerQualityKpi> quality(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async {
    final start = DateTime(
      int.parse(fromMonth.substring(0, 4)),
      int.parse(fromMonth.substring(5)),
    );
    final cut = DateTime(
      int.parse(toMonth.substring(0, 4)),
      int.parse(toMonth.substring(5)) + 1,
    ).subtract(const Duration(days: 1));
    bool inMonths(Invoice i) =>
        _month(i).compareTo(fromMonth) >= 0 && _month(i).compareTo(toMonth) <= 0;
    final standing = [
      for (final i in money.invoices)
        if (i.voidedAt == null && i.kind != InvoiceKind.settlement) i,
    ];
    final credits = <String, int>{};
    for (final c in standing) {
      if (c.totalCents < 0 && c.replacesInvoiceId != null) {
        credits[c.replacesInvoiceId!] =
            (credits[c.replacesInvoiceId!] ?? 0) - c.totalCents;
      }
    }

    // The invoices falling due in the months, each in one cohort.
    final due = <({Invoice invoice, PaymentCohort cohort, DateTime? paidOn})>[];
    for (final i in standing) {
      if (i.totalCents <= 0) continue;
      final dueOn = i.dueOn == null ? null : _day(i.dueOn!);
      final inScope = dueOn == null
          ? inMonths(i)
          : !dueOn.isBefore(start) && !dueOn.isAfter(cut);
      if (!inScope) continue;
      final m = money.invoiceMatchesStore[i.id];
      final confirmed = m != null && !m.pending;
      final paid = confirmed ? m.paidCents : 0;
      final credited = credits[i.id] ?? 0;
      final writtenOff = confirmed && m.writeoffAt != null;
      final settled =
          i.settledByInvoiceId != null ||
          credited >= i.totalCents ||
          (confirmed &&
              (const {
                    'exact',
                    'over_forced',
                    'over_credit_note',
                    'refunded',
                  }.contains(m.resolution) ||
                  paid + credited >= i.totalCents));
      final paidOn = _paidOn(i);
      final cohort = dueOn == null
          ? PaymentCohort.unknownDue
          : writtenOff
          ? PaymentCohort.writtenOff
          : settled && paidOn == null
          ? PaymentCohort.undated
          : settled && !paidOn!.isAfter(dueOn)
          ? PaymentCohort.onTime
          : settled
          ? PaymentCohort.late
          : money.dunningHolds.containsKey(i.id)
          ? PaymentCohort.held
          : confirmed && paid > 0
          ? PaymentCohort.partial
          : PaymentCohort.open;
      due.add((invoice: i, cohort: cohort, paidOn: paidOn));
    }

    final mixed =
        standing.any((i) => inMonths(i) && i.currency.toUpperCase() != currency) ||
        due.any((d) => d.invoice.currency.toUpperCase() != currency) ||
        standing.any(
          (i) =>
              i.totalCents > 0 &&
              i.currency.toUpperCase() != currency &&
              !_day(i.issuedAt).isAfter(cut) &&
              _open(i, credits) > 0,
        );
    int? amount(int v) => mixed ? null : v;

    final cohorts = {
      for (final c in PaymentCohort.values)
        c: (
          count: due.where((d) => d.cohort == c).length,
          minor: amount(
            due
                .where((d) => d.cohort == c)
                .fold(0, (s, d) => s + d.invoice.totalCents),
          ),
        ),
    };
    final settledDays = [
      for (final d in due)
        if (d.cohort == PaymentCohort.onTime || d.cohort == PaymentCohort.late)
          (
            days: d.paidOn!.difference(_day(d.invoice.dueOn!)).inDays,
            total: d.invoice.totalCents,
          ),
    ];
    final sortedDays = [for (final s in settledDays) s.days]..sort();
    int? percentile(double p) => sortedDays.isEmpty
        ? null
        : sortedDays[((p * sortedDays.length).ceil() - 1).clamp(
            0,
            sortedDays.length - 1,
          )];
    final weightTotal = settledDays.fold(0, (s, d) => s + d.total);
    final weighted = mixed || weightTotal == 0
        ? null
        : (settledDays.fold(0, (s, d) => s + d.days * d.total) /
                      weightTotal *
                      10)
                  .round() /
              10;

    DunningLoad? dunning;
    if (dunningEnabled()) {
      final byLevel = <int, int>{};
      var reminded = 0, reminders = 0, paidAfter = 0;
      for (final d in due) {
        final sent = money.invoiceReminders[d.invoice.id] ?? const [];
        if (sent.isEmpty) continue;
        reminded++;
        reminders += sent.length;
        for (var n = 1; n <= sent.length; n++) {
          byLevel[n] = (byLevel[n] ?? 0) + 1;
        }
        final first = sent.map(_day).reduce((a, b) => a.isBefore(b) ? a : b);
        if ((d.cohort == PaymentCohort.onTime ||
                d.cohort == PaymentCohort.late) &&
            d.paidOn!.isAfter(first)) {
          paidAfter++;
        }
      }
      dunning = DunningLoad(
        dueInvoices: due.where((d) => d.invoice.dueOn != null).length,
        remindedInvoices: reminded,
        reminders: reminders,
        byLevel: byLevel,
        paidAfterReminder: paidAfter,
      );
    }

    // Credit notes and written-off remainders, by the invoice's month, net.
    final credited = <String, int>{}, written = <String, int>{};
    var notes = 0, offs = 0;
    for (final i in standing.where(inMonths)) {
      final month = _month(i);
      if (i.totalCents < 0) {
        notes++;
        credited[month] = (credited[month] ?? 0) - _net(i);
        continue;
      }
      final m = money.invoiceMatchesStore[i.id];
      if (i.totalCents == 0 || m == null || m.pending || m.writeoffAt == null) {
        continue;
      }
      offs++;
      if (m.paidCents < i.totalCents) {
        written[month] =
            (written[month] ?? 0) +
            ((i.totalCents - m.paidCents) * _net(i) / i.totalCents).round();
      }
    }
    final months = {...credited.keys, ...written.keys}.toList()..sort();

    // Net invoiced per customer, and what each owes now.
    final names = namesVisible();
    final byMember = <String, ({int net, String name, DateTime issued})>{};
    for (final i in standing.where(inMonths)) {
      final prior = byMember[i.memberId];
      byMember[i.memberId] = (
        net: (prior?.net ?? 0) + _net(i),
        name: prior == null || i.issuedAt.isAfter(prior.issued)
            ? i.memberName
            : prior.name,
        issued: prior == null || i.issuedAt.isAfter(prior.issued)
            ? i.issuedAt
            : prior.issued,
      );
    }
    final owed = <String, int>{};
    for (final i in standing) {
      if (i.totalCents <= 0 || _day(i.issuedAt).isAfter(cut)) continue;
      owed[i.memberId] = (owed[i.memberId] ?? 0) + _open(i, credits);
    }
    final ranked =
        [
          for (final e in byMember.entries)
            if (e.value.net > 0)
              (id: e.key, net: e.value.net, name: e.value.name),
        ]..sort(
          (a, b) => b.net != a.net ? b.net.compareTo(a.net) : a.id.compareTo(b.id),
        );
    final net = ranked.fold(0, (s, r) => s + r.net);
    final open = ranked.fold(0, (s, r) => s + (owed[r.id] ?? 0));
    final top = ranked.take(_top);

    final partial = toMonth.compareTo(yearMonth(now.year, now.month)) >= 0;
    return CustomerQualityKpi(
      fromMonth: fromMonth,
      toMonth: toMonth,
      currency: currency,
      namesVisible: names,
      cohorts: cohorts,
      medianDays: percentile(0.5),
      p90Days: percentile(0.9),
      weightedDays: weighted,
      dunning: dunning,
      creditNotes: notes,
      creditedMinor: amount(credited.values.fold(0, (s, v) => s + v)),
      writeOffs: offs,
      writtenOffMinor: amount(written.values.fold(0, (s, v) => s + v)),
      creditMonths: [
        for (final m in months)
          (
            month: m,
            creditedMinor: amount(credited[m] ?? 0),
            writtenOffMinor: amount(written[m] ?? 0),
          ),
      ],
      topCount: _top,
      customerCount: ranked.length,
      netMinor: amount(net),
      topNetMinor: amount(top.fold(0, (s, r) => s + r.net)),
      openMinor: amount(open),
      topOpenMinor: amount(top.fold(0, (s, r) => s + (owed[r.id] ?? 0))),
      customers: [
        for (final (n, r) in ranked.take(_rows).indexed)
          CustomerShare(
            rank: n + 1,
            name: names ? r.name : null,
            netMinor: amount(r.net),
            openMinor: amount(owed[r.id] ?? 0),
          ),
      ],
      quality: {
        if (mixed) KpiQuality.unavailable,
        if (partial) KpiQuality.partial,
      },
      reasons: [
        if (mixed) 'currency_mix',
        if (partial) 'period_not_over',
        if (!dunningEnabled()) 'dunning_off',
      ],
      computedAt: now,
    );
  }

  /// What [i] still owes now, by the dunning rules (0331).
  int _open(Invoice i, Map<String, int> credits) {
    final m = money.invoiceMatchesStore[i.id];
    final confirmed = m != null && !m.pending;
    if (i.settledByInvoiceId != null || (confirmed && m.writeoffAt != null)) {
      return 0;
    }
    if (confirmed &&
        const {
          'exact',
          'over_forced',
          'over_credit_note',
          'refunded',
        }.contains(m.resolution)) {
      return 0;
    }
    final left = i.totalCents - (confirmed ? m.paidCents : 0) - (credits[i.id] ?? 0);
    return left > 0 ? left : 0;
  }
}
