// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3556 (1b) — the invoices I select on My finances to pay or declare paid.
// A selection is of ONE business in ONE currency (the money goes to one
// payee, in one currency): once the first invoice is chosen, an invoice of
// another business or currency cannot join it. Only an invoice a payment
// may name now (the server's `payable`) is offered. A payment is of one
// month (0797, DKC04): a selection spanning months is paid one month at a
// time, the oldest first, and declared as one declaration per month.
import 'finance_overview.dart';

/// One month of a selection: its invoices and what they still owe.
typedef SelectionMonth = ({
  String period,
  List<FinanceInvoice> invoices,
  int cents,
});

class FinanceSelection {
  const FinanceSelection([this.invoices = const []]);

  static const none = FinanceSelection();

  final List<FinanceInvoice> invoices;

  bool get isEmpty => invoices.isEmpty;
  int get count => invoices.length;

  String? get workspaceId => invoices.firstOrNull?.workspaceId;
  String? get networkId => invoices.firstOrNull?.networkId;
  String? get workspaceName => invoices.firstOrNull?.workspaceName;
  String? get currency => invoices.firstOrNull?.currency;

  /// #4165 — the selection is of invoices without a month (its first
  /// invoice decides: no other kind can join it).
  bool get isStandalone => invoices.firstOrNull?.isStandalone ?? false;

  /// #4165 — the financial subject a standalone selection is paid for.
  String? get subjectId => isStandalone ? invoices.first.financialSubjectId : null;

  /// What one invoice still owes, as the server counts it.
  static int dueOf(FinanceInvoice i) => i.stillDueCents ?? i.remainingCents;

  /// The total of the selection, in its one currency.
  int get cents => invoices.fold(0, (sum, i) => sum + dueOf(i));

  bool holds(FinanceInvoice i) =>
      invoices.any((s) => s.networkId == i.networkId && s.id == i.id);

  /// Whether a payment may name [i] at all: the server says so, and its
  /// month is known (a host that does not say offers nothing to select).
  static bool selectable(FinanceInvoice i) =>
      i.target != null && i.payable && (i.period != null || i.isStandalone);

  /// Whether [i] may join this selection: selectable, and of its business
  /// and currency.
  bool accepts(FinanceInvoice i) =>
      selectable(i) &&
      (isEmpty ||
          (i.networkId == networkId &&
              i.currency.toUpperCase() == currency!.toUpperCase() &&
              acceptsKind(i)));

  /// #4165 — [i] is of the kind this selection is: a month's invoice or one
  /// without a month, and for the latter the same financial subject.
  bool acceptsKind(FinanceInvoice i) =>
      isEmpty ||
      (i.isStandalone == isStandalone &&
          (!isStandalone || i.financialSubjectId == subjectId));


  /// [i] added, or removed when it is in; an invoice it does not accept
  /// changes nothing.
  FinanceSelection toggled(FinanceInvoice i) {
    if (holds(i)) {
      return FinanceSelection([
        for (final s in invoices)
          if (!(s.networkId == i.networkId && s.id == i.id)) s,
      ]);
    }
    return accepts(i) ? FinanceSelection([...invoices, i]) : this;
  }

  /// The selection without [paid].
  FinanceSelection without(Iterable<FinanceInvoice> paid) => FinanceSelection([
    for (final s in invoices)
      if (!paid.any((p) => p.networkId == s.networkId && p.id == s.id)) s,
  ]);

  /// #4165 — the invoices without a month of a standalone selection, the
  /// oldest first; none for a monthly one.
  List<FinanceInvoice> get standaloneInvoices => isStandalone
      ? ([...invoices]..sort((a, b) => a.issuedAt.compareTo(b.issuedAt)))
      : const [];

  /// The months it spans, oldest first, each with its invoices (oldest
  /// first) and what they still owe.
  List<SelectionMonth> get months {
    final byPeriod = <String, List<FinanceInvoice>>{};
    for (final i in invoices) {
      // an invoice without a month is paid in its own selection (#4165)
      final period = i.period;
      if (period != null) (byPeriod[period] ??= []).add(i);
    }
    final periods = byPeriod.keys.toList()..sort();
    return [
      for (final p in periods)
        (
          period: p,
          invoices: [...byPeriod[p]!]
            ..sort((a, b) => a.issuedAt.compareTo(b.issuedAt)),
          cents: byPeriod[p]!.fold(0, (sum, i) => sum + dueOf(i)),
        ),
    ];
  }
}
