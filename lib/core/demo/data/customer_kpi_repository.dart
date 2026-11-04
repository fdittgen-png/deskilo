// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 — `kpi_customer_quality` over a demo space's own invoices, matches,
// reminders and holds, by the server's rules (0671): a payment is dated by
// the day it was reported paid (the bank's value date, else the ledger's),
// never by the match; amounts in the space's currency, another currency
// leaving them unknown; names only for a reader of personal data.
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:deskilo/features/workspace/domain/kpi_customers.dart';

import '../../time/date_text.dart';
import 'money_repository.dart';

/// An invoice falling due in the months, in its cohort.
typedef _Due = ({Invoice invoice, PaymentCohort cohort, DateTime? paidOn});

/// Credit notes and written-off remainders by the invoice's month.
typedef _Credit = ({
  Map<String, int> credited,
  Map<String, int> written,
  int notes,
  int offs,
  int unknown,
});

/// A customer by its net sales, or a debtor by what it owes ([net]).
typedef _Ranked = ({String id, int net, String name});

/// The resolutions that settle an invoice whatever was paid (0331).
const _settling = {'exact', 'over_forced', 'over_credit_note', 'refunded'};

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

  /// Calendar days from [from] to [to], whatever a clock change between
  /// them does to the hours.
  static int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

  static String _month(Invoice i) =>
      i.period ?? yearMonth(i.issuedAt.year, i.issuedAt.month);

  /// The net from the frozen VAT breakdown; null without one: a missing
  /// breakdown does not prove that gross equals net.
  static int? _net(Invoice i) => i.vatTotals.isEmpty
      ? null
      : i.vatTotals.fold<int>(0, (s, t) => s + t.netCents);

  static int _sum(Iterable<int> values) => values.fold(0, (s, v) => s + v);

  static bool _completed(_Due d) =>
      d.cohort == PaymentCohort.onTime || d.cohort == PaymentCohort.late;

  InvoiceMatch? _confirmed(Invoice i) =>
      switch (money.invoiceMatchesStore[i.id]) {
        final m? when !m.pending => m,
        _ => null,
      };

  /// The day the invoice's last payment was reported paid; null when no
  /// recorded payment explains it.
  DateTime? _paidOn(Invoice i) {
    final payments = [
      ...?money.invoiceMatchPaymentsStore[i.id],
      if (money.invoiceMatchPaymentsStore[i.id] == null)
        ?money.invoiceMatchesStore[i.id],
    ];
    DateTime? last;
    for (final p in payments.where((p) => !p.pending)) {
      final ledger = money.ledger
          .where((e) => e.id == p.paymentLedgerId)
          .firstOrNull;
      final day = p.valueDate ?? ledger?.on;
      if (day != null && (last == null || _day(day).isAfter(last))) {
        last = _day(day);
      }
    }
    return last;
  }

  /// The invoice [i] is owed through: the settlement that regrouped it
  /// (0148: regrouping is not paying), else itself.
  Invoice _owedThrough(Invoice i) => switch (i.settledByInvoiceId) {
    final id? =>
      money.invoices.where((s) => s.id == id && s.voidedAt == null).firstOrNull ??
          i,
    null => i,
  };

  /// [i] in its cohort, by the state of what it is owed through.
  _Due _dueOf(Invoice i, Map<String, int> credits) {
    final e = _owedThrough(i);
    final paidOn = _paidOn(e);
    return (
      invoice: i,
      cohort: _cohortOf(i, e, credits[e.id] ?? 0, paidOn),
      paidOn: paidOn,
    );
  }

  /// What [i] still owes now, by the dunning rules (0331); a regrouped
  /// source owes through its settlement, never twice.
  int _open(Invoice i, Map<String, int> credits) {
    final m = _confirmed(i);
    if (i.settledByInvoiceId != null ||
        m?.writeoffAt != null ||
        _settling.contains(m?.resolution)) {
      return 0;
    }
    final left = i.totalCents - (m?.paidCents ?? 0) - (credits[i.id] ?? 0);
    return left > 0 ? left : 0;
  }

  PaymentCohort _cohortOf(
    Invoice i,
    Invoice e,
    int credited,
    DateTime? paidOn,
  ) {
    final m = _confirmed(e);
    final paid = m?.paidCents ?? 0;
    final settled =
        credited >= e.totalCents ||
        (m != null &&
            (_settling.contains(m.resolution) ||
                paid + credited >= e.totalCents));
    if (i.dueOn == null) return PaymentCohort.unknownDue;
    if (m?.writeoffAt != null) return PaymentCohort.writtenOff;
    if (settled) {
      if (paidOn == null) return PaymentCohort.undated;
      return paidOn.isAfter(_day(i.dueOn!))
          ? PaymentCohort.late
          : PaymentCohort.onTime;
    }
    if (money.dunningHolds.containsKey(e.id)) return PaymentCohort.held;
    return paid > 0 ? PaymentCohort.partial : PaymentCohort.open;
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
        _month(i).compareTo(fromMonth) >= 0 &&
        _month(i).compareTo(toMonth) <= 0;
    final standing = [
      for (final i in money.invoices)
        if (i.voidedAt == null && i.kind != InvoiceKind.settlement) i,
    ];
    final credits = _creditsOf(standing);
    bool dueInMonths(Invoice i) => i.dueOn == null
        ? inMonths(i)
        : !_day(i.dueOn!).isBefore(start) && !_day(i.dueOn!).isAfter(cut);
    final due = <_Due>[
      for (final i in standing)
        if (i.totalCents > 0 && dueInMonths(i)) _dueOf(i, credits),
    ];
    // What is owed now: a settlement owes for its sources.
    final issuedByCut = [
      for (final i in money.invoices)
        if (i.voidedAt == null &&
            i.totalCents > 0 &&
            !_day(i.issuedAt).isAfter(cut))
          i,
    ];
    final inScope = standing.where(inMonths).toList();
    final mixed = _mixed(inScope, due, issuedByCut, credits);
    final partial = toMonth.compareTo(yearMonth(now.year, now.month)) >= 0;
    final dunning = dunningEnabled() ? _dunning(due) : null;
    return _figures(
      period: (from: fromMonth, to: toMonth),
      due: due,
      credit: _credit(inScope),
      customers: (
        ranked: _ranked(inScope),
        debtors: _debtors(_owedBy(issuedByCut, credits)),
        unknown: inScope.where(_netLeftOut).length,
      ),
      state: (
        mixed: mixed,
        dunning: dunning,
        quality: {
          if (mixed) KpiQuality.unavailable,
          if (partial) KpiQuality.partial,
        },
        reasons: [
          if (inScope.any(_netLeftOut)) 'net_not_proven',
          if (mixed) 'currency_mix',
          if (partial) 'period_not_over',
          if (dunning == null) 'dunning_off',
        ],
      ),
    );
  }

  /// An invoice whose net the figures need but cannot prove.
  static bool _netLeftOut(Invoice i) => _net(i) == null;

  /// The debtors by what they owe now, the largest first.
  List<_Ranked> _debtors(Map<String, int> owed) =>
      [
        for (final e in owed.entries)
          if (e.value > 0) (id: e.key, net: e.value, name: _nameOf(e.key)),
      ]..sort(
        (a, b) =>
            b.net != a.net ? b.net.compareTo(a.net) : a.id.compareTo(b.id),
      );

  /// A member's name as its latest invoice froze it.
  String _nameOf(String memberId) {
    Invoice? latest;
    for (final i in money.invoices.where((i) => i.memberId == memberId)) {
      if (latest == null || i.issuedAt.isAfter(latest.issuedAt)) latest = i;
    }
    return latest?.memberName ?? '';
  }

  /// What the credit notes give back to each invoice they replace.
  static Map<String, int> _creditsOf(List<Invoice> standing) {
    final credits = <String, int>{};
    for (final c in standing) {
      if (c.totalCents < 0 && c.replacesInvoiceId != null) {
        credits[c.replacesInvoiceId!] =
            (credits[c.replacesInvoiceId!] ?? 0) - c.totalCents;
      }
    }
    return credits;
  }

  /// Every invoice of the months, the ones due in them and what is owed
  /// now, in one currency — or not.
  bool _mixed(
    List<Invoice> inScope,
    List<_Due> due,
    List<Invoice> issuedByCut,
    Map<String, int> credits,
  ) {
    bool foreign(Invoice i) => i.currency.toUpperCase() != currency;
    return inScope.any(foreign) ||
        due.any((d) => foreign(d.invoice)) ||
        issuedByCut.any((i) => foreign(i) && _open(i, credits) > 0);
  }

  /// What each customer owes now on its invoices issued by the cut-off.
  Map<String, int> _owedBy(List<Invoice> issued, Map<String, int> credits) {
    final owed = <String, int>{};
    for (final i in issued) {
      owed[i.memberId] = (owed[i.memberId] ?? 0) + _open(i, credits);
    }
    return owed;
  }

  DunningLoad _dunning(List<_Due> due) {
    final byLevel = <int, int>{};
    var reminded = 0, reminders = 0, paidAfter = 0;
    for (final d in due) {
      final sent = money.invoiceReminders[d.invoice.id] ?? const <DateTime>[];
      if (sent.isEmpty) continue;
      reminded++;
      reminders += sent.length;
      for (var n = 1; n <= sent.length; n++) {
        byLevel[n] = (byLevel[n] ?? 0) + 1;
      }
      final first = sent.map(_day).reduce((a, b) => a.isBefore(b) ? a : b);
      if (_completed(d) && d.paidOn!.isAfter(first)) paidAfter++;
    }
    return DunningLoad(
      dueInvoices: due.where((d) => d.invoice.dueOn != null).length,
      remindedInvoices: reminded,
      reminders: reminders,
      byLevel: byLevel,
      paidAfterReminder: paidAfter,
    );
  }

  /// The credit notes and the written-off remainders, net: a remainder in
  /// proportion to its invoice's net.
  _Credit _credit(List<Invoice> inScope) {
    final credited = <String, int>{}, written = <String, int>{};
    var notes = 0, offs = 0, unknown = 0;
    for (final i in inScope) {
      final month = _month(i);
      final m = _confirmed(i);
      final net = _net(i);
      if (i.totalCents < 0) {
        notes++;
        if (net == null) unknown++;
        if (net != null) credited[month] = (credited[month] ?? 0) - net;
      } else if (i.totalCents > 0 && m?.writeoffAt != null) {
        offs++;
        if (m!.paidCents >= i.totalCents) continue;
        if (net == null) {
          unknown++;
          continue;
        }
        written[month] =
            (written[month] ?? 0) +
            ((i.totalCents - m.paidCents) * net / i.totalCents).round();
      }
    }
    return (
      credited: credited,
      written: written,
      notes: notes,
      offs: offs,
      unknown: unknown,
    );
  }

  /// The customers by signed net invoiced in the months, the largest first; a
  /// customer's name is the one of its latest invoice.
  List<_Ranked> _ranked(List<Invoice> inScope) {
    final net = <String, int>{};
    final latest = <String, Invoice>{};
    for (final i in inScope) {
      final n = _net(i);
      if (n != null) net[i.memberId] = (net[i.memberId] ?? 0) + n;
      if (!(latest[i.memberId]?.issuedAt.isAfter(i.issuedAt) ?? false)) {
        latest[i.memberId] = i;
      }
    }
    // Every customer with a proven net, by its signed net: a credit
    // against an earlier sale is deducted, never dropped (0671).
    return [
      for (final e in net.entries)
        (id: e.key, net: e.value, name: latest[e.key]!.memberName),
    ]..sort(
      (a, b) => b.net != a.net ? b.net.compareTo(a.net) : a.id.compareTo(b.id),
    );
  }

  /// The delays of the settled invoices, sorted, and their weighted mean.
  ({int? median, int? p90, double? weighted}) _delays(
    List<_Due> due,
    bool mixed,
  ) {
    final settled = [
      for (final d in due.where(_completed))
        (
          days: _daysBetween(d.invoice.dueOn!, d.paidOn!),
          total: d.invoice.totalCents,
        ),
    ];
    final days = [for (final s in settled) s.days]..sort();
    // percentile_disc: the first value whose cumulative share reaches p.
    int? percentile(double p) => days.isEmpty
        ? null
        : days[((p * days.length).ceil() - 1).clamp(0, days.length - 1)];
    final weight = _sum(settled.map((s) => s.total));
    final weighted = _sum(settled.map((s) => s.days * s.total)) / weight;
    return (
      median: percentile(0.5),
      p90: percentile(0.9),
      weighted: mixed || weight == 0 ? null : (weighted * 10).round() / 10,
    );
  }

  CustomerQualityKpi _figures({
    required ({String from, String to}) period,
    required List<_Due> due,
    required _Credit credit,
    required ({List<_Ranked> ranked, List<_Ranked> debtors, int unknown})
    customers,
    required ({
      bool mixed,
      DunningLoad? dunning,
      Set<KpiQuality> quality,
      List<String> reasons,
    })
    state,
  }) {
    final mixed = state.mixed;
    final (:ranked, :debtors, :unknown) = customers;
    int? amount(int v) => mixed ? null : v;
    List<CustomerShare> share(List<_Ranked> rows) => [
      for (final (n, r) in rows.take(_rows).indexed)
        CustomerShare(
          rank: n + 1,
          name: namesVisible() ? r.name : null,
          minor: amount(r.net),
        ),
    ];
    final delays = _delays(due, mixed);
    final names = namesVisible();
    final top = ranked.take(_top);
    final months = {...credit.credited.keys, ...credit.written.keys}.toList()
      ..sort();
    return CustomerQualityKpi(
      fromMonth: period.from,
      toMonth: period.to,
      currency: currency,
      namesVisible: names,
      cohorts: {
        for (final c in PaymentCohort.values)
          c: (
            count: due.where((d) => d.cohort == c).length,
            minor: amount(
              _sum([
                for (final d in due)
                  if (d.cohort == c) d.invoice.totalCents,
              ]),
            ),
          ),
      },
      medianDays: delays.median,
      p90Days: delays.p90,
      weightedDays: delays.weighted,
      dunning: state.dunning,
      creditNotes: credit.notes,
      creditNetUnknown: credit.unknown,
      creditedMinor: amount(_sum(credit.credited.values)),
      writeOffs: credit.offs,
      writtenOffMinor: amount(_sum(credit.written.values)),
      creditMonths: [
        for (final m in months)
          (
            month: m,
            creditedMinor: amount(credit.credited[m] ?? 0),
            writtenOffMinor: amount(credit.written[m] ?? 0),
          ),
      ],
      topCount: _top,
      customerCount: ranked.length,
      netMinor: amount(_sum(ranked.map((r) => r.net))),
      topNetMinor: amount(_sum(top.map((r) => r.net))),
      netUnknown: unknown,
      debtorCount: debtors.length,
      openMinor: amount(_sum(debtors.map((r) => r.net))),
      topOpenMinor: amount(_sum(debtors.take(_top).map((r) => r.net))),
      customers: share(ranked),
      debtors: share(debtors),
      quality: state.quality,
      reasons: state.reasons,
      computedAt: now,
    );
  }
}
